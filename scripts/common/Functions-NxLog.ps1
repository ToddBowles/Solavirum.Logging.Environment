function Configure-NxLog
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$logServerAddress,
        [System.IO.DirectoryInfo]$DI_nxlogConfigurationDirectory
    )

    if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $repositoryRootPath = $repositoryRoot.FullName
    $commonScriptsDirectoryPath = "$repositoryRootPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-FileSystem.ps1"

    if ($DI_nxlogConfigurationDirectory -eq $null)
    {
        $DI_nxlogConfigurationDirectory = Ensure-DirectoryExists "C:\Program Files (x86)\nxlog\conf"
    }

    $currentDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path
    $baseConfig = "$currentDirectoryPath\configuration\nxlog.conf"
    $uniqueDirectoryName = [Guid]::NewGuid().ToString("N")
    $temporaryDirectory = "$currentDirectoryPath\configuration\script-working\$uniqueDirectoryName"
    $tempConfigFile = "$currentDirectoryPath\configuration\script-working\$uniqueDirectoryName\nxlog.conf"
    New-Item -Path $tempConfigFile -Force -Type "File"

    Get-Content $baseConfig | 
        ForEach-Object { $_ -replace "@@LOG_SERVER_ADDRESS", $logServerAddress } |
        Set-Content $tempConfigFile

    $configurationFileDestination = "$($DI_nxlogConfigurationDirectory.FullName)\nxlog.conf"

    New-Item -Path $configurationFileDestination -Force -Type "File"
    Copy-Item $tempConfigFile $configurationFileDestination -Force
    Remove-Item -Path $temporaryDirectory -Force -Recurse
}

function Enable-NxLogService
{
    Start-Service nxlog
}

function Install-NxLog
{
    if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $repositoryRootPath = $repositoryRoot.FullName

    $commonScriptsPath = "$repositoryRootPath\scripts\common"

    . "$commonScriptsPath\Functions-Enumerables.ps1"

    $nxlogInstallerFile = Get-ChildItem -Path "$repositoryRootPath\tools\nxlog" | Single

    $arguments = @()
    $arguments += "/i"
    $arguments += "$($nxlogInstallerFile.FullName)"
    $arguments += "/qn"

    $result = Start-Process -FilePath msiexec -ArgumentList ([String]::Join(" ", $arguments)) -Wait -Passthru
    $exitCode = $result.ExitCode
    if ($exitCode -ne 0)
    {
        throw "Failed to install from [$($nxlogInstallerFile.FullName). Exit code [$exitCode]."
    }
}