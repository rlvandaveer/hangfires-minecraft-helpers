# PaperMC -> Vanilla Save Conversion: NBT Reconstruction

This document captures the analysis behind why `ConvertTo-MinecraftSavedGame`
cannot, by file moves alone, produce a vanilla-loadable save from a modern
PaperMC server world, and what an NBT-aware second pass would need to do.

The current cmdlet performs all the safely-reversible file-level work
(promoting overworld region/entities/poi, renaming `the_nether`/`the_end` to
`DIM-1`/`DIM1`, reshaping `players/` into the vanilla layout, removing
`paper-world.yml` and `datapacks/bukkit`). After it runs, the vanilla client
still rejects the save with two errors in sequence:

1. "Errors in currently selected data packs prevented the world from loading."
2. (after Safe Mode) "This world contains invalid or corrupted save data."

Both are rooted in how PaperMC 26+ has restructured the save format.

## 1. Observed Paper world layout (Paper 26.1.2)

Source archive structure (from `Backup-MinecraftServerWorld`):

```
<world>/
  data/
    minecraft/maps/                  vanilla map items
  datapacks/
    bukkit/pack.mcmeta               Paper-injected datapack (vanilla can't load)
  dimensions/
    minecraft/
      overworld/
        data/
          paper/                     Paper-internal (level_overrides, metadata, persistent_data_container)
          minecraft/                 EXTRACTED vanilla per-dim state (see Section 2)
            chunk_tickets.dat
            game_rules.dat
            raids.dat
            scheduled_events.dat
            wandering_trader.dat
            weather.dat
            world_border.dat
            world_clocks.dat
            world_gen_settings.dat
        entities/
        poi/
        region/
        paper-world.yml
      the_nether/ (same shape)
      the_end/   (same shape)
  players/
    advancements/<uuid>.json         vanilla path is <world>/advancements/
    data/<uuid>.dat                  vanilla path is <world>/playerdata/
    stats/<uuid>.json                vanilla path is <world>/stats/
  icon.png
  level.dat                          STRIPPED (see Section 3)
  level.dat_old
  session.lock
```

## 2. Layout produced by the current cmdlet

After `ConvertTo-MinecraftSavedGame` runs, the destination save looks like:

```
<save>/
  data/minecraft/maps/                          (untouched, vanilla)
  datapacks/                                    (bukkit removed)
  dimensions/minecraft/overworld/
    data/minecraft/*.dat                        PRESERVED for the NBT pass
  DIM-1/
    region/, entities/, poi/                    vanilla layout
    data/minecraft/*.dat                        PRESERVED for the NBT pass
  DIM1/
    region/, entities/, poi/
    data/minecraft/*.dat                        PRESERVED for the NBT pass
  region/, entities/, poi/                      overworld, promoted to root
  playerdata/, advancements/, stats/            reshaped from Paper's players/
  icon.png
  level.dat                                     STILL stripped (Section 3)
  level.dat_old
```

Asymmetry note: overworld per-dim data is at
`<save>/dimensions/minecraft/overworld/data/minecraft/`, while the nether and
end are at `<save>/DIM-1/data/minecraft/` and `<save>/DIM1/data/minecraft/`.
The vanilla client ignores both locations -- they are scratch space for the
NBT reconstruction step.

## 3. Why `level.dat` fails to load in vanilla

Decompressed Paper 26.1.2 `level.dat` (708 bytes uncompressed) contains, under
`Data`:

- `difficulty_settings { locked: 0b, difficulty: "hard" }`
- `hardcore: 0b`
- `Bukkit.Version: "Paper/26.1.2-61-..."`
- `singleplayer_uuid: <UUID>`
- `spawn { pos: [...], pitch, yaw }`
- `dimension: "minecraft:overworld"`
- `WasModded: 1b`
- `allowCommands: 1b`
- `LastPlayed: <long>`
- `initialized: 1b`
- `version: <int>` (legacy world format version)
- `ServerBrands: ["fabric", "Paper"]`
- `GameType: 0`
- `DataPacks { Enabled: ["vanilla", "file/bukkit", "paper"], Disabled: ["minecart_improvements", "redstone_experiments", "trade_rebalance"] }`
- `DataVersion: 4790`
- `paperSpawnDimension: "minecraft:overworld"`
- `LevelName: "Familycraft"`
- `Time: <long>`
- `Version { Name: "26.1.2", Series: "main", Snapshot: 0b, Id: 4790 }`

Vanilla `LevelStorageSource.readLevelData()` expects, in addition, the
following tags (see Mojang's mappings and the wiki references in Section 7):

- `WorldGenSettings` (compound with `seed`, `generate_features`, `bonus_chest`,
  and a `dimensions` map keyed by dimension id, each holding `type` and
  `generator`)
- `GameRules` (compound of named string entries)
- `BorderCenterX`, `BorderCenterZ`, `BorderSize`, `BorderSizeLerpTarget`,
  `BorderSizeLerpTime`, `BorderSafeZone`, `BorderDamagePerBlock`,
  `BorderWarningBlocks`, `BorderWarningTime`
- `clearWeatherTime`, `rainTime`, `raining`, `thunderTime`, `thundering`
- `DayTime`
- `WanderingTraderSpawnChance`, `WanderingTraderSpawnDelay`, `WanderingTraderId`
- `ScheduledEvents` (list)
- `Player` (singleplayer host's player state)
- `ServerBrands` should contain `"vanilla"` (the Paper value triggers
  `WasModded`)

Without `WorldGenSettings`, the world load fails -- this surfaces as
"invalid or corrupted save data" in Safe Mode (because Safe Mode masks the
datapack failure first).

### What Paper writes instead

Paper 26+ keeps the per-dimension counterparts as standalone gzipped NBT files
under `<dim>/data/minecraft/`:

| Paper file | Vanilla destination |
| --- | --- |
| `world_gen_settings.dat` | merge into `level.dat:Data.WorldGenSettings.dimensions[<dim id>]` and seed (see Section 4) |
| `game_rules.dat` | overworld only -> `level.dat:Data.GameRules` |
| `world_border.dat` | overworld only -> `level.dat:Data.BorderCenter*` / `BorderSize*` / `BorderWarning*` / `BorderDamagePerBlock` / `BorderSafeZone` |
| `world_clocks.dat` | overworld only -> `level.dat:Data.DayTime` and `Time` (already present) |
| `weather.dat` | overworld only -> `level.dat:Data.{clearWeatherTime,raining,rainTime,thundering,thunderTime}` |
| `wandering_trader.dat` | overworld only -> `level.dat:Data.WanderingTrader*` |
| `scheduled_events.dat` | overworld only -> `level.dat:Data.ScheduledEvents` |
| `raids.dat` | per-dim -> `<dim>/data/raids.dat` (NOT in level.dat) |
| `chunk_tickets.dat` | not used by vanilla; safe to drop |

The exact tag names inside each Paper file should be verified before merging
(open the file with NBTExplorer or `nbted -p` and confirm shape).
`world_gen_settings.dat` is the trickiest because vanilla expects one combined
`WorldGenSettings` compound at the level.dat root, with `seed` /
`generate_features` / `bonus_chest` at that level and a `dimensions` map of
per-dim `{ type, generator }`. The per-dim files most likely each store one
`{ type, generator }` plus a copy of `seed`; the reconstruction step needs to
pick the overworld's seed (they should all agree) and assemble the
`dimensions` map keyed by `minecraft:overworld`, `minecraft:the_nether`, and
`minecraft:the_end`.

## 4. Datapack list cleanup

After `WorldGenSettings` is in place, the second remaining failure is
`DataPacks.Enabled = ["vanilla", "file/bukkit", "paper"]`. Vanilla cannot
resolve `file/bukkit` or `paper`, so the load aborts.

The fix is to overwrite `level.dat:Data.DataPacks.Enabled` with
`["vanilla"]` (preserving any genuine user datapacks if present in
`<save>/datapacks/`). `Data.DataPacks.Disabled` may stay as-is; vanilla
recognises those feature-gate names.

`Data.ServerBrands` should be replaced with `["vanilla"]` (or
`["fabric"]` if loading in Fabric). `WasModded` can be left at 1b -- it is
informational. `Bukkit.Version` and `paperSpawnDimension` are vendor-specific
tags that vanilla ignores; harmless to leave, cleaner to strip.

## 5. Suggested NBT pass (when someone implements it)

The pass should run after the file-level cmdlet and consume the same
`$savePath`. Pseudo-steps:

1. Load `<save>/level.dat` (gzipped NBT) into an in-memory tree.
2. Load each per-dim file (paths in Section 2 above) needed for the merges in
   Section 3.
3. Build `WorldGenSettings`:
   - `seed`: from any per-dim `world_gen_settings.dat` (overworld preferred).
   - `generate_features`: from same.
   - `bonus_chest`: 0b unless source says otherwise.
   - `dimensions`: map of three entries with `type` + `generator` taken from
     each dim's `world_gen_settings.dat`.
4. Inject `GameRules`, `BorderXxx`, weather, `DayTime`, wandering trader,
   `ScheduledEvents` from the overworld's per-dim files.
5. Rewrite `DataPacks.Enabled` to `["vanilla"]` plus any genuine user
   datapacks present in `<save>/datapacks/` (excluding `bukkit`).
6. Optionally replace `ServerBrands`, drop `Bukkit.Version` and
   `paperSpawnDimension`.
7. Move per-dim `raids.dat` from `<dim>/data/minecraft/raids.dat` to
   `<dim>/data/raids.dat` (vanilla path).
8. Delete the scratch directories: `<save>/dimensions/`,
   `<save>/DIM-1/data/`, `<save>/DIM1/data/` (after raids has been moved out),
   `<save>/data/_paper*` if any. Re-gzip and write `level.dat` back, and
   rewrite `level.dat_old` to match.

Vanilla also expects `level.dat` to be small but well-formed; total size
after merge will be in the multi-kilobyte range (the 2024-08-20 reference
backup of this same world had an 11 KB `level.dat`).

## 6. Tooling options

PowerShell has no built-in NBT support. Practical implementation paths, in
rough order of effort:

- **External CLI**. Shell out to `nbted` ([github.com/joewing/nbted](https://github.com/joewing/nbted),
  Rust) which reads/writes gzipped NBT as a textual format. The cmdlet would
  emit text edits, then convert back. Requires the user to install one binary.
- **Python helper**. Bundle a small Python script using the `nbt` package
  ([github.com/twoolie/NBT](https://github.com/twoolie/NBT)). PowerShell
  invokes it. Requires Python on PATH.
- **Java helper**. Bundle a small Java program using NBT-Editor's library
  ([github.com/jaquadro/NBTExplorer](https://github.com/jaquadro/NBTExplorer))
  or Querz's NBT ([github.com/Querz/NBT](https://github.com/Querz/NBT)).
  Heaviest dependency, most authoritative library.
- **Native PowerShell NBT module**. Write or vendor a minimal gzipped-NBT
  reader/writer in PowerShell. Doable in a few hundred lines because we only
  touch a handful of well-known tags, but a maintenance burden. The NBT
  format itself is documented in the Wiki link in Section 7.

If the goal is just unblocking a single conversion ad hoc,
[NBTExplorer](https://github.com/jaquadro/NBTExplorer) (a GUI) is the
quickest manual option: open each file, copy tags between trees, save.

## 7. References

- PaperMC `paper-world.yml` configuration:
  <https://docs.papermc.io/paper/reference/configuration/>
- Minecraft Wiki, `level.dat` format (canonical list of expected tags):
  <https://minecraft.wiki/w/Java_Edition_level_format>
- Minecraft Wiki, NBT format spec:
  <https://minecraft.wiki/w/NBT_format>
- PaperMC source (level data structures), `paper-server` module:
  <https://github.com/PaperMC/Paper>
- NBT libraries:
  - <https://github.com/twoolie/NBT> (Python)
  - <https://github.com/Querz/NBT> (Java)
  - <https://github.com/jaquadro/NBTExplorer> (Java GUI / library)
  - <https://github.com/joewing/nbted> (Rust CLI, text round-trip)
