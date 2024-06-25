<#
.SYNOPSIS
	Downloads the latest Paper build and places it into the desired server paths
.DESCRIPTION
	This Cmdlet can be used to update the Paper server JAR file in one or more server directories.
.PARAMETER PaperDownloadUri
	Overrides the default download Uri for Paper
.PARAMETER MinecraftVersion
	The version of Minecraft to find builds for
.PARAMETER ServerPath
	An array of paths where the Paper build should be copied to
#>
function Update-PaperVersion {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Uri]$PaperDownloadUri,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$MinecraftVersion = '1.21',
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[ValidateScript({
			if (-not ($_ | Test-Path)) { throw 'Source is not a valid path'}
			if (-not ($_ | Test-Path -PathType Container)) { throw 'Source is not a directory'}
			$true
		})]
		[System.IO.FileSystemInfo[]]$ServerPath
	)

	begin {

		if ([String]::IsNullOrWhiteSpace($PaperDownloadUri)) {

			New-Variable -Name VERSION_INFO_URI -Value "https://api.papermc.io/v2/projects/paper/versions/$MinecraftVersion/" -Option Constant -WhatIf:$false
			Write-Verbose "Retrieving Paper builds for Minecraft version $MinecraftVersion..."
			$versionInfo = Invoke-RestMethod -Uri $VERSION_INFO_URI -Method Get -StatusCodeVariable versionInfoResponseCode

			if ($null -eq $versionInfo) {
				throw 'Could not retrieve version information for Paper'
			}

			$buildNumber = ($versionInfo.builds | Measure-Object -Maximum).Maximum
			Write-Verbose "Latest Paper build version number for $MinecraftVersion is $buildNumber"
			$fileUri = "https://api.papermc.io/v2/projects/paper/versions/$MinecraftVersion/builds/$buildNumber/downloads/paper-$MinecraftVersion-$buildNumber.jar"
			$fileName = Split-Path -Path $fileUri -Leaf
			$tempFile = (Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $fileName)

			if ($PSCmdlet.ShouldProcess($fileUri, "Download Paper build")) {

				Write-Verbose "Downloading $fileName to $tempFile..."
				$response = Invoke-WebRequest -Uri $fileUri -OutFile $tempFile

			}

		} else {

			$fileName = Split-Path -Path $PaperDownloadUri -Leaf
			$tempFile = (Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $fileName)

			if ($PSCmdlet.ShouldProcess($fileUri, "Download Paper build")) {

				Write-Verbose "Downloading $fileName to $tempFile..."
				$response = Invoke-WebRequest -Uri $PaperDownloadUri -OutFile $tempFile

			}

		}
	}

	process {

		$maxPaperVer = ((Get-ChildItem -Path (Join-Path -Path $ServerPath -ChildPath "paper-$MinecraftVersion*")).Name | Measure-Object -Maximum).Maximum
		if ($null -eq $maxPaperVer) {

			Write-Verbose "Did not find a version of Paper for Minecraft version $MinecraftVersion. Looking for another version..."
			$maxPaperVer = ((Get-ChildItem -Path (Join-Path -Path $ServerPath -ChildPath "paper-*")).Name | Measure-Object -Maximum).Maximum

		}

		Write-Verbose "Max Version of PaperMC in $ServerPath is $maxPaperVer"

		if ($PSCmdlet.ShouldProcess($ServerPath, "Copy Paper build")) {

			$destination = Join-Path -Path $ServerPath -ChildPath $fileName
			Write-Verbose "Copying $fileName to $destination..."
			Copy-Item -Path $tempFile -Destination $destination

		}

		if ($PSCmdlet.ShouldProcess($ServerPath, "Update start script")) {

			Update-StartScript -MinecraftVersion $MinecraftVersion -PreviousPaperJar $maxPaperVer -NewPaperBuild $buildNumber -ServerPath $ServerPath

		}

	}

	end {

		if ($PSCmdlet.ShouldProcess($tempFile, "Remove Paper build from temp files")) {

			Write-Verbose "Removing $tempFile..."
			Remove-Item -Path $tempFile

		}
	}
}

<#
.SYNOPSIS
	Updates the start-up script in the server path(s) to the latest paper version.
.DESCRIPTION
	This commandlet finds the previous minecraft version in the start-up script and replaces it with the new version.
.PARAMETER MinecraftVersion
	The version of Minecraft to target
.PARAMETER PreviousPaperJar
	The previous Paper JAR file
.PARAMETER NewPaperBuild
	The new Paper build number
.PARAMETER ServerPath
	The path(s) to the server directories to update
#>
function Update-StartScript {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$MinecraftVersion = '1.21',
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		$PreviousPaperJar,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[int]$NewPaperBuild,
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[ValidateScript({
			if (-not ($_ | Test-Path)) { throw 'Source is not a valid path'}
			if (-not ($_ | Test-Path -PathType Container)) { throw 'Source is not a directory'}
			$true
		})]
		[System.IO.FileSystemInfo[]]$ServerPath
	)

	begin {

	}

	process {

		New-Variable -Name SCRIPT_NAME -Value "start.ps1" -Option Constant
		$scriptPath = (Join-Path -Path $ServerPath -ChildPath $SCRIPT_NAME)
		$newPaperJar = "paper-$MinecraftVersion-$NewPaperBuild.jar"
		Write-Verbose "Updating $SCRIPT_NAME from $PreviousPaperJar to $newPaperJar..."
		(Get-Content -Path $scriptPath) -replace $PreviousPaperJar, $newPaperJar | Set-Content $scriptPath

	}

	end {

	}
}

<#
.SYNOPSIS
	This commandlet will create a new Paper server with default files
.DESCRIPTION

.PARAMETER PaperDownloadUri
	The URL where to download the Paper files. This only needs to be set if overriding the default location
.PARAMETER MinecraftVersion
	The Minecraft version to target
.PARAMETER WorldName
	The name of the new server world
.PARAMETER ServerPath
	The path(s) to the server directory(ies)
#>
function New-PaperServer {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Uri]$PaperDownloadUri,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$MinecraftVersion = '1.21',
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$WorldName,
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[ValidateScript({
			if ($_ | Test-Path) { throw 'Source is an existing path'}
			if (-not ($_ | Test-Path -IsValid)) { throw 'Source is not a valid path syntax'}
			$true
		})]
		[string]$ServerPath
	)

	begin {

		if ([String]::IsNullOrWhiteSpace($PaperDownloadUri)) {

			New-Variable -Name VERSION_INFO_URI -Value "https://api.papermc.io/v2/projects/paper/versions/$MinecraftVersion/" -Option Constant -WhatIf:$false
			Write-Verbose "Retrieving Paper builds for Minecraft version $MinecraftVersion..."
			$versionInfo = Invoke-RestMethod -Uri $VERSION_INFO_URI -Method Get -StatusCodeVariable versionInfoResponseCode

			if ($null -eq $versionInfo) {
				throw 'Could not retrieve version information for Paper'
			}

			$buildNumber = ($versionInfo.builds | Measure-Object -Maximum).Maximum
			Write-Verbose "Latest Paper build version number for $MinecraftVersion is $buildNumber"
			$fileUri = "https://api.papermc.io/v2/projects/paper/versions/$MinecraftVersion/builds/$buildNumber/downloads/paper-$MinecraftVersion-$buildNumber.jar"
			$fileName = Split-Path -Path $fileUri -Leaf
			$tempFile = (Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $fileName)

			if ($PSCmdlet.ShouldProcess($fileUri, "Download Paper build")) {

				Write-Verbose "Downloading $fileName to $tempFile..."
				$response = Invoke-WebRequest -Uri $fileUri -OutFile $tempFile

			}

		} else {

			$fileName = Split-Path -Path $PaperDownloadUri -Leaf
			$tempFile = (Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $fileName)

			if ($PSCmdlet.ShouldProcess($fileUri, "Download Paper build")) {

				Write-Verbose "Downloading $fileName to $tempFile..."
				$response = Invoke-WebRequest -Uri $PaperDownloadUri -OutFile $tempFile

			}

		}

	}

	process {

		if ($PSCmdlet.ShouldProcess($ServerPath, "Create server game directory")) {

			Write-Verbose "Creating $ServerPath..."
			New-Item -Path $ServerPath -ItemType Directory

		}

		if ($PSCmdlet.ShouldProcess($ServerPath, "Create base files")) {

			Write-Verbose "Cloning base server directory..."
			git clone --depth=1 git@github.com:rlvandaveer/hangfires-papermc-base-server.git $ServerPath
			Remove-Item -Path (Join-Path -Path $ServerPath -ChildPath '.git') -Recurse -Force

			New-Variable -Name SCRIPT_NAME -Value "start.ps1" -Option Constant
			Write-Verbose "Preparing startup script $SCRIPT_NAME..."

			New-Variable -Name TEMPLATE_VALUE -Value '{{paper.jar}}' -Option Constant
			Write-Verbose "Rename startup template file $TEMPLATE_VALUE..."
			$scriptPath = (Join-Path -Path $ServerPath -ChildPath $SCRIPT_NAME)
			Rename-Item -Path (Join-Path -Path $ServerPath -ChildPath start-template.ps1) -NewName $scriptPath

			Write-Verbose "Updating $SCRIPT_NAME to execute $fileName..."
			(Get-Content -Path $scriptPath) -replace $TEMPLATE_VALUE, $fileName | Set-Content $scriptPath

		}

		if ($PSCmdlet.ShouldProcess($ServerPath, "Copy Paper build")) {

			$destination = Join-Path -Path $ServerPath -ChildPath $fileName
			Write-Verbose "Copying $fileName to $destination..."
			Copy-Item -Path $tempFile -Destination $destination

		}

	}

	end {


	}

}
