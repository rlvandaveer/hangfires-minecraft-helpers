function Update-PaperVersion {
	[CmdletBinding()]
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

			New-Variable -Name VERSION_INFO_URI -Value 'https://papermc.io/api/v2/projects/paper/versions/1.18.2/' -Option Constant
			$versionInfo = Invoke-RestMethod -Uri $VERSION_INFO_URI -Method Get -StatusCodeVariable versionInfoResponseCode

			if ($null -eq $versionInfo) { Write-Error 'Could not retrieve version information for Paper'}

			$buildNumber = ($versionInfo.builds | Measure-Object -Maximum).Maximum
			$fileUri = "https://papermc.io/api/v2/projects/paper/versions/$MinecraftVersion/builds/$buildNumber/downloads/paper-$MinecraftVersion-$buildNumber.jar"
			$fileName = Split-Path -Path $fileUri -Leaf
			$tempFile = (Join-Path -Path $env:TMPDIR -ChildPath $fileName)
			$response = Invoke-WebRequest -Uri $fileUri -OutFile $tempFile

		} else {

			$fileName = Split-Path -Path $PaperDownloadUrl -Leaf
			$tempFile = (Join-Path -Path $env:TMPDIR -ChildPath $fileName)
			$response = Invoke-WebRequest -Uri $PaperDownloadUrl -OutFile $tempFile

		}
	}

	process {

		$destination = Join-Path -Path $ServerPath -ChildPath $fileName
		Copy-Item -Path $tempFile -Destination $destination

	}

	end {

		Remove-Item -Path $tempFile

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