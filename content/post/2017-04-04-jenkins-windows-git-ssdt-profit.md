+++
title=  "Automating SSDT build and deployment with Jenkins from a local git repo"
date =  "2017-04-04"
tags = ["Jenkins", "SSDT", "PowerShell"]

draft = false
+++

This is a short illustration of using a local installation of Jenkins on Windows to build an SSDT project from a local git repo and deploy it to a SQL Server on the same machine.

This is probably useful for a quick demonstration or to understand how the various moving parts fit together, but possibly less applicable to "Real Life" production environments.

There are no build agents and no git remotes; all the action takes place on the Jenkins master, and the git repo is local to the same machine. No "git management" software such as GitHub/VSTS/GitLab/BitBucket/etc is involved (except for some slight cheating regarding the build definition itself.)

## Getting set up

I am using Windows 10 with SQL Server 2016 Developer Edition and Visual Studio 2015 Professional. Most of this stuff should work with most editions and versions of SQL Server and Visual Studio, but some of the paths will vary here and there. I am using SQL Server Data Tools Version 14.0.61021.0, released on October 26, 2016.

### Installing Jenkins
I used the windows installer linked [here](https://jenkins.io/content/thank-you-downloading-windows-installer/#stable) (note that this link will trigger the download _immediately_). At the time of writing this is version 2.46.1. In the initial setup, I selected the option to "Install Recommended Plugins"; this installs more than is required for this example. 



### Further Jenkins twiddling
The MSBuild plugin needs to be installed separately (as it isn't "_recommended_"!), which can be done from http://localhost:8080/pluginManager/available or by clicking through _Jenkins -> Manage Jenkins -> Manage Plugins -> Available_. We need to tell Jenkins where it can find `MSBuild.exe`, this is done on http://localhost:8080/configureTools/ (_Jenkins -> Manage Jenkins -> Global Tool Configuration_). You can find out where `MSBuild` is installled by opening the "Developer Command Prompt for Visual Studio" and typing

```bat

C:\Program Files (x86)\Microsoft Visual Studio 14.0>where msbuild
C:\Program Files (x86)\MSBuild\14.0\Bin\MSBuild.exe
C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe

```
I used the first of these, as this is the one installed by Visual Studio[^1] 2015, and should avoid having to re-read the somewhat convoluted StackOverflow thread [here](http://stackoverflow.com/questions/22968561/msbuild-errors-for-database-project-on-tfs-server-with-vs-2013-shell).

I already had git installed and in the path, so there was no need to configure this separately in Jenkins.

``` bash
$ git --version
git version 2.11.0.windows.3

```

### Compromising your SQL Server [^2]

By default, the Jenkins service will run as "Local System" on Windows. In order to allow this account - which will authenticate to SQL Server as the machine account - to deploy the database, I made "Local System" an `sa` of the SQL Server:

```sql

EXEC sp_addsrvrolemember 'NT AUTHORITY\SYSTEM', 'sysadmin';
```
There are many circumstances in which this wouldn't be a good idea, if any of them apply in your scenario you should make appropriate adjustments to the scripts that follow.

### Find something to build
I started by cloning a repo I had prepared earlier, containing a copy of the Chinook database.

```bat

C:\Projects>git clone https://github.com/arapaima-uk/Chinook.JenkinsDemo.git
Cloning into 'Chinook.JenkinsDemo'...
remote: Counting objects: 26, done.
remote: Compressing objects: 100% (20/20), done.
remote: Total 26 (delta 5), reused 26 (delta 5), pack-reused 0
Unpacking objects: 100% (26/26), done.

C:\Projects>tree
Folder PATH listing
Volume serial number is 000000B7 806E:E890
C:.
└───Chinook.JenkinsDemo
    └───Chinook.JenkinsDemo
        └───dbo
            └───Tables

C:\Projects>
```

having done that, I then removed the reference to the GitHub remote with 
```bat
C:\Projects\Chinook.JenkinsDemo>git remote rm origin
```
From here on, everything is local (_geddit?_).

## Creating the Jenkins job

The first step is to create the Jenkins job that will build our project into a dacpac, and deploy it to a local SQL Server.

The job definition is contained in the following Jenkinsfile, which consists of three fairly self-explanatory stages. The first stage `git checkout` checks out our master branch from the local (indicated by the `file:\\` prefix) repo. The second stage calls the `MSBuild` tool we defined earlier, taking advantage of the fact that our project is very simple to provide very few parameters on the command line. The third calls out to the shell to call `sqlpackage.exe`, again with very few parameters. This last stage is the one that requires whatever account Jenkins is running under to be able to authenticate to the SQL Server (though there are alternatives involving storing credentials in Jenkins).

{{<gist gavincampbell e3dfa25abf427752e919eb2110f03852>}}

Conveniently, since this is stored in a GitHub gist, and a gist is a git repo, I can create a new pipeline job and specify "Pipeline Script from SCM" in the build definition then provide the url of the gist for the repository url. 

Note that this repo contains a single file, namely the build definition - all the project files are coming from the git repo on our local machine. If you want to copy and paste the complete url, it's in the build output log reproduced below.

![Screenshot of Jenkins showing pipeline from SCM](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/jenkins-ssdt-git/pipeline-job-from-gist.PNG)

One more detail is that the job needs to be set to "Poll SCM", but the schedule can be left empty (ignore the warning). This isn't required to test the build, but will be required later on to trigger the build on a commit to our git repo.

![Jenkins Pipeline Job showing Poll SCM Setting with empty schedule](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/jenkins-ssdt-git/jenkins-job-set-to-poll-with-empty-schedule.PNG)

### Testing the build

We should now be able to trigger the build from the Jenkins dashboard, and see some output like the following (under "Console Output")

```
Started by user arapaima
Obtained Jenkinsfile from git https://gist.github.com/gavincampbell/e3dfa25abf427752e919eb2110f03852
[Pipeline] node
Running on master in C:\Program Files (x86)\Jenkins\workspace\BuildDeploySsdtFromLocalRepo
[Pipeline] {
[Pipeline] stage
[Pipeline] { (git checkout)
[Pipeline] git
 > git.exe rev-parse --is-inside-work-tree # timeout=10
Fetching changes from the remote Git repository
 > git.exe config remote.origin.url file:///C:/Projects/Chinook.JenkinsDemo # timeout=10
Fetching upstream changes from file:///C:/Projects/Chinook.JenkinsDemo
 > git.exe --version # timeout=10
 > git.exe fetch --tags --progress file:///C:/Projects/Chinook.JenkinsDemo +refs/heads/*:refs/remotes/origin/*
 > git.exe rev-parse "refs/remotes/origin/master^{commit}" # timeout=10
 > git.exe rev-parse "refs/remotes/origin/origin/master^{commit}" # timeout=10
Checking out Revision 8ccbac95d2edd4ce0cbf14ec9f5f3f7ac2868eac (refs/remotes/origin/master)
 > git.exe config core.sparsecheckout # timeout=10
 > git.exe checkout -f 8ccbac95d2edd4ce0cbf14ec9f5f3f7ac2868eac
 > git.exe branch -a -v --no-abbrev # timeout=10
 > git.exe branch -D master # timeout=10
 > git.exe checkout -b master 8ccbac95d2edd4ce0cbf14ec9f5f3f7ac2868eac
 > git.exe rev-list 8ccbac95d2edd4ce0cbf14ec9f5f3f7ac2868eac # timeout=10
[Pipeline] }
[Pipeline] // stage
[Pipeline] stage
[Pipeline] { (Build Dacpac from SQLProj)
[Pipeline] tool
[Pipeline] bat
[BuildDeploySsdtFromLocalRepo] Running batch script

C:\Program Files (x86)\Jenkins\workspace\BuildDeploySsdtFromLocalRepo>"C:\Program Files (x86)\MSBuild\14.0\Bin\MSBuild.exe"  /p:Configuration=Release 
Microsoft (R) Build Engine version 14.0.25420.1
Copyright (C) Microsoft Corporation. All rights reserved.

Building the projects in this solution one at a time. To enable parallel build, please add the "/m" switch.
Build started 05/04/2017 00:55:50.
Project "C:\Program Files (x86)\Jenkins\workspace\BuildDeploySsdtFromLocalRepo\Chinook.JenkinsDemo.sln" on node 1 (default targets).
ValidateSolutionConfiguration:
  Building solution configuration "Release|Any CPU".
Project "C:\Program Files (x86)\Jenkins\workspace\BuildDeploySsdtFromLocalRepo\Chinook.JenkinsDemo.sln" (1) is building "C:\Program Files (x86)\Jenkins\workspace\BuildDeploySsdtFromLocalRepo\Chinook.JenkinsDemo\Chinook.JenkinsDemo.sqlproj" (2) on node 1 (default targets).
GenerateSqlTargetFrameworkMoniker:
Skipping target "GenerateSqlTargetFrameworkMoniker" because all output files are up-to-date with respect to the input files.
CoreCompile:
Skipping target "CoreCompile" because all output files are up-to-date with respect to the input files.
SqlBuild:
Skipping target "SqlBuild" because all output files are up-to-date with respect to the input files.
CopyFilesToOutputDirectory:
  Chinook.JenkinsDemo -> C:\Program Files (x86)\Jenkins\workspace\BuildDeploySsdtFromLocalRepo\Chinook.JenkinsDemo\bin\Release\Chinook.JenkinsDemo.dll
SqlPrepareForRun:
  Chinook.JenkinsDemo -> C:\Program Files (x86)\Jenkins\workspace\BuildDeploySsdtFromLocalRepo\Chinook.JenkinsDemo\bin\Release\Chinook.JenkinsDemo.dacpac
Done Building Project "C:\Program Files (x86)\Jenkins\workspace\BuildDeploySsdtFromLocalRepo\Chinook.JenkinsDemo\Chinook.JenkinsDemo.sqlproj" (default targets).
Done Building Project "C:\Program Files (x86)\Jenkins\workspace\BuildDeploySsdtFromLocalRepo\Chinook.JenkinsDemo.sln" (default targets).

Build succeeded.
    0 Warning(s)
    0 Error(s)

Time Elapsed 00:00:00.53
[Pipeline] stash
Stashed 1 file(s)
[Pipeline] }
[Pipeline] // stage
[Pipeline] stage
[Pipeline] { (Deploy Dacpac to SQL Server)
[Pipeline] unstash
[Pipeline] bat
[BuildDeploySsdtFromLocalRepo] Running batch script

C:\Program Files (x86)\Jenkins\workspace\BuildDeploySsdtFromLocalRepo>"C:\Program Files (x86)\Microsoft SQL Server\130\DAC\bin\sqlpackage.exe" /Action:Publish /SourceFile:"Chinook.JenkinsDemo\bin\Release\Chinook.JenkinsDemo.dacpac" /TargetServerName:(local) /TargetDatabaseName:Chinook 
Publishing to database 'Chinook' on server '(local)'.
Initializing deployment (Start)
Initializing deployment (Complete)
Analyzing deployment plan (Start)
Analyzing deployment plan (Complete)
Updating database (Start)
Update complete.
Updating database (Complete)
Successfully published database.
[Pipeline] }
[Pipeline] // stage
[Pipeline] }
[Pipeline] // node
[Pipeline] End of Pipeline
Finished: SUCCESS

```

The "stage view" of the build should be showing green:

![passing builds in Jenkins](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/jenkins-ssdt-git/passing-stage-view.PNG "Earlier builds omitted for clarity, naturally!")

## Triggering the build from the git repo

Many approaches to building a project automatically on each commit rely on the CI server, in this case Jenkins, polling the source control system at some pre-defined interval. 

However, if the geo-political events of 2016 are any guide, polling doesn't always lead to the outcome we expect, so in this case we'll create a git "hook" to trigger the build on every commit to master.

A [git hook](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks "Link to git hooks chapter of git book") is a script that runs in response to a specific event that occurs in git. There are a bunch of events that can fire hooks, these can be used to enforce commit message conventions, run static code analysis, prevent force-pushes, and all kinds of other arbitrary busywork. The event that's of interest here is the `post-commit` hook, which runs _after_ a commit has been added. In "Real Life", hooks are normally added to the _server_ copy of the repo but since there's no remote in our setup, everything has to be local. 

Notably, even though we're on Windows in this example, hooks are executed by the `msysgit` subsystem so much of the usual UNIX shell stuff will work.

Hooks are stored in the `.git` folder in our repo (this is usually hidden on Windows) in files that match the name of the hook. So, our file is called `post-commit` (no extension) and contains the `#!/bin/sh` "shebang" plus a single line that uses `curl` to hit a specific URL in the Jenkins server that will cause our Jenkins job to poll its source repo as defined in the build pipeline (i.e. `file:///C:/Projects/Chinook.JenkinsDemo` )

``` bat
C:\Projects\Chinook.JenkinsDemo\.git\hooks>type post-commit
#!/bin/sh
curl http://localhost:8080/git/notifyCommit?url=file:///C:/Projects/Chinook.JenkinsDemo
```
> Note for `git` beginners: this file isn't in the repo when you download it, you'll need to add it yourself!

Now, all that remains is to make an arbitrary change to our project and add a commit.

![Visual Studio showing changed table and commit dialog](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/jenkins-ssdt-git/changed-table-with-commit-dialog.PNG)

If everything is working the pipeline job should be triggered, and the new build will also log that it was "Started by an SCM Change". 

![Build Triggered by SCM Change](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/jenkins-ssdt-git/build-started-by-scm-change.PNG)

To clarify what's happened here, we made a change and committed it to our local repo, the `post-commit` hook called the url in Jenkins, and Jenkins then "polled" the git repo, found a new commit, and triggered the pipeline job.

Until next time, happy triggering!

> If you commit the change from the `git` command line, you may see output along the lines of:
```
$ git commit -am "add shoesize to artist table"
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   135  100   135    0     0   9000      0 --:--:-- --:--:-- --:--:--  9000Scheduled polling of BuildDeploySsdtFromLocalRepo
No Git consumers using SCM API plugin for: file:///C:/Projects/Chinook.JenkinsDemo

```
> The "error" message is nothing to worry about, as long as the line "Scheduled Polling of _myJobName_ is present then everything is hunky-dory!

[^1]: [MSBuild is now part of Visual Studio!](https://blogs.msdn.microsoft.com/visualstudio/2013/07/24/msbuild-is-now-part-of-visual-studio/)

[^2]: [Testing connection to SQL Server from a service running under Local System Account](https://blogs.msdn.microsoft.com/dataaccesstechnologies/2010/01/29/testing-connection-to-sql-server-from-a-service-running-under-local-system-account/)