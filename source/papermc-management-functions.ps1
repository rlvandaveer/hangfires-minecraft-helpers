<#


#>
function Update-PaperVersion {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Uri]$PaperDownloadUrl,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$MinecraftVersion = '1.18.2',
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[ValidateScript({
			if (-not ($_ | Test-Path)) { throw 'Source is not a valid path'}
			if (-not ($_ | Test-Path -PathType Container)) { throw 'Source is not a directory'}
			return $true
		})]
		[System.IO.FileSystemInfo[]]$ServerPath
	)

	begin {

		if ([String]::IsNullOrWhiteSpace($PaperDownloadUrl)) {

			New-Variable -Name VERSION_INFO_URI -Value "https://papermc.io/api/v2/projects/paper/versions/$MinecraftVersion/" -Option Constant -WhatIf:$false
			Write-Verbose "Retrieving Paper builds for Minecraft version $MinecraftVersion..."
			$versionInfo = Invoke-RestMethod -Uri $VERSION_INFO_URI -Method Get -StatusCodeVariable versionInfoResponseCode

			if ($null -eq $versionInfo) { Write-Error 'Could not retrieve version information for Paper'}

			$buildNumber = ($versionInfo.builds | Measure-Object -Maximum).Maximum
			Write-Verbose "Latest Paper build version number for $MinecraftVersion is $buildNumber"
			$fileUri = "https://papermc.io/api/v2/projects/paper/versions/$MinecraftVersion/builds/$buildNumber/downloads/paper-$MinecraftVersion-$buildNumber.jar"
			$fileName = Split-Path -Path $fileUri -Leaf
			$tempFile = (Join-Path -Path $env:TMPDIR -ChildPath $fileName)

			if ($PSCmdlet.ShouldProcess($fileUri, "Download Paper build")) {

				Write-Verbose "Downloading $fileName to $tempFile..."
				$response = Invoke-WebRequest -Uri $fileUri -OutFile $tempFile

			}

		} else {

			$fileName = Split-Path -Path $PaperDownloadUrl -Leaf
			$tempFile = (Join-Path -Path $env:TMPDIR -ChildPath $fileName)

			if ($PSCmdlet.ShouldProcess($fileUri, "Download Paper build")) {

				Write-Verbose "Downloading $fileName to $tempFile..."
				$response = Invoke-WebRequest -Uri $PaperDownloadUrl -OutFile $tempFile

			}

		}
	}

	process {

		if ($PSCmdlet.ShouldProcess($ServerPath, "Copy Paper build")) {

			$destination = Join-Path -Path $ServerPath -ChildPath $fileName
			Write-Verbose "Copying $fileName to $destination..."
			Copy-Item -Path $tempFile -Destination $destination

		}
	}

	end {

		if ($PSCmdlet.ShouldProcess($tempFile, "Remove Paper build from temp files")) {

			Write-Verbose "Removing $tempFile..."
			Remove-Item -Path $tempFile

		}
	}
}

# function Stop-MinecraftServer {
# 	[CmdletBinding()]
# 	param (

# 	)

# 	begin {

# 	}

# 	process {

# 	}

# 	end {

# 	}
# }