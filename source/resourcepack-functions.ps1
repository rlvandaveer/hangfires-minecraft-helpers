function Copy-ResourcePackForTesting {
	param (
		[Parameter(Mandatory = $false)]
		[string]$ResourcePackName = "HangFire0331 Vanilla Tweaks",
		[Parameter(Mandatory = $false)]
		[string]$Path = '~/Code/Heliar/minecraft/resourcepacks',
		[Parameter(Mandatory = $false)]
		[string]$Destination = '~/Library/Application Support/minecraft/resourcepacks',
		[Parameter(Mandatory = $false)]
		[switch]$Force = $false
	)

	$Path = (Get-Item -Path $Path).FullName
	$Destination = (Get-Item -Path $Destination).FullName
	$scrubbedResourcePackName = (Get-Culture).TextInfo.ToLower(($ResourcePackName -replace ' ', '-'))
	$sourcePath = Join-Path -Path $Path -ChildPath $scrubbedResourcePackName
	[array]$excludeFilenames = @('Thumbs.db', '.DS_Store', '.git', '.gitattributes', '.gitignore')
	$resourceFiles = Get-ChildItem -Path $sourcePath -Recurse -Exclude $excludeFilenames
	$version = Get-ResourcePackVersion -Path $Path
	$versionedResourcePackName = "$scrubbedResourcePackName-$version"
	$resourcePackDestination = Join-Path -Path $Destination -ChildPath $versionedResourcePackName
	$resourceFiles | Copy-Item -Destination { Join-Path -Path $resourcePackDestination -ChildPath $_.FullName.Substring($sourcePath.Length) } -Force:$Force -Exclude $excludeFilenames
}

function Compress-ResourcePackForTesting {
	param (
		[Parameter(Mandatory = $false)]
		[string]$ResourcePackName = "HangFire0331 Vanilla Tweaks",
		[Parameter(Mandatory = $false)]
		[string]$Path = '~/Code/Minecraft/resourcepacks',
		[Parameter(Mandatory = $false)]
		[string]$Destination = '~/Library/Application Support/minecraft/resourcepacks',
		[Parameter(Mandatory = $false)]
		[switch]$Force = $false
	)

	$Path = (Get-Item -Path $Path).FullName
	$Destination = (Get-Item -Path $Destination).FullName
	$scrubbedResourcePackName = (Get-Culture).TextInfo.ToLower(($ResourcePackName -replace ' ', '-'))
	$sourcePath = Join-Path -Path $Path -ChildPath $scrubbedResourcePackName
	[array]$excludeFilenames = @('Thumbs.db', '.DS_Store', '.git', '.gitattributes', '.gitignore')
	$resourceFiles = Get-ChildItem -Path $sourcePath -Recurse -Exclude $excludeFilenames
	$tempDestination = Join-Path -Path $env:TMPDIR -ChildPath $scrubbedResourcePackName
	$version = Get-ResourcePackVersion -Path $Path
	$versionedResourcePackName = "$scrubbedResourcePackName-$version"
	$resourcePackDestination = Join-Path -Path $Destination -ChildPath "$versionedResourcePackName.zip"
	if ((Test-Path -Path $resourcePackDestination) -and ($Force -eq $false)) {
		throw "The resource pack $resourcePackDestination already exists at the destination. Use the -Force parameter to overwrite the existing archive file."
	}

	if (Test-Path -Path $tempDestination) {
		Remove-Item $tempDestination -Recurse -Force
	}
	$resourceFiles | Copy-Item -Destination {
		Join-Path -Path $tempDestination -ChildPath $_.FullName.Substring($sourcePath.Length)
	} -Force -Exclude $excludeFilenames
	Compress-Archive -Path (Join-Path -Path $tempDestination -ChildPath "*") -DestinationPath $resourcePackDestination -Force:$Force
}

function Get-ResourcePackVersion {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $false)]
		[ValidateScript( {
				if (-not ($_ | Test-Path)) { throw "The specified path is not a valid path or does not exist" }
				if (-not ($_ | Test-Path -PathType Container)) { throw "The specified path does not point to a directory destination" }
				$true
			})]
		[System.IO.FileInfo]$Path = '~/Code/Heliar/minecraft/resourcepacks'
	)

	begin {

		$packFormats = @{
			'1' = @{ min = '1.6.1'; max = '1.8.9' }
			'2' = @{ min = '1.9'; max = '1.10.2' }
			'3' = @{ min = '1.11'; max = '1.12.2' }
			'4' = @{ min = '1.13'; max = '1.14.4' }
			'5' = @{ min = '1.15'; max = '1.16.1' }
			'6' = @{ min = '1.16.2'; max = '1.16.5' }
			'7' = @{ min = '1.17'; max = '1.17.1' }
			'8' = @{ min = '1.18'; max = '1.18.2' }
			'9' = @{ min = '1.19' }
		}
	}

	process {

		$packMetaData = Get-ResourcePackMetaData -Path $Path
		$packFormat = $packMetaData.pack.pack_format

		$version = $packFormats["$packFormat"]?.version ? $packFormats["$packFormat"].version : ($packFormats["$packFormat"]?.max ? $packFormats["$packFormat"].max : "$($packFormats["$packFormat"].min)+")
		$version
	}
}

function Get-ResourcePackVersionedDescription {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $false)]
		[ValidateScript( {
				if (-not ($_ | Test-Path)) { throw "The specified path is not a valid path or does not exist" }
				if (-not ($_ | Test-Path -PathType Container)) { throw "The specified path does not point to a directory destination" }
				$true
			})]
		[System.IO.FileInfo]$Path = '~/Code/Heliar/minecraft/resourcepacks'
	)

	$packMetaData = Get-ResourcePackMetaData -Path $Path
	$description = "$($packMetaData.pack.description) for $(Get-ResourcePackVersion -Path $Path)"
	$description

}

function Get-ResourcePackMetaData {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $false)]
		[ValidateScript( {
				if (-not ($_ | Test-Path)) { throw "The specified path is not a valid path or does not exist" }
				if (-not ($_ | Test-Path -PathType Container)) { throw "The specified path does not point to a directory destination" }
				$true
			})]
		[System.IO.FileInfo]$Path = '~/Code/Heliar/minecraft/resourcepacks'
	)

	$packMetaFileName = 'pack.mcmeta'
	$Path = (Get-Item -Path $Path).FullName
	$scrubbedResourcePackName = (Get-Culture).TextInfo.ToLower(($ResourcePackName -replace ' ', '-'))
	$sourcePath = Join-Path -Path $Path -ChildPath $scrubbedResourcePackName
	$packMetaData = Get-Content -Path (Join-Path -Path $sourcePath -ChildPath $packMetaFileName) -Raw | ConvertFrom-Json -Depth 10
	$packMetaData

}