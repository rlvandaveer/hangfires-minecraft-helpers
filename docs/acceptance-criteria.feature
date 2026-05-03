Feature: Get latest Paper build information
  As a Minecraft server administrator
  I want to query Paper build information by Minecraft version
  So that I can inspect available builds before updating servers

  Scenario: Auto-detect latest stable version when no version is specified
    Given the Fill API is accessible
    When I call Get-LatestPaperBuild with no parameters
    Then it returns build info for the latest Paper version that has at least one stable build
    And the returned object has Version, BuildNumber, FileName, and DownloadUrl properties

  Scenario: Get latest stable build for a specific version
    Given the Fill API is accessible
    And version '26.1.2' has at least one stable build
    When I call Get-LatestPaperBuild -MinecraftVersion '26.1.2'
    Then it returns build info for the highest-numbered stable build of version '26.1.2'

  Scenario: Requested version has only unstable builds and AllowUnstable is not set
    Given the Fill API is accessible
    And version 'X.Y.Z' exists but has no stable builds
    When I call Get-LatestPaperBuild -MinecraftVersion 'X.Y.Z'
    Then it throws a terminating error indicating no stable builds are available for that version

  Scenario: Requested version has only unstable builds and AllowUnstable is set
    Given the Fill API is accessible
    And version 'X.Y.Z' exists but has no stable builds
    When I call Get-LatestPaperBuild -MinecraftVersion 'X.Y.Z' -AllowUnstable
    Then it returns build info for the highest-numbered build regardless of channel
    And it writes a warning indicating the build is not stable

  Scenario: Auto-detect latest version with AllowUnstable when newest version has no stable builds
    Given the Fill API is accessible
    And the newest Paper version has only unstable builds
    When I call Get-LatestPaperBuild -AllowUnstable
    Then it returns build info for the highest-numbered build of the newest Paper version

  Scenario: Requested version does not exist
    Given the Fill API is accessible
    And version '99.99.99' does not exist in the Fill API
    When I call Get-LatestPaperBuild -MinecraftVersion '99.99.99'
    Then it throws a terminating error indicating the version was not found

  Scenario: Fill API is unreachable
    Given the Fill API is not accessible
    When I call Get-LatestPaperBuild
    Then it throws a terminating error indicating the API could not be reached


Feature: Update Paper server JAR files
  As a Minecraft server administrator
  I want to update the Paper JAR in one or more server directories
  So that servers run the latest compatible Paper build

  Scenario: Update using auto-detected latest stable version
    Given one or more valid server directories exist
    And the Fill API is accessible
    And no MinecraftVersion is specified
    When I call Update-PaperVersion -ServerPath <paths>
    Then it downloads the latest stable build for the latest stable Paper version
    And it copies the JAR to each server directory
    And it calls Update-StartScript with the new JAR filename for each server directory

  Scenario: Update using a specified version with stable builds
    Given one or more valid server directories exist
    And the Fill API is accessible
    And version '26.1.2' has stable builds
    When I call Update-PaperVersion -MinecraftVersion '26.1.2' -ServerPath <paths>
    Then it downloads the latest stable build for version '26.1.2'
    And it copies the JAR to each server directory
    And it calls Update-StartScript with the new JAR filename for each server directory

  Scenario: Update using a version that has only unstable builds without AllowUnstable
    Given one or more valid server directories exist
    And version 'X.Y.Z' has only unstable builds
    When I call Update-PaperVersion -MinecraftVersion 'X.Y.Z' -ServerPath <paths>
    Then it throws a terminating error before downloading anything

  Scenario: Update using a version that has only unstable builds with AllowUnstable
    Given one or more valid server directories exist
    And version 'X.Y.Z' has only unstable builds
    When I call Update-PaperVersion -MinecraftVersion 'X.Y.Z' -AllowUnstable -ServerPath <paths>
    Then it downloads the latest build for version 'X.Y.Z' regardless of channel
    And it copies the JAR to each server directory
    And it calls Update-StartScript with the new JAR filename for each server directory

  Scenario: Update using a direct download URI override
    Given one or more valid server directories exist
    When I call Update-PaperVersion -PaperDownloadUri <uri> -ServerPath <paths>
    Then it downloads the JAR from the provided URI without calling the Fill API
    And it copies the JAR to each server directory

  Scenario: Update with WhatIf
    Given one or more valid server directories exist
    When I call Update-PaperVersion -WhatIf -ServerPath <paths>
    Then it writes WhatIf messages describing each action
    And it does not download, copy, or modify any files


Feature: Update server start script
  As a Minecraft server administrator
  I want the start script updated to reference the new Paper JAR
  So that the server launches with the correct version after an update

  Scenario: Update start script with explicit version and build
    Given a valid server directory exists
    And it contains a start.ps1 referencing a previous Paper JAR filename
    When Update-StartScript is called with MinecraftVersion, PreviousPaperJar, NewPaperBuild, and ServerPath
    Then it replaces the previous JAR filename with the new one in start.ps1

  Scenario: MinecraftVersion is not provided
    When Update-StartScript is called without MinecraftVersion
    Then PowerShell raises a missing mandatory parameter error before execution begins

  Scenario: Update with WhatIf
    Given a valid server directory exists
    When I call Update-StartScript -WhatIf with all required parameters
    Then it writes a WhatIf message describing the change
    And it does not modify start.ps1


Feature: Create a new Paper server
  As a Minecraft server administrator
  I want to create a new Paper server directory with default files
  So that I can stand up a server quickly

  Scenario: Create server using auto-detected latest stable version
    Given the target server path does not exist
    And the Fill API is accessible
    And no MinecraftVersion is specified
    When I call New-PaperServer -WorldName <name> -ServerPath <path>
    Then it creates the directory at the server path
    And it downloads the latest stable build for the latest stable Paper version
    And it clones the base server files and prepares the start script with the JAR filename

  Scenario: Create server using a specified version with stable builds
    Given the target server path does not exist
    And version '26.1.2' has stable builds
    When I call New-PaperServer -MinecraftVersion '26.1.2' -WorldName <name> -ServerPath <path>
    Then it downloads the latest stable build for version '26.1.2'
    And it clones the base server files and prepares the start script with the JAR filename

  Scenario: Create server using a version that has only unstable builds without AllowUnstable
    Given the target server path does not exist
    And version 'X.Y.Z' has only unstable builds
    When I call New-PaperServer -MinecraftVersion 'X.Y.Z' -WorldName <name> -ServerPath <path>
    Then it throws a terminating error before creating the directory or downloading anything

  Scenario: Create server using a version that has only unstable builds with AllowUnstable
    Given the target server path does not exist
    And version 'X.Y.Z' has only unstable builds
    When I call New-PaperServer -MinecraftVersion 'X.Y.Z' -AllowUnstable -WorldName <name> -ServerPath <path>
    Then it downloads the latest build for version 'X.Y.Z' regardless of channel
    And it clones the base server files and prepares the start script with the JAR filename

  Scenario: Create server with WhatIf
    Given the target server path does not exist
    When I call New-PaperServer -WhatIf -WorldName <name> -ServerPath <path>
    Then it writes WhatIf messages describing each action
    And it does not create any directories, download files, or clone the base server
