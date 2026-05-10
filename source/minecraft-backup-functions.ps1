
<#
.SYNOPSIS
Archives a single-player Minecraft saved game into a dated zip file.

.DESCRIPTION
Compresses a saved game folder from the Minecraft client's saves directory into
a zip archive named after the saved game and the supplied date. The archive name
is lowercased with spaces replaced by hyphens (e.g. "HangFire0331s World" becomes
		"hangfire0331s-world-2026-05-08.zip").

.PARAMETER SavedGameName
Name of the saved game folder under SavesPath. Defaults to "HangFire0331s World".

.PARAMETER DestinationPath
Directory where the zip archive will be written. Must exist.

.PARAMETER Date
Date used in the archive filename. Defaults to today.

.PARAMETER Force
Overwrite an existing archive at the destination.

.PARAMETER SavesPath
Directory containing the saved game folder. Defaults to the macOS Minecraft
client saves location.

.EXAMPLE
Backup-MinecraftSavedGame -SavedGameName 'Familycraft'

Backs up the "Familycraft" saved game to today's archive in the default
destination.
#>
function Backup-MinecraftSavedGame {
	param (
		[Parameter(Mandatory = $false)]
		[string]$SavedGameName = 'HangFire0331s World',
		[Parameter(Mandatory = $false)]
		[ValidateScript({
			if (-not ($_ | Test-Path)) { throw 'Source is not a valid path'}
			if (-not ($_ | Test-Path -PathType Container)) { throw 'Source is not a directory'}
			$true
		})]
		[System.IO.FileInfo]$DestinationPath = '~/Downloads/minecraft/World and Server Backups',
		[Parameter(Mandatory = $false)]
		[DateTime]$Date = [DateTime]::Today,
		[Parameter(Mandatory = $false)]
		[switch]$Force = $false,
		[Parameter(Mandatory = $false)]
		[ValidateScript({
			if (-not ($_ | Test-Path)) { throw 'SavesPath is not a valid path'}
			if (-not ($_ | Test-Path -PathType Container)) { throw 'SavesPath is not a directory'}
			$true
		})]
		[System.IO.FileInfo]$SavesPath = '~/Library/ApplicationSupport/minecraft/saves/'
	)

	$savedGamePath = Join-Path -Path $SavesPath -ChildPath $SavedGameName
	$formattedDate = $Date.ToString('yyyy-MM-dd')
	$scrubbedSavedGameName = (Get-Culture).TextInfo.ToLower(($SavedGameName -replace ' ', '-'))
	Compress-Archive -Path $savedGamePath `
					 -DestinationPath (Join-Path -Path $DestinationPath -ChildPath "$scrubbedSavedGameName-$formattedDate.zip") `
					 -Force:$Force
}

<#
.SYNOPSIS
Expands a saved-game backup archive into the Minecraft client's saves directory.

.DESCRIPTION
Locates the archive matching SavedGameName and Date in SourcePath and expands it
into SavesPath. The archive name is derived by title-casing SavedGameName with
spaces replaced by hyphens and appending the formatted date.

.PARAMETER SavedGameName
Name of the saved game to restore. Used to locate the archive file.

.PARAMETER SourcePath
Directory containing the backup archive. Must exist.

.PARAMETER Date
Date portion of the archive filename to restore. Defaults to today.

.PARAMETER Force
Overwrite existing files in the destination during expansion.

.PARAMETER SavesPath
Target Minecraft client saves directory. Defaults to the macOS location.

.EXAMPLE
Restore-MinecraftSavedGame -SavedGameName 'Familycraft' -Date '2026-05-08'

Restores the Familycraft world from the 2026-05-08 archive.
#>
function Restore-MinecraftSavedGame {
	param (
		[Parameter(Mandatory = $false)]
		[string]$SavedGameName = 'HangFire0331s World',
		[Parameter(Mandatory = $false)]
		[ValidateScript({
			if (-not ($_ | Test-Path)) { throw 'Source is not a valid path'}
			if (-not ($_ | Test-Path -PathType Container)) { throw 'Source is not a directory'}
			$true
		})]
		[System.IO.FileInfo]$SourcePath = '~/Downloads/minecraft/World and Server Backups',
		[Parameter(Mandatory = $false)]
		[DateTime]$Date = [DateTime]::Today,
		[Parameter(Mandatory = $false)]
		[switch]$Force = $false,
		[Parameter(Mandatory = $false)]
		[ValidateScript({
			if (-not ($_ | Test-Path)) { throw 'SavesPath is not a valid path'}
			if (-not ($_ | Test-Path -PathType Container)) { throw 'SavesPath is not a directory'}
			$true
		})]
		[System.IO.FileInfo]$SavesPath = '~/Library/ApplicationSupport/minecraft/saves/'
	)

	$formattedDate = $Date.ToString('yyyy-MM-dd')
	$scrubbedSavedGameName = (Get-Culture).TextInfo.ToTitleCase(($SavedGameName -replace ' ', '-'))
	Expand-Archive -Path (Join-Path -Path $SourcePath -ChildPath "$scrubbedSavedGameName-$formattedDate.zip") `
				   -DestinationPath $SavesPath `
				   -Force:$Force
}

<#
.SYNOPSIS
Archives a PaperMC server world folder into a dated zip file.

.DESCRIPTION
	Compresses the world folder under ServerPath into a zip archive in
DestinationPath. PaperMC nests all dimensions (overworld, the_nether, the_end)
	beneath <WorldName>/dimensions/minecraft/, so a single folder captures the
	entire world.

	.PARAMETER WorldName
	Name of the world folder under ServerPath. This must match the level-name in
	server.properties.

	.PARAMETER DestinationPath
	Directory where the zip archive will be written. Must exist.

	.PARAMETER Date
	Date used in the archive filename. Defaults to today.

	.PARAMETER Force
	Overwrite an existing archive at the destination.

	.PARAMETER ServerPath
	Root directory of the PaperMC server installation containing the world folder.

	.EXAMPLE
	Backup-MinecraftServerWorld -WorldName 'Familycraft' -ServerPath '/Applications/Minecraft-Server-Familycraft'

	Backs up the Familycraft server world to today's archive.

	.EXAMPLE
	Get-Item /Applications/minecraft-Server-* | ForEach-Object {
		Backup-MinecraftServerWorld -WorldName ($_.Name -replace '^Minecraft-Server-') -ServerPath $_.FullName
	}

Backs up every PaperMC server installed under /Applications.
#>
function Backup-MinecraftServerWorld {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $false)]
		[string]$WorldName = 'HangFire0331s World',
		[Parameter(Mandatory = $false)]
		[ValidateScript({
			if (-not ($_ | Test-Path)) { throw 'Destination is not a valid path'}
			if (-not ($_ | Test-Path -PathType Container)) { throw 'Destination is not a directory'}
			$true
		})]
		[System.IO.FileInfo]$DestinationPath = '~/Downloads/minecraft/World and Server Backups',
		[Parameter(Mandatory = $false)]
		[DateTime]$Date = [DateTime]::Today,
		[Parameter(Mandatory = $false)]
		[switch]$Force = $false,
		[Parameter(Mandatory = $false)]
		[ValidateScript({
			if (-not ($_ | Test-Path)) { throw 'ServerPath is not a valid path'}
			if (-not ($_ | Test-Path -PathType Container)) { throw 'ServerPath is not a directory'}
			$true
		})]
		[System.IO.FileInfo]$ServerPath = '/Applications/Minecraft-Server'
	)

	$worldPath = Join-Path -Path $ServerPath -ChildPath $WorldName
	$scrubbedWorldName = (Get-Culture).TextInfo.ToLower(($WorldName -replace ' ', '-'))
	$formattedDate = $Date.ToString('yyyy-MM-dd')

	Compress-Archive -Path $worldPath `
					 -DestinationPath (Join-Path -Path $DestinationPath -ChildPath "$scrubbedWorldName-$formattedDate.zip") `
					 -Force:$Force
}

<#
.SYNOPSIS
Expands a server-world backup archive into a PaperMC server folder.

.DESCRIPTION
Locates the archive matching WorldName and Date in SourcePath and expands it
into ServerPath, restoring the world folder (and its nested dimensions) in
place.

.PARAMETER WorldName
Name of the world to restore. Used to locate the archive file.

.PARAMETER SourcePath
Directory containing the backup archive. Must exist.

.PARAMETER Date
Date portion of the archive filename to restore. Defaults to today.

.PARAMETER Force
Overwrite existing files in the server folder during expansion.

.PARAMETER ServerPath
Root directory of the PaperMC server installation. Must exist.

.EXAMPLE
Restore-MinecraftServerWorld -WorldName 'Familycraft' -ServerPath '/Applications/Minecraft-Server-Familycraft' -Date '2026-05-08'

Restores the Familycraft world from the 2026-05-08 archive into the server
directory.
#>
function Restore-MinecraftServerWorld {
	param (
		[Parameter(Mandatory = $false)]
		[string]$WorldName = 'HangFire0331s World',
		[Parameter(Mandatory = $false)]
		[ValidateScript({
			if (-not ($_ | Test-Path)) { throw 'Destination is not a valid path'}
			if (-not ($_ | Test-Path -PathType Container)) { throw 'Destination is not a directory'}
			$true
		})]
		[System.IO.FileInfo]$SourcePath = '~/Downloads/minecraft/World and Server Backups',
		[Parameter(Mandatory = $false)]
		[DateTime]$Date = [DateTime]::Today,
		[Parameter(Mandatory = $false)]
		[switch]$Force = $false,
		[Parameter(Mandatory = $false)]
		[ValidateScript({
			if (-not ($_ | Test-Path)) { throw 'ServerPath is not a valid path'}
			if (-not ($_ | Test-Path -PathType Container)) { throw 'ServerPath is not a directory'}
			$true
		})]
		[System.IO.FileInfo]$ServerPath = '/Applications/Minecraft-Server'
	)

	$formattedDate = $Date.ToString('yyyy-MM-dd')
	$scrubbedWorldName = (Get-Culture).TextInfo.ToTitleCase(($WorldName -replace ' ', '-'))
	Expand-Archive -Path (Join-Path -Path $SourcePath -ChildPath "$scrubbedWorldName-$formattedDate.zip") `
				   -DestinationPath $ServerPath `
				   -Force:$Force
}

<#
.SYNOPSIS
Converts a PaperMC server world into a vanilla Minecraft client saved game.

.DESCRIPTION
Copies a PaperMC server world to the client's saves directory and rewrites the
dimension layout to match the vanilla client format:

- Promotes <world>/dimensions/minecraft/overworld/{region,entities,poi} up to
the world root.
- Renames <world>/dimensions/minecraft/the_nether to DIM-1.
- Renames <world>/dimensions/minecraft/the_end to DIM1.
- Removes the now-empty dimensions folder.

Paper-specific files (e.g. paper-world.yml, data/paper) are carried along with
their dimension folders. The vanilla client ignores them.

The source world can be supplied either as a directory under ServerPath or as a
backup archive produced by Backup-MinecraftServerWorld. When ArchivePath is
used, the archive is expanded into a temporary directory, converted, and the
temporary directory is removed afterwards.

.PARAMETER WorldName
Name of the world folder. When using ServerPath, this is the folder under the
server directory. When using ArchivePath, this must match the world folder
contained in the archive (Backup-MinecraftServerWorld preserves the original
folder name).

.PARAMETER DestinationPath
Minecraft client saves directory. Must exist. The converted world is written
to <DestinationPath>/<WorldName>.

.PARAMETER Force
Overwrite existing files in the destination saved game.

.PARAMETER ServerPath
Root directory of the PaperMC server installation containing the world folder.

.PARAMETER ArchivePath
Path to a zip archive produced by Backup-MinecraftServerWorld. The archive is
expanded into a temporary directory for the conversion, then deleted.

.EXAMPLE
ConvertTo-MinecraftSavedGame -WorldName 'Familycraft' -ServerPath '/Applications/Minecraft-Server-Familycraft'

Converts the Familycraft server world into a single-player saved game in the
default saves directory.

.EXAMPLE
ConvertTo-MinecraftSavedGame -WorldName 'Familycraft' -ArchivePath '~/Downloads/minecraft/World and Server Backups/familycraft-2026-05-10.zip'

Expands the Familycraft backup archive to a temporary directory, converts it
into a single-player saved game, and cleans up the temporary files.
#>
function ConvertTo-MinecraftSavedGame {
	[CmdletBinding(DefaultParameterSetName = 'FromServer')]
	param (
		[Parameter(Mandatory = $true)]
		[string]$WorldName,
		[Parameter(Mandatory = $false, ParameterSetName = 'FromServer')]
		[ValidateScript({
			if (-not ($_ | Test-Path)) { throw 'ServerPath is not a valid path'}
			if (-not ($_ | Test-Path -PathType Container)) { throw 'ServerPath is not a directory'}
			$true
			})]
		[System.IO.FileInfo]$ServerPath = '/Applications/Minecraft-Server',
		[Parameter(Mandatory = $true, ParameterSetName = 'FromArchive')]
		[ValidateScript({
			if (-not ($_ | Test-Path)) { throw 'ArchivePath is not a valid path'}
			if (-not ($_ | Test-Path -PathType Leaf)) { throw 'ArchivePath is not a file'}
			$true
		})]
		[System.IO.FileInfo]$ArchivePath,
		[Parameter(Mandatory = $false)]
		[ValidateScript({
			if (-not ($_ | Test-Path)) { throw 'Destination is not a valid path'}
			if (-not ($_ | Test-Path -PathType Container)) { throw 'Destination is not a directory'}
			$true
		})]
		[System.IO.FileInfo]$DestinationPath = '~/Library/Application Support/Minecraft/saves',
		[Parameter(Mandatory = $false)]
		[switch]$Force = $false
	)

	$tempPath = $null
	try {
		if ($PSCmdlet.ParameterSetName -eq 'FromArchive') {
			$tempPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.IO.Path]::GetRandomFileName())
			New-Item -ItemType Directory -Path $tempPath | Out-Null
			Expand-Archive -Path $ArchivePath -DestinationPath $tempPath -Force
			$worldRoot = $tempPath
		} else {
			$worldRoot = $ServerPath
		}

		$worldPath = Join-Path -Path $worldRoot -ChildPath $WorldName
		$savePath = Join-Path -Path $DestinationPath -ChildPath $WorldName
		$dimensionsPath = Join-Path -Path $savePath -ChildPath 'dimensions/minecraft'

		Copy-Item -Path $worldPath -Destination $DestinationPath -Recurse -Force:$Force

		$overworldPath = Join-Path -Path $dimensionsPath -ChildPath 'overworld'
		foreach ($folder in 'region', 'entities', 'poi') {
			$source = Join-Path -Path $overworldPath -ChildPath $folder
			if (Test-Path $source) {
				Move-Item -Path $source -Destination $savePath -Force:$Force
			}
		}

		$netherPath = Join-Path -Path $dimensionsPath -ChildPath 'the_nether'
		if (Test-Path $netherPath) {
			Move-Item -Path $netherPath -Destination (Join-Path -Path $savePath -ChildPath 'DIM-1') -Force:$Force
		}
		$endPath = Join-Path -Path $dimensionsPath -ChildPath 'the_end'
		if (Test-Path $endPath) {
			Move-Item -Path $endPath -Destination (Join-Path -Path $savePath -ChildPath 'DIM1') -Force:$Force
		}

		Remove-Item -Path (Join-Path -Path $savePath -ChildPath 'dimensions') -Recurse -Force:$Force
	}
	finally {
		if ($tempPath -and (Test-Path $tempPath)) {
			Remove-Item -Path $tempPath -Recurse -Force
		}
	}
}
