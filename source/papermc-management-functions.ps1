<#
.SYNOPSIS
	Downloads the latest Paper build and places it into the desired server paths
.DESCRIPTION
	This Cmdlet can be used to update the Paper mod in one or more server directories.
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
		[string]$MinecraftVersion = '1.19.3',
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

function Update-StartScript {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$MinecraftVersion = '1.19.3',
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
