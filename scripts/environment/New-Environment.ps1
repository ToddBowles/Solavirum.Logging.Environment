function Get-CommonStackNamePrefix
{
    return "ELK"
}

function New-Environment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$environmentName,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsKey,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsSecret,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsRegion,
        [switch]$wait,
        [switch]$disableCleanupOnFailure
    )

    try
    {
        if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

        $scriptFileLocation = Split-Path $script:MyInvocation.MyCommand.Path
        write-verbose "Script is located at [$scriptFileLocation]."

        $repositoryRootDirectoryPath = $repositoryRoot.FullName
        $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

        . "$commonScriptsDirectoryPath\Functions-Aws.ps1"

        Ensure-AwsPowershellFunctionsAvailable

        Write-Verbose "Gathering environment setup dependencies into single zip archive for distribution to S3 for usage by CloudFormation."
        $directories = Get-ChildItem -Directory -Path $($repositoryRoot.FullName) |
            Where-Object { $_.Name -like "scripts" }

        $user = (& whoami).Replace("\", "_")
        $date = [DateTime]::Now.ToString("yyyyMMddHHmmss")

        $archive = "$scriptFileLocation\script-working\$environmentName\$user\$date\dependencies.zip"

        . "$commonScriptsDirectoryPath\Functions-Compression.ps1"

        $archive = 7Zip-ZipDirectories $directories $archive -SubdirectoriesToExclude @("script-working","test-working")
        $archive = 7Zip-ZipFiles "$($repositoryRoot.FullName)\script-root-indicator" $archive -Additive

        Write-Verbose "Uploading dependencies archive to S3 for usage by CloudFormation."
        $awsBucket = "[BUCKET TO PUT DEPENDENCIES]"

        $dependenciesArchiveS3Key = "$environmentName/$user/$date/dependencies.zip"

        . "$commonScriptsDirectoryPath\Functions-Aws-S3.ps1"

        $dependenciesArchiveS3Key = UploadFileToS3 -AwsKey $awsKey -AwsSecret $awsSecret -AwsBucket $awsBucket -AwsRegion $awsRegion -File $archive -S3FileKey $dependenciesArchiveS3Key
        $haveUploadedDependenciesToS3 = $true

        $parametersHash = @{
            "Stack"="$environmentName";
            "KeyName"="[KEY FILE IN AWS]";
            "VpcId"="[VPC ID]";
            "PrivateVpcSubnets"="[COMMA SEPARATED LIST OF PRIVATE SUBNETS]";
            "PublicVpcSubnets"="[COMMA SEPARATED LIST OF PUBLIC SUBNETS]";
            "HostedZoneName"="[SOMETHING.SOMETHING.COM]";
            "EBSVolumeSize"="0"; #0 indicates to use the space on instance storage, which is limited
            "ProxyUrlAndPort"="[PROXY USED/REQUIRED BY AWS MACHINES]";
            "DependenciesArchiveS3Url"="https://s3-ap-southeast-2.amazonaws.com/$awsBucket/$dependenciesArchiveS3Key";
            "S3AccessKey"="$awsKey";
            "S3SecretKey"="$awsSecret";
            "S3BucketName"="$awsBucket";
        }

        $stacksHash = @{}

        $resultHash = @{}
        $resultHash.Add("Stacks", $stacksHash)
        $resultHash.Add("LogstashEndpoint", $null)
        $resultHash.Add("KibanaUrl", $null)
        $resultHash.Add("GoogleOAuthRedirectUrl", $null)

        $result = new-object PSObject $resultHash

        $commonStackNamePrefix = Get-CommonStackNamePrefix

        $filePath = "$($repositoryRoot.FullName)\scripts\environment\ELK.cloudformation.template"
        $stackName = "$commonStackNamePrefix-$environmentName"
        $stackId = Create-Stack -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -TemplateFile $filePath -ParametersHash $parametersHash -DisableCleanupOnFailure:$disableCleanupOnFailure.IsPresent -StackName $stackName
        $stacksHash.Add($stackId, $null)

        if ($wait)
        {
            $result = Wait-Environment -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -NewEnvironmentResult $result

            $stackIds = ($result.Stacks.GetEnumerator() | Select -ExpandProperty Name )
            foreach ($stackId in $stackIds)
            {
                $stack = $result.Stacks[$stackId]
                if ($stack.StackStatus -ne [Amazon.CloudFormation.StackStatus]::CREATE_COMPLETE)
                {
                    write-verbose $stack
                    throw "Stack creation for [$stackId] failed. If DisableCleanupOnFailure is set, you will be able to check the Stack in the AWS Dashboard and investigate. If not, rerun with that switch set to stop the failure stack being torn down immediately."
                } 
            }

            . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"

            $stack = $result.Stacks[$stackId]
            $result.LogstashEndpoint = ($stack.Outputs | Single -Predicate { $_.OutputKey -eq "LogstashEndpoint" }).OutputValue
            $result.KibanaUrl = ($stack.Outputs | Single -Predicate { $_.OutputKey -eq "KibanaUrl" }).OutputValue
        }

        return $result
    }
    catch
    {
        if (!$disableCleanupOnFailure)
        {
            Write-Verbose "A failure occurred and DisableCleanupOnFailure flag was not set. Cleaning up."
            if ($haveUploadedDependenciesToS3)
            {
                RemoveFilesFromS3ByPrefix -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -AwsBucket $awsBucket -Prefix $environmentName -Force
            }
            if ($result -ne $null)
            {
                $stackIds = ($result.Stacks.GetEnumerator() | Select -ExpandProperty Name )
                foreach ($stackId in $stackIds)
                {
                    Write-Verbose "Deleting CFN Stack [$stackId]."
                    Remove-CFNStack -AccessKey $awsKey -SecretKey $awsSecret -Region $awsRegion -StackName $stackId -Force
                }
            }
        }

        throw $_
    }
}

function Create-Stack
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsKey,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsSecret,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsRegion,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$stackName,
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]$templateFile,
        [Parameter(Mandatory=$true)]
        [hashtable]$parametersHash,
        [switch]$disableCleanupOnFailure
    )
    if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $repositoryRootDirectoryPath = $repositoryRoot.FullName
    $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Aws-CloudFormation.ps1"

    $filePath = $templateFile.FullName
    $templateContent = Get-Content $filePath -Raw
    write-verbose "Creating CloudFormation stack using template at [$filePath]."
    $stackId = New-CFNStack -AccessKey $awsKey -SecretKey $awsSecret -Region $awsRegion -StackName $stackName -TemplateBody $templateContent -Parameters (Convert-HashTableToAWSCloudFormationParametersArray $parametersHash) -DisableRollback $disableCleanupOnFailure.IsPresent

    return $stackId
}

function Wait-Environment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsKey,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsSecret,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsRegion,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $newEnvironmentResult
    )

    if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $scriptFileLocation = Split-Path $script:MyInvocation.MyCommand.Path
    write-verbose "Script is located at [$scriptFileLocation]."

    $repositoryRootDirectoryPath = $repositoryRoot.FullName
    $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Aws-CloudFormation.ps1"

    $stackIds = ($newEnvironmentResult.Stacks.GetEnumerator() | Select -ExpandProperty Name )
    foreach ($stackId in $stackIds)
    {
        $stack = Wait-CloudFormationStack -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -StackId "$stackId"
        $newEnvironmentResult.Stacks.Set_Item($stackId, $stack)
    }
    
    return $newEnvironmentResult
}
