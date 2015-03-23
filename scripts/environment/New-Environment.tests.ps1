$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -ireplace "tests.", ""
. "$here\$sut"

. "$currentDirectoryPath\_Find-RepositoryRoot.ps1"
$repositoryRoot = Find-RepositoryRoot $here

Describe "New-Environment" {
    Context "When executed with appropriate parameters" {
        It "Returns appropriate outputs, including stack identifiers and URLs for exposed services" {
            $currentUtcDateTime = [DateTime]::UtcNow

            $a = $currentUtcDateTime.ToString("yy") + $currentUtcDateTime.DayOfYear.ToString("000")
            $b = ([int](([int]$currentUtcDateTime.Subtract($currentUtcDateTime.Date).TotalSeconds) / 2)).ToString("00000")
            $uniqueId = "$a-$b"

            $awsKey = "[KEY HERE]"
            $awsSecret = "[SECRET HERE]"

            $environmentCreationResult = New-Environment -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion "ap-southeast-2" -EnvironmentName "Test-$uniqueId" -Wait -DisableCleanupOnFailure

            Write-Verbose (ConvertTo-Json $environmentCreationResult)

            $environmentCreationResult.LogstashEndpoint | Should Not BeNullOrEmpty
            $environmentCreationResult.KibanaUrl | Should Not BeNullOrEmpty
        }
    }
}