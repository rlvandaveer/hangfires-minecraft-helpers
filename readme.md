# HangFire0331's Minecraft Helpers

PowerShell cmdlets for managing PaperMC servers, backing up worlds, and working with resource packs.

## Contents

- [PaperMC Management](#papermc-management)
  - [Get-LatestPaperBuild](#get-latestpaperbuild)
  - [Update-PaperVersion](#update-paperversion)
  - [Update-StartScript](#update-startscript)
  - [New-PaperServer](#new-paperserver)
- [Backup and Restore](#backup-and-restore)
  - [Backup-MinecraftSavedGame](#backup-minecraftsavedgame)
  - [Restore-MinecraftSavedGame](#restore-minecraftsavedgame)
  - [Backup-MinecraftServerWorld](#backup-minecraftserverworld)
  - [Restore-MinecraftServerWorld](#restore-minecraftserverworld)
  - [ConvertTo-MinecraftSavedGame](#convertto-minecraftsavedgame)
- [Resource Packs](#resource-packs)
  - [Copy-ResourcePackForTesting](#copy-resourcepackfortesting)
  - [Compress-ResourcePackForTesting](#compress-resourcepackfortesting)
  - [Get-ResourcePackVersion](#get-resourcepackversion)
  - [Get-ResourcePackVersionedDescription](#get-resourcepackversioneddescription)
  - [Get-ResourcePackMetaData](#get-resourcepackmetadata)

---

## PaperMC Management

Source: `source/papermc-management-functions.ps1`

These cmdlets interact with the [PaperMC Fill API](https://fill.papermc.io) (GraphQL) to download
and manage Paper server JARs.

### Get-LatestPaperBuild

Queries the Fill API and returns build metadata for a given Paper version. When no version is
specified, the latest version that has at least one stable build is auto-detected.

```powershell
Get-LatestPaperBuild [-MinecraftVersion <string>] [-AllowUnstable]
```

**Parameters**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-MinecraftVersion` | string | No | Paper version to query (e.g. `26.1.2`). Omit to auto-detect the latest stable version. |
| `-AllowUnstable` | switch | No | Include alpha and beta builds. A warning is written when a non-stable build is returned. |

**Output**

Returns a `PSCustomObject` with the following properties:

| Property | Type | Description |
|---|---|---|
| `Version` | string | The Paper version string (e.g. `26.1.2`) |
| `BuildNumber` | int | The build number |
| `FileName` | string | The JAR filename (e.g. `paper-26.1.2-53.jar`) |
| `DownloadUrl` | string | Direct download URL for the JAR |

**Examples**

```powershell
# Get the latest stable build (auto-detect version)
Get-LatestPaperBuild

# Get the latest stable build for a specific version
Get-LatestPaperBuild -MinecraftVersion '26.1.2'

# Get the latest build for a version that only has unstable builds
Get-LatestPaperBuild -MinecraftVersion '26.1.3' -AllowUnstable

# Pipe build info to use elsewhere
$build = Get-LatestPaperBuild
Write-Host "Latest: $($build.Version) build $($build.BuildNumber)"
```

---

### Update-PaperVersion

Downloads the latest Paper build and copies it into one or more server directories. Automatically
updates the start script in each directory via `Update-StartScript`. Supports `-WhatIf`.

```powershell
Update-PaperVersion [-PaperDownloadUri <Uri>] [-MinecraftVersion <string>] [-AllowUnstable]
                    -ServerPath <FileSystemInfo[]>
```

**Parameters**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-ServerPath` | FileSystemInfo[] | Yes | One or more server directories to update. Accepts pipeline input. |
| `-MinecraftVersion` | string | No | Paper version to download (e.g. `26.1.2`). Omit to auto-detect the latest stable version. |
| `-AllowUnstable` | switch | No | Allow downloading alpha or beta builds when no stable build exists for the requested version. |
| `-PaperDownloadUri` | Uri | No | Direct download URL override. When provided, the Fill API is not consulted and `Update-StartScript` is not called. |

**Examples**

```powershell
# Update a single server to the latest stable Paper version
Update-PaperVersion -ServerPath '/Applications/Minecraft-Server'

# Update multiple servers to a specific version
Update-PaperVersion -MinecraftVersion '26.1.2' -ServerPath @('/srv/mc/survival', '/srv/mc/creative')

# Preview changes without downloading or modifying anything
Update-PaperVersion -MinecraftVersion '26.1.2' -ServerPath '/Applications/Minecraft-Server' -WhatIf

# Download from a custom URL (start script not updated automatically)
Update-PaperVersion -PaperDownloadUri 'https://example.com/paper-26.1.2-53.jar' -ServerPath '/Applications/Minecraft-Server'
```

---

### Update-StartScript

Replaces the Paper JAR filename referenced in a server's `start.ps1`. Called automatically by
`Update-PaperVersion`; use directly when updating after a `PaperDownloadUri` install. Supports
`-WhatIf`.

```powershell
Update-StartScript -MinecraftVersion <string> -PreviousPaperJar <string> -NewPaperBuild <int>
                   -ServerPath <FileSystemInfo[]>
```

**Parameters**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-MinecraftVersion` | string | Yes | The Paper version being installed (e.g. `26.1.2`). |
| `-PreviousPaperJar` | string | Yes | The JAR filename currently referenced in `start.ps1`. |
| `-NewPaperBuild` | int | Yes | The build number of the new Paper JAR. |
| `-ServerPath` | FileSystemInfo[] | Yes | One or more server directories whose `start.ps1` should be updated. Accepts pipeline input. |

**Examples**

```powershell
# Update start.ps1 manually after a custom URI install
Update-StartScript -MinecraftVersion '26.1.2' -PreviousPaperJar 'paper-26.1.1-29.jar' -NewPaperBuild 53 -ServerPath '/Applications/Minecraft-Server'

# Preview the change
Update-StartScript -MinecraftVersion '26.1.2' -PreviousPaperJar 'paper-26.1.1-29.jar' -NewPaperBuild 53 -ServerPath '/Applications/Minecraft-Server' -WhatIf
```

---

### New-PaperServer

Creates a new Paper server directory, clones the base server files from
[hangfires-papermc-base-server](https://github.com/rlvandaveer/hangfires-papermc-base-server),
and downloads the Paper JAR. Supports `-WhatIf`.

```powershell
New-PaperServer [-PaperDownloadUri <Uri>] [-MinecraftVersion <string>] [-AllowUnstable]
                -WorldName <string> -ServerPath <string>
```

**Parameters**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-WorldName` | string | Yes | The name of the server world. |
| `-ServerPath` | string | Yes | Path for the new server directory. Must not already exist. Accepts pipeline input. |
| `-MinecraftVersion` | string | No | Paper version to use (e.g. `26.1.2`). Omit to auto-detect the latest stable version. |
| `-AllowUnstable` | switch | No | Allow using alpha or beta builds when no stable build exists for the requested version. |
| `-PaperDownloadUri` | Uri | No | Direct download URL override. When provided, the Fill API is not consulted. |

**Examples**

```powershell
# Create a new server using the latest stable Paper version
New-PaperServer -WorldName 'MyWorld' -ServerPath '/Applications/Minecraft-Server'

# Create a new server pinned to a specific version
New-PaperServer -MinecraftVersion '26.1.2' -WorldName 'MyWorld' -ServerPath '/srv/mc/survival'

# Preview server creation without making any changes
New-PaperServer -MinecraftVersion '26.1.2' -WorldName 'MyWorld' -ServerPath '/srv/mc/survival' -WhatIf
```

---

## Backup and Restore

Source: `source/minecraft-backup-functions.ps1`

### Backup-MinecraftSavedGame

Compresses a Minecraft client saved game (single-player world) to a dated ZIP archive.

```powershell
Backup-MinecraftSavedGame [-SavedGameName <string>] [-DestinationPath <FileInfo>]
                          [-Date <DateTime>] [-Force]  [-SavesPath <FileInfo>]
```

**Parameters**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-SavedGameName` | string | `HangFire0331s World` | Name of the saved game folder. |
| `-DestinationPath` | FileInfo | `~/Downloads/minecraft/World and Server Backups` | Directory where the archive will be written. |
| `-Date` | DateTime | Today | Date used in the archive filename. |
| `-Force` | switch | `$false` | Overwrite an existing archive with the same name. |
| `-SavesPath` | FileInfo | `~/Library/ApplicationSupport/minecraft/saves/` | Path to the Minecraft saves directory. |

**Examples**

```powershell
# Backup today's save with defaults
Backup-MinecraftSavedGame

# Backup a specific world to a custom location
Backup-MinecraftSavedGame -SavedGameName 'MySurvivalWorld' -DestinationPath '~/Backups'
```

---

### Restore-MinecraftSavedGame

Extracts a previously archived client saved game back to the Minecraft saves directory.

```powershell
Restore-MinecraftSavedGame [-SavedGameName <string>] [-SourcePath <FileInfo>]
                           [-Date <DateTime>] [-Force] [-SavesPath <FileInfo>]
```

**Parameters**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-SavedGameName` | string | `HangFire0331s World` | Name of the saved game. |
| `-SourcePath` | FileInfo | `~/Downloads/minecraft/World and Server Backups` | Directory containing the archive. |
| `-Date` | DateTime | Today | Date used to locate the archive file. |
| `-Force` | switch | `$false` | Overwrite existing files when extracting. |
| `-SavesPath` | FileInfo | `~/Library/ApplicationSupport/minecraft/saves/` | Destination saves directory. |

**Examples**

```powershell
# Restore today's backup
Restore-MinecraftSavedGame

# Restore a specific date's backup
Restore-MinecraftSavedGame -Date '2026-04-01' -SavedGameName 'MySurvivalWorld'
```

---

### Backup-MinecraftServerWorld

Compresses a Paper server world (including nether and end dimensions) to a dated ZIP archive.

```powershell
Backup-MinecraftServerWorld [-WorldName <string>] [-DestinationPath <FileInfo>]
                            [-Date <DateTime>] [-Force] [-ServerPath <FileInfo>]
```

**Parameters**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-WorldName` | string | `HangFire0331s World` | Name of the world folder inside the server directory. |
| `-DestinationPath` | FileInfo | `~/Downloads/minecraft/World and Server Backups` | Directory where the archive will be written. |
| `-Date` | DateTime | Today | Date used in the archive filename. |
| `-Force` | switch | `$false` | Overwrite an existing archive with the same name. |
| `-ServerPath` | FileInfo | `/Applications/Minecraft-Server` | Path to the server directory. |

**Examples**

```powershell
# Backup today's server world with defaults
Backup-MinecraftServerWorld

# Backup a named world on a custom server path
Backup-MinecraftServerWorld -WorldName 'Survival' -ServerPath '/srv/mc/paper'
```

---

### Restore-MinecraftServerWorld

Extracts a previously archived server world back into the server directory.

```powershell
Restore-MinecraftServerWorld [-WorldName <string>] [-SourcePath <FileInfo>]
                             [-Date <DateTime>] [-Force] [-ServerPath <FileInfo>]
```

**Parameters**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-WorldName` | string | `HangFire0331s World` | Name of the world. |
| `-SourcePath` | FileInfo | `~/Downloads/minecraft/World and Server Backups` | Directory containing the archive. |
| `-Date` | DateTime | Today | Date used to locate the archive file. |
| `-Force` | switch | `$false` | Overwrite existing files when extracting. |
| `-ServerPath` | FileInfo | `/Applications/Minecraft-Server` | Destination server directory. |

**Examples**

```powershell
# Restore today's backup with defaults
Restore-MinecraftServerWorld

# Restore a specific date's backup
Restore-MinecraftServerWorld -Date '2026-04-01' -WorldName 'Survival' -ServerPath '/srv/mc/paper'
```

---

### ConvertTo-MinecraftSavedGame

Copies a Paper server world into the Minecraft client saves directory so it can be opened in
single-player. Handles the nether (`DIM-1`) and end (`DIM1`) dimension folders. The source can
be either a live server directory or a backup archive produced by `Backup-MinecraftServerWorld`;
when an archive is supplied it is expanded to a temporary directory that is removed after the
conversion.

```powershell
ConvertTo-MinecraftSavedGame -WorldName <string> [-DestinationPath <FileInfo>] [-Force]
                             [-ServerPath <FileInfo>]
ConvertTo-MinecraftSavedGame -WorldName <string> -ArchivePath <FileInfo>
                             [-DestinationPath <FileInfo>] [-Force]
```

**Parameters**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-WorldName` | string | _(required)_ | Name of the world folder. With `-ArchivePath`, must match the folder name inside the archive. |
| `-ServerPath` | FileInfo | `/Applications/Minecraft-Server` | Path to the server directory. Mutually exclusive with `-ArchivePath`. |
| `-ArchivePath` | FileInfo | _(required for archive set)_ | Path to a zip archive produced by `Backup-MinecraftServerWorld`. Expanded to a temp directory and cleaned up afterwards. |
| `-DestinationPath` | FileInfo | `~/Library/Application Support/Minecraft/saves` | Client saves directory. |
| `-Force` | switch | `$false` | Overwrite existing files in the destination. |

**Examples**

```powershell
# Convert a named world from the default server directory
ConvertTo-MinecraftSavedGame -WorldName 'HangFire0331s World'

# Convert a named world from a custom server
ConvertTo-MinecraftSavedGame -WorldName 'Survival' -ServerPath '/srv/mc/paper'

# Convert directly from a Backup-MinecraftServerWorld archive
ConvertTo-MinecraftSavedGame -WorldName 'Survival' `
                             -ArchivePath '~/Downloads/minecraft/World and Server Backups/survival-2026-05-10.zip'
```

---

## Resource Packs

Source: `source/resourcepack-functions.ps1`

### Copy-ResourcePackForTesting

Copies a resource pack directory (excluding SCM and OS metadata files) into the Minecraft client
resource packs folder with a versioned name derived from `pack.mcmeta`.

```powershell
Copy-ResourcePackForTesting [-ResourcePackName <string>] [-Path <string>]
                            [-Destination <string>] [-Force]
```

**Parameters**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-ResourcePackName` | string | `HangFire0331 Vanilla Tweaks` | Display name of the resource pack. |
| `-Path` | string | `~/Code/minecraft/resourcepacks` | Directory containing the resource pack source folder. |
| `-Destination` | string | `~/Library/Application Support/minecraft/resourcepacks` | Client resource packs directory. |
| `-Force` | switch | `$false` | Overwrite existing files at the destination. |

**Examples**

```powershell
# Copy the default pack for client testing
Copy-ResourcePackForTesting

# Copy a named pack from a custom location
Copy-ResourcePackForTesting -ResourcePackName 'MyPack' -Path '~/Projects/mc/packs'
```

---

### Compress-ResourcePackForTesting

Packages a resource pack directory into a versioned ZIP file ready for client use or server
distribution.

```powershell
Compress-ResourcePackForTesting [-ResourcePackName <string>] [-Path <string>]
                                [-Destination <string>] [-Force]
```

**Parameters**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-ResourcePackName` | string | `HangFire0331 Vanilla Tweaks` | Display name of the resource pack. |
| `-Path` | string | `~/Code/Minecraft/resourcepacks` | Directory containing the resource pack source folder. |
| `-Destination` | string | `~/Library/Application Support/minecraft/resourcepacks` | Directory where the ZIP will be written. |
| `-Force` | switch | `$false` | Overwrite an existing ZIP with the same name. Throws if the file exists and `-Force` is not set. |

**Examples**

```powershell
# Compress the default pack for distribution
Compress-ResourcePackForTesting

# Compress a named pack, overwriting any existing archive
Compress-ResourcePackForTesting -ResourcePackName 'MyPack' -Force
```

---

### Get-ResourcePackVersion

Returns the Minecraft version string for a resource pack by reading its `pack_format` value from
`pack.mcmeta` and mapping it to the corresponding Minecraft version range.

```powershell
Get-ResourcePackVersion [-Path <FileInfo>]
```

**Parameters**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-Path` | FileInfo | `~/Code/Heliar/minecraft/resourcepacks` | Directory containing the resource pack source folder. |

**Examples**

```powershell
Get-ResourcePackVersion -Path '~/Code/minecraft/resourcepacks'
```

---

### Get-ResourcePackVersionedDescription

Returns the resource pack description string appended with its Minecraft version, suitable for
display or use in pack metadata.

```powershell
Get-ResourcePackVersionedDescription [-Path <FileInfo>]
```

**Parameters**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-Path` | FileInfo | `~/Code/Heliar/minecraft/resourcepacks` | Directory containing the resource pack source folder. |

**Examples**

```powershell
Get-ResourcePackVersionedDescription -Path '~/Code/minecraft/resourcepacks'
```

---

### Get-ResourcePackMetaData

Reads and returns the parsed contents of `pack.mcmeta` for the resource pack.

```powershell
Get-ResourcePackMetaData [-Path <FileInfo>]
```

**Parameters**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-Path` | FileInfo | `~/Code/Heliar/minecraft/resourcepacks` | Directory containing the resource pack source folder. |

**Examples**

```powershell
$meta = Get-ResourcePackMetaData -Path '~/Code/minecraft/resourcepacks'
$meta.pack.pack_format
```
