+++
title=  'Expose VSTS secrets as environment variables with this one weird trick...'
date =  "2017-10-23"
tags = ["VSTS"]
draft = false
+++

## Config as environment variables

I'm a big fan of the [Twelve-Factor App](https://12factor.net/) "methodology"[^1] for building and deploying applications, and whilst much of it is geared towards web apps in Heroku-esque environments, I think the principles - or "factors" - are well worth bearing in mind when considering the delivery of other types of application.

[Factor 3 of the 12](https://12factor.net/config) reads as follows

>An app’s config is everything that is likely to vary between deploys (staging, production, developer environments, etc). This includes:
>
>    * Resource handles to the database, Memcached, and other backing services
>    * Credentials to external services such as Amazon S3 or Twitter
>    * Per-deploy values such as the canonical hostname for the deploy

There are a number of benefits to this approach, the main ones I can think of are:

* The obvious one about not having credentials stored in source control. Nobody does this anymore, right?
* If environment specific information such as server names are stored with the source control, then changes in the infrastructure will result in new commits in the source repo, meaning that the commit history will no longer merely "tell the story" of the application, but will also contain numerous sub-plots regarding the infrastructure.

### The downside
There is some debate over whether environment variables are really the best place for secret information, and there are definitely customers for whom this approach would be considered too high risk. However, I wouldn't have thought these included the customers where the credentials are currently stored with the application source code!

The main alternatives generally revolve around storing credentials somewhere where the infrastructure automation tools - Ansible, etc. - can see them and using these tools to deploy a file which the applications can read.  

## Never mind the downside, on with the weird trick...

I used the following example of the "config as environment variables" approach in a recent talk about SSDT and VSTS, using a Powershell Script to read config values from environment variables and deploy a dacpac to a SQL Azure database using SQL Authentication.

``` Powershell
$serverName=$env:Chinook_ServerName
$dbName = $env:Chinook_DatabaseName
$dbUser = $env:Chinook_DbUser
$dbPassword = $env:Chinook_DbPassword

$dacFxDll='C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin\Microsoft.SqlServer.Dac.dll'

Add-Type -Path $dacFxDll
$dacServices = New-Object Microsoft.SqlServer.Dac.DacServices "server=$serverName;User ID=$dbUser;Password=$dbPassword;"

$dacpacPath=Join-Path -Path $PSScriptRoot -ChildPath "\bin\Debug\ChinookDb.dacpac"
$publishProfilePath = Join-Path -Path $PSScriptRoot -ChildPath "CommonSettings.publish.xml"

$dacpac = [Microsoft.SqlServer.Dac.DacPackage]::Load($dacpacPath)
$dacProfile = [Microsoft.SqlServer.Dac.DacProfile]::Load($publishProfilePath)

$dacServices.Deploy($dacpac, $dbName, $true, $dacProfile.DeployOptions )

```

What this script does, in brief, is load the server name, database name, and credentials from environment variables, and then deploy a `.dacpac` using this information in addition to a publish profile(`CommonSettings.publish.xml`) that defines some common - to _all_ environments - deployment configuration.

The main advantage of this approach is that the _same_ deployment script can be used without modification in _all_ environments, from the developer's desktop through the various testing environments and on to UAT and Production.

So, for deployments from the desktop or other unmanaged environments, it is easy to specify these values by setting environment variables.

However, in VSTS, things are a little more complicated. It's possible to use [private agent queues](https://docs.microsoft.com/en-us/vsts/build-release/concepts/agents/pools-queues#creating-agent-pools-and-queues) to allocate specific build agents - which could have these variables set in advance -  to specific environments, but what if we just want to use the [hosted queue](https://docs.microsoft.com/en-us/vsts/build-release/concepts/agents/hosted#use-a-hosted-agent)?

[VSTS Release Management](https://docs.microsoft.com/en-us/vsts/build-release/concepts/releases/) allows us to specify variables for each environment in our [Release Definition](https://docs.microsoft.com/en-us/vsts/build-release/concepts/definitions/release/). It's fairly common to see these used as parameters to deployment tasks, but what is possibly less obvious from this interface is that these values are surfaced as _environment variables_ in the build process. 

![Variables pane in VSTS Release Management](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-secret-vars/variablesinreleasedefinition.png)

This means that our Powershell script above can still work unmodified - except, that is, for the password. This is masked in the screenshot  as it is defined as a "secret" variable. Secret variables are [not exposed as environment variables](https://docs.microsoft.com/en-us/vsts/build-release/concepts/definitions/build/variables?tabs=batch#secret-variables), but can only be passed as arguments to our build steps. What muddies the water slightly is that within living memory [secret variables _were_ exposed as environment variables](https://github.com/Microsoft/vsts-agent/issues/145), but this behaviour was "fixed" some time in 2016.

### Finally, the weird trick

In the above example, there is an empty environment variable `Chinook_DbPassword` for each environment, and a corresponding _secret_ variable that contains the actual password.

We need to add an additional task to our release definition to read the secret variable and surface it as an environment variable. This can be done through the [VSTS logging commands](https://github.com/Microsoft/vsts-tasks/blob/master/docs/authoring/commands.md)[^2], which are worth checking out as they enable a number of "weird tricks" in addition to this particular one.

As per the documentation, Logging Commands are invoked by writing the command to standard output, which in the case of PowerShell is done via `Write-Host`.

![Release Definition showing PowerShell step to decrypt secret variable](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-secret-vars/PowerShellStepToReadSecretVariable.png)

In accordance with the "rules", we pass the secret variable as an argument to the script, then use the `##vso[task.setvariable]` command to set the value of the non-secret environment variable to the value of the argument.

In the logs for the release, we can see the non-secret variables being set, with `Chinook_dbPassword` set to blank (`[]`).

```
2017-10-13T12:00:12.1607197Z Environment variables available are below.  
...
...
    [AGENT_HOMEDIRECTORY] --> [C:\LR\mms\Services\Mms\Provisioner\TaskAgent\agents\2.123.0]
...    
...
    [CHINOOK_DATABASENAME] --> [Chinook]
    [CHINOOK_DBPASSWORD] --> []
    [CHINOOK_DBUSER] --> [arapaima]
    [CHINOOK_SERVERNAME] --> [vstsdemochinook.database.windows.net]
...
...
```

When we get to the logs for the "Read Env Var" step:
```
2017-10-13T12:00:14.5784670Z ##[section]Starting: Read Env Var
2017-10-13T12:00:14.5954676Z ==============================================================================
2017-10-13T12:00:14.5954676Z Task         : PowerShell
2017-10-13T12:00:14.5954676Z Description  : Run a PowerShell script
2017-10-13T12:00:14.5954676Z Version      : 1.2.3
2017-10-13T12:00:14.5954676Z Author       : Microsoft Corporation
2017-10-13T12:00:14.5954676Z Help         : [More Information]
2017-10-13T12:00:14.5954676Z ==============================================================================
2017-10-13T12:00:14.6704451Z ##[command]. 'd:\a\_temp\2fa5955a-1363-464a-bed7-aed0cbea2c96.ps1' ********
2017-10-13T12:00:15.5054467Z ##[section]Finishing: Read Env Var
```
we can see that the secret variable is passed as a parameter to the inline script, but masked with asterisks in the release logs.

The "Deploy Dacpac" step contains a single action, namely running the same Powershell script as was used in every other environment:

```
2017-10-13T12:01:30.0026563Z ##[section]Starting: Deploy Dacpac
2017-10-13T12:01:30.0036563Z ==============================================================================
2017-10-13T12:01:30.0036563Z Task         : PowerShell
2017-10-13T12:01:30.0036563Z Description  : Run a PowerShell script
2017-10-13T12:01:30.0036563Z Version      : 1.2.3
2017-10-13T12:01:30.0036563Z Author       : Microsoft Corporation
2017-10-13T12:01:30.0036563Z Help         : [More Information]
2017-10-13T12:01:30.0036563Z ==============================================================================
2017-10-13T12:01:30.0076572Z ##[command]. 'd:\a\r1\a\ChinookDb-CI\BuildOutput\Deploy.ps1' 
2017-10-13T12:02:10.3410313Z ##[section]Finishing: Deploy Dacpac
```

This isn't restricted to Release Definitions, the same technique will work in Build Definitions too. This is possibly a less common scenario - as _builds_ shouldn't normally contain environment-specific information - except in cases like database deployment where it's generally necessary to deploy the database [_somewhere_](https://stackoverflow.com/questions/39443317/can-you-run-sql-unit-tests-tsqlt-during-build-process-in-vsts) before we can do any automated testing.








[^1]: Their words, not mine!
[^2]: I can't find this page on docs.microsoft.com, so the link is to the [Github source](https://github.com/Microsoft/vsts-tasks/blob/master/docs/authoring/commands.md).