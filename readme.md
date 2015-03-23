A CloudFormation template to setup an ELK based Log Aggregator in AWS.

To execute, use the scripts/environment/Invoke-NewEnvironment.ps1 Powershell script with appropriate arguments.

Powershell -ExecutionPolicy RemoteSigned -File ./scripts/environment/Invoke-NewEnvironment.ps1 -EnvironmentName "[ENVIRONMENT NAME]" -AwsKey [YOUR KEY] -AwsSecret [YOUR SECRET]

That will create the stack in ap-southeast-2 by default, and wait for it to complete. If you want to create in another region, you'll have to lookup the appropriate AMI for that region.

If you want status messages output to the console while waiting, use the -Verbose flag. 

Also included is a script to configure Nxlog to upload IIS log files to a Logstash endpoint (scripts/environment/configure-nxlog.ps1).

Finally, this repository leverages Pester for testing Powershell scripts. To invoke all of the tests, use scripts/test/Invoke-PowershellTests.ps1.