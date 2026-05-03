<#
.SYNOPSIS
	Retrieves the latest Paper build information for a given Minecraft version
.DESCRIPTION
	Queries the PaperMC Fill GraphQL API and returns build metadata for the specified
	Minecraft version. When no version is supplied, the function auto-detects the latest
	Paper version that has at least one stable build. Use -AllowUnstable to include
	alpha and beta builds.
.PARAMETER MinecraftVersion
	The Paper version to query (e.g. '26.1.2'). Omit to auto-detect the latest stable version.
.PARAMETER AllowUnstable
	When set, includes alpha and beta builds in addition to stable builds. A warning is
	written when a non-stable build is returned.
.OUTPUTS
	PSCustomObject with Version, BuildNumber, FileName, and DownloadUrl properties
#>
function Get-LatestPaperBuild {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $false)]
		[string]$MinecraftVersion,
		[Parameter(Mandatory = $false)]
		[switch]$AllowUnstable
	)

	New-Variable -Name FILL_GRAPHQL_URI -Value 'https://fill.papermc.io/graphql' -Option Constant -WhatIf:$false

	if (-not [string]::IsNullOrWhiteSpace($MinecraftVersion)) {

		Write-Verbose "Querying Fill API for Paper version '$MinecraftVersion'..."
		$query = '{ project(key: "paper") { version(key: "' + $MinecraftVersion + '") { key builds(last: 100) { nodes { number channel downloads { name url } } } } } }'
		$response = Invoke-RestMethod -Uri $FILL_GRAPHQL_URI -Method Post -ContentType 'application/json' -Body (ConvertTo-Json @{ query = $query } -Compress)

		if ($response.errors) {
			throw "Fill API error: $($response.errors[0].message)"
		}

		if ($null -eq $response.data.project.version) {
			throw "Paper version '$MinecraftVersion' was not found."
		}

		$builds = $response.data.project.version.builds.nodes

		$selectedBuild = if ($AllowUnstable) {
			$builds | Sort-Object number -Descending | Select-Object -First 1
		} else {
			$builds | Where-Object { $_.channel -eq 'STABLE' } | Sort-Object number -Descending | Select-Object -First 1
		}

		if ($null -eq $selectedBuild) {
			throw "No stable builds found for Paper version '$MinecraftVersion'. Use -AllowUnstable to include non-stable builds."
		}

	} else {

		Write-Verbose 'No version specified. Auto-detecting latest Paper version...'
		$familiesQuery = '{ project(key: "paper") { families { key } } }'
		$familiesResponse = Invoke-RestMethod -Uri $FILL_GRAPHQL_URI -Method Post -ContentType 'application/json' -Body (ConvertTo-Json @{ query = $familiesQuery } -Compress)

		if ($familiesResponse.errors) {
			throw "Fill API error: $($familiesResponse.errors[0].message)"
		}

		$families = $familiesResponse.data.project.families
		$selectedBuild = $null

		foreach ($family in $families) {
			$versionsQuery = '{ project(key: "paper") { versions(last: 20, filterBy: { familyKey: "' + $family.key + '" }) { nodes { key builds(last: 100) { nodes { number channel downloads { name url } } } } } } }'
			$versionsResponse = Invoke-RestMethod -Uri $FILL_GRAPHQL_URI -Method Post -ContentType 'application/json' -Body (ConvertTo-Json @{ query = $versionsQuery } -Compress)

			if ($versionsResponse.errors) {
				throw "Fill API error: $($versionsResponse.errors[0].message)"
			}

			$versions = @($versionsResponse.data.project.versions.nodes)
			[array]::Reverse($versions)

			foreach ($version in $versions) {
				$candidate = if ($AllowUnstable) {
					$version.builds.nodes | Sort-Object number -Descending | Select-Object -First 1
				} else {
					$version.builds.nodes | Where-Object { $_.channel -eq 'STABLE' } | Sort-Object number -Descending | Select-Object -First 1
				}

				if ($null -ne $candidate) {
					$selectedBuild = $candidate
					$MinecraftVersion = $version.key
					break
				}
			}

			if ($null -ne $selectedBuild) { break }
		}

		if ($null -eq $selectedBuild) {
			$channelMsg = if ($AllowUnstable) { '' } else { ' with stable channel' }
			throw "No Paper builds found$channelMsg."
		}
	}

	if ($selectedBuild.channel -ne 'STABLE') {
		Write-Warning "The selected build ($MinecraftVersion-$($selectedBuild.number)) is not a stable release (channel: $($selectedBuild.channel))."
	}

	Write-Verbose "Selected Paper build: $MinecraftVersion-$($selectedBuild.number) ($($selectedBuild.channel))"

	$download = $selectedBuild.downloads | Select-Object -First 1

	return [PSCustomObject]@{
		Version     = $MinecraftVersion
		BuildNumber = $selectedBuild.number
		FileName    = $download.name
		DownloadUrl = $download.url
	}
}

<#
.SYNOPSIS
	Downloads the latest Paper build and places it into the desired server paths
.DESCRIPTION
	This Cmdlet can be used to update the Paper server JAR file in one or more server
	directories. When no MinecraftVersion is specified, the latest stable Paper version
	is auto-detected from the Fill API. This cmdlet supports ShouldProcess.
.PARAMETER PaperDownloadUri
	Overrides the default download Uri for Paper. When provided, the Fill API is not
	consulted and Update-StartScript is not called.
.PARAMETER MinecraftVersion
	The Paper version to download (e.g. '26.1.2'). Omit to auto-detect the latest stable version.
.PARAMETER AllowUnstable
	When set, allows downloading alpha or beta builds when no stable build exists for the
	requested version.
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
		[string]$MinecraftVersion,
		[Parameter(Mandatory = $false)]
		[switch]$AllowUnstable,
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[ValidateScript({
			if (-not ($_ | Test-Path)) { throw 'Source is not a valid path'}
			if (-not ($_ | Test-Path -PathType Container)) { throw 'Source is not a directory'}
			$true
		})]
		[System.IO.FileSystemInfo[]]$ServerPath
	)

	begin {

		$buildNumber = $null

		if ([String]::IsNullOrWhiteSpace($PaperDownloadUri)) {

			$buildInfo = Get-LatestPaperBuild -MinecraftVersion $MinecraftVersion -AllowUnstable:$AllowUnstable
			$MinecraftVersion = $buildInfo.Version
			$buildNumber = $buildInfo.BuildNumber
			$fileUri = $buildInfo.DownloadUrl
			$fileName = $buildInfo.FileName
			$tempFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $fileName

			if ($PSCmdlet.ShouldProcess($fileUri, "Download Paper build")) {

				Write-Verbose "Downloading $fileName to $tempFile..."
				Invoke-WebRequest -Uri $fileUri -OutFile $tempFile

			}

		} else {

			$fileName = Split-Path -Path $PaperDownloadUri -Leaf
			$tempFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $fileName

			if ($PSCmdlet.ShouldProcess($PaperDownloadUri, "Download Paper build")) {

				Write-Verbose "Downloading $fileName to $tempFile..."
				Invoke-WebRequest -Uri $PaperDownloadUri -OutFile $tempFile

			}

		}
	}

	process {

		if ($PSCmdlet.ShouldProcess($ServerPath, "Copy Paper build")) {

			$destination = Join-Path -Path $ServerPath -ChildPath $fileName
			Write-Verbose "Copying $fileName to $destination..."
			Copy-Item -Path $tempFile -Destination $destination

		}

		if ($null -ne $buildNumber) {

			$maxPaperVer = ((Get-ChildItem -Path (Join-Path -Path $ServerPath -ChildPath "paper-$MinecraftVersion*")).Name | Measure-Object -Maximum).Maximum
			if ($null -eq $maxPaperVer) {

				Write-Verbose "Did not find a version of Paper for Minecraft version $MinecraftVersion. Looking for another version..."
				$maxPaperVer = ((Get-ChildItem -Path (Join-Path -Path $ServerPath -ChildPath "paper-*")).Name | Measure-Object -Maximum).Maximum

			}

			if ($maxPaperVer -gt 0) {

				Write-Verbose "Max Version of PaperMC in $ServerPath is $maxPaperVer"
				Update-StartScript -MinecraftVersion $MinecraftVersion -PreviousPaperJar $maxPaperVer -NewPaperBuild $buildNumber -ServerPath $ServerPath

			} else {
				Write-Warning "No Version of PaperMC found in $ServerPath. Cannot update server launch script."
			}

		} else {

			Write-Verbose "Skipping start script update — call Update-StartScript manually when using a custom download URI."

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
	This commandlet finds the previous minecraft version in the start-up script and
	replaces it with the new version. This cmdlet supports ShouldProcess.
.PARAMETER MinecraftVersion
	The Paper version being targeted (e.g. '26.1.2')
.PARAMETER PreviousPaperJar
	The previous Paper JAR filename to replace
.PARAMETER NewPaperBuild
	The new Paper build number
.PARAMETER ServerPath
	The path(s) to the server directories to update
#>
function Update-StartScript {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$MinecraftVersion,
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

	begin { }

	process {

		New-Variable -Name SCRIPT_NAME -Value "start.ps1" -Option Constant
		$scriptPath = (Join-Path -Path $ServerPath -ChildPath $SCRIPT_NAME)
		$startExists = Test-Path -Path $scriptPath

		if ($PSCmdlet.ShouldProcess($ServerPath, "Update start script")) {

			if (-not $startExists) { throw "$scriptPath does not exist in the directory. Cannot continue with automatic update."}
			$newPaperJar = "paper-$MinecraftVersion-$NewPaperBuild.jar"
			Write-Verbose "Updating $SCRIPT_NAME from $PreviousPaperJar to $newPaperJar..."
			(Get-Content -Path $scriptPath) -replace $PreviousPaperJar, $newPaperJar | Set-Content $scriptPath

		} elseif (-not $startExists) {
			Write-Warning "$scriptPath does not exist. Command will fail when run without -WhatIf"
		}
	}

	end { }
}

<#
.SYNOPSIS
	This commandlet will create a new Paper server with default files
.DESCRIPTION
	This creates one or more Paper Minecraft servers using the latest version of Paper
	and a set of default files from Hangfires-PaperMC-Base-Server repo. When no
	MinecraftVersion is specified, the latest stable Paper version is auto-detected.
	This cmdlet supports ShouldProcess.
.PARAMETER PaperDownloadUri
	The URL where to download the Paper files. Skips the Fill API when provided.
.PARAMETER MinecraftVersion
	The Paper version to use (e.g. '26.1.2'). Omit to auto-detect the latest stable version.
.PARAMETER AllowUnstable
	When set, allows using alpha or beta builds when no stable build exists for the
	requested version.
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
		[string]$MinecraftVersion,
		[Parameter(Mandatory = $false)]
		[switch]$AllowUnstable,
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

			$buildInfo = Get-LatestPaperBuild -MinecraftVersion $MinecraftVersion -AllowUnstable:$AllowUnstable
			$MinecraftVersion = $buildInfo.Version
			$fileUri = $buildInfo.DownloadUrl
			$fileName = $buildInfo.FileName
			$tempFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $fileName

			if ($PSCmdlet.ShouldProcess($fileUri, "Download Paper build")) {

				Write-Verbose "Downloading $fileName to $tempFile..."
				Invoke-WebRequest -Uri $fileUri -OutFile $tempFile

			}

		} else {

			$fileName = Split-Path -Path $PaperDownloadUri -Leaf
			$tempFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $fileName

			if ($PSCmdlet.ShouldProcess($PaperDownloadUri, "Download Paper build")) {

				Write-Verbose "Downloading $fileName to $tempFile..."
				Invoke-WebRequest -Uri $PaperDownloadUri -OutFile $tempFile

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
			Write-Verbose "Removing git repository..."
			Remove-Item -Path (Join-Path -Path $ServerPath -ChildPath '.git') -Recurse -Force

			New-Variable -Name SCRIPT_NAME -Value "start.ps1" -Option Constant
			Write-Verbose "Preparing startup script $SCRIPT_NAME..."

			New-Variable -Name TEMPLATE_VALUE -Value '{{paper.jar}}' -Option Constant
			Write-Verbose "Rename startup template file start-template.ps1..."
			$scriptPath = Join-Path -Path $ServerPath -ChildPath $SCRIPT_NAME
			Rename-Item -Path (Join-Path -Path $ServerPath -ChildPath start-template.ps1) -NewName $SCRIPT_NAME

			Write-Verbose "Updating $SCRIPT_NAME to execute $fileName..."
			(Get-Content -Path $scriptPath) -replace $TEMPLATE_VALUE, $fileName | Set-Content $scriptPath

		}

		if ($PSCmdlet.ShouldProcess($ServerPath, "Copy Paper build")) {

			$destination = Join-Path -Path $ServerPath -ChildPath $fileName
			Write-Verbose "Copying $fileName to $destination..."
			Copy-Item -Path $tempFile -Destination $destination

		}

	}

	end { }

}
