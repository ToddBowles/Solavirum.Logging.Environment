[CmdletBinding()]
param
(
    [Parameter(Mandatory=$true)]
    [string]$logServerAddress
)

$currentDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path
write-verbose "Script is located at [$currentDirectoryPath]."

. "$currentDirectoryPath\_Find-RepositoryRoot.ps1"

$repositoryRoot = Find-RepositoryRoot $currentDirectoryPath

$repositoryRootPath = $repositoryRoot.FullName

$commonScriptsPath = "$repositoryRootPath\scripts\common"

. "$commonScriptsPath\Functions-NxLog.ps1"

Install-NxLog
Configure-NxLog -LogServerAddress $logServerAddress
Enable-NxLogService