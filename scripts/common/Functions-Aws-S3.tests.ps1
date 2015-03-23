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

Describe "Functions-Aws-S3" {
    BeforeEach {
        . "$($repositoryRoot.FullName)\scripts\common\Functions-Aws.ps1"
        Ensure-AwsPowershellFunctionsAvailable

        $workingDirectoryPath = Get-UniqueTestWorkingDirectory
    }

    Context "When valid credentials, file and S3 key supplied" {
        It "Correctly uploads the file to S3" {
            $file = New-Item "$workingDirectoryPath\test-file.txt" -ItemType File -Force

            $awsKey = ""
            $awsSecret = ""
            $awsRegion = ""
            $awsBucket = ""
            

        }
    }
}