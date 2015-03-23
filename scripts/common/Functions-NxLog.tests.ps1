$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -ireplace "tests.", ""
. "$here\$sut"

. "$currentDirectoryPath\_Find-RepositoryRoot.ps1"
$repositoryRoot = Find-RepositoryRoot $here

function Get-UniqueTestWorkingDirectory
{
    $tempDirectoryName = [System.Guid]::NewGuid().ToString()
    return "$here\test-working\$tempDirectoryName"
}

Describe "Configure-NxLog" {
    BeforeEach {
        $workingDirectoryPath = Get-UniqueTestWorkingDirectory
    }

    Context "When supplied with a valid environment name" {
        It "Replaces environment name inside configuration file and copies it to the appropriate destination directory" {
            $logServerAddress = [Guid]::NewGuid().ToString("N")

            Configure-NxLog -LogServerAddress $logServerAddress -DI_nxlogConfigurationDirectory $workingDirectoryPath

            $file = "$workingDirectoryPath\nxlog.conf"

            $file | Should Exist
            $file | Should Contain $logServerAddress
            $file | Should Not Contain "@@"
        }
    }

    Context "When nxlog configuration file already exists in installation directory" {
        It "Replaces existing file with new file" {
            $oldFileContent = [Guid]::NewGuid().ToString("N")
            $logServerAddress = [Guid]::NewGuid().ToString("N")
            $outputConfigurationFilePath = "$workingDirectoryPath\nxlog.conf"
            New-Item -Path $outputConfigurationFilePath -Type "File" -Value $oldFileContent -Force

            Configure-NxLog -LogServerAddress $logServerAddress -DI_nxlogConfigurationDirectory $workingDirectoryPath

            $outputConfigurationFilePath | Should Exist
            $outputConfigurationFilePath | Should Contain $logServerAddress
            $outputConfigurationFilePath | Should Not Contain $oldFileContent
        }
    }
}