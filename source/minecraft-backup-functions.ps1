

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

	$worldPaths = @(Join-Path -Path $ServerPath -ChildPath $WorldName
					Join-Path -Path $ServerPath -ChildPath "$($WorldName)_nether"
					Join-Path -Path $ServerPath -ChildPath "$($WorldName)_the_end")
	$scrubbedWorldName = (Get-Culture).TextInfo.ToLower(($WorldName -replace ' ', '-'))
	$formattedDate = $Date.ToString('yyyy-MM-dd')

	Compress-Archive -Path $worldPaths `
					 -DestinationPath (Join-Path -Path $DestinationPath -ChildPath "$scrubbedWorldName-$formattedDate.zip") `
					 -Force:$Force
}

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

function ConvertTo-MinecraftSavedGame {
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
		[System.IO.FileInfo]$DestinationPath = '~/Library/Application Support/Minecraft/saves',
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

	$worldPath = (Join-Path -Path $ServerPath -ChildPath $WorldName)
	$netherPath = Join-Path -Path $ServerPath -ChildPath "$($WorldName)_nether"
	$endPath = Join-Path -Path $ServerPath -ChildPath "$($WorldName)_the_end"
	$savePath = (Join-Path -Path $DestinationPath -ChildPath $WorldName)
	$netherFolderName = 'DIM-1'
	$endFolderName = 'DIM1'
	Copy-Item -Path $worldPath -Destination $DestinationPath -Recurse -Force:$Force
	Copy-Item -Path (Join-Path $netherPath -ChildPath $netherFolderName) -Destination (Join-Path -Path $savePath -ChildPath $netherFolderName) -Recurse -Force:$Force
	Copy-Item -Path (Join-Path $endPath -ChildPath $endFolderName) -Destination (Join-Path -Path $savePath -ChildPath $endFolderName) -Recurse -Force:$Force
}