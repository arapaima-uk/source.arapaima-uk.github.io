+++
title=  'Building an SSDT project with YAML build in VSTS'
date =  "2018-03-17"
tags = ["VSTS","SSDT"]
draft = false
+++

It may have been a while coming, at least compared to [Jenkins Pipeline](https://jenkins.io/solutions/pipeline/), [Travis-CI](https://travis-ci.org/), and friends, but VSTS now offers the facility to specify your build pipeline as YAML, meaning it can be version controlled with your application code. YAML Release Management Pipelines are "on the way", but not yet publically available.

{{< tweet 971796151862222848 >}}

YAML Build Definitions are currently in public preview, so you'll need to ensure you have the [feature enabled for your account](https://docs.microsoft.com/en-us/vsts/collaborate/preview-features).[^1]

## The Sample Project

We don't even need to download anything to get going with this, we can just use the WideWorldImporters Sample Database, which is buried in the [SQL Server Samples repo on GitHub](https://github.com/Microsoft/sql-server-samples), as VSTS supports building GitHub hosted projects. If you're following along, you'll need to [create your own fork](https://help.github.com/articles/fork-a-repo/) of the official [Microsoft/sql-server-samples](https://github.com/Microsoft/sql-server-samples) repo, as we'll be adding the YAML build definition to the root of our repo (yes, you need to have a [Github Account](https://github.com/join) for this to work). According to the [docs](https://docs.microsoft.com/en-us/vsts/build-release/actions/build-yaml), the only sources currently supported for YAML Build Definitions are Git (hosted in VSTS) and GitHub, so if your code is hosted elsewhere you'll have to wait a while longer.

### Creating a dummy build definition

Just to make sure everything is working, it's not a bad idea to go ahead and create a trivial build definition now. By convention, this file is called `.vsts-ci.yml` and is placed at the root of the repo. You can create this directly from the GitHub UI with the "Create New File" button. [Mine](https://github.com/arapaima-uk/sql-server-samples/blob/fa28d3f8803991a20884722e23fe01be6f170ca4/.vsts-ci.yml) just has a single step, which is rather unimaginative:

``` yaml
steps:
- script: echo hello world
```

## Making sure VSTS can talk to GitHub

The easiest way to do this, in my view at least, is to create a [Personal Access Token](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/) we can use so that VSTS can authenticate to GitHub. The `public_repo` scope will be adequate for everything we need to do here. 

![Creating a personal access token](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/github-vsts-yaml/create-access-token-public-repo.png)

You will need to copy the value of the token from GitHub as soon as you create it, it won't be accessible again.

![Copying the access token](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/github-vsts-yaml/copy-personal-access-token.png)


## Creating the Project in VSTS

Having selected the "New Project" button, we have a couple of forms to fill in. The first is just to give our VSTS project a name, the rest of the fields can be left at their defaults.

![Creating a new project in VSTS](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/github-vsts-yaml/vst-new-project.png)

Next, we specify that we are building code from an external repo, and select "Setup Build".

![Building code from an external repo](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/github-vsts-yaml/setup-build.png)

In the next screen, we specify that we are building a project from GitHub, and paste in the access token we created earlier.

![entering the personal access token](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/github-vsts-yaml/entering-the-access-token.png).

Finally, we are presented with a list of all the repos our account has access to. We need to find our clone of `sql-server-samples` in this list and select it.

![selecting the repo](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/github-vsts-yaml/select-repo.png)

We're presented with a list of build process templates, the one we want is "YAML"

![selecting YAML build](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/github-vsts-yaml/select-yaml-build.png).

All that's left to do is specify the path to our YAML build definition, in this case `.vsts-ci-yml`.

![specifying the path to the yaml file](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/github-vsts-yaml/specify-path-to-yaml-file.png)

Having got this far, we can go ahead and select "Save and Queue", and a new build will be created using the "Hello World" build definition we created earlier.

If we look at the output of our build, we can see our text being written to the log.

![building the trivial project](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/github-vsts-yaml/successful-build.png)

Almost all of the elapsed time here was cloning the repo from GitHub, there is quite a lot of stuff in it!

## Building the real project

This is all very well, but we haven't managed to build our actual database project yet. To do so, we'll need to go back to GitHub and edit the build definition file.

The documentation for how to specify build steps in YAML is still a [work in progress](https://github.com/Microsoft/vsts-agent/tree/master/docs/preview). In summary, the current procedure is to visit the [VSTS Tasks repo on GitHub](https://github.com/Microsoft/vsts-tasks/tree/master/Tasks), open the folder for the task your are interested in, and take a look at the `task.json`. 

In our case, the first task we need is [MSBuild](https://github.com/Microsoft/vsts-tasks/tree/master/Tasks/MSBuild), to build the database project. Looking inside [task.json](https://github.com/Microsoft/vsts-tasks/blob/master/Tasks/MSBuild/task.json), we can see that the name of the task we need is `MSBuild`, and that there are a huge number of available `inputs` we can use to configure the task; `solution` to specify the project or solution to build, `platform`, `configuration`, and many more. In our case, we'll just specify the path to our `.sqlproj` file and let `msbuild` take care of the rest.

Having built the project, we need to copy our output somewhere so we can use it later. In this case, we'll use the "Publish Build Artifacts" task to copy the built dacpac file to VSTS.

The complete build definition is shown below. We build the database project with MSBuild, then specify the path to the built artifact to copy. The artifact itself needs a name, so we can reference it later, for instance in a Release Definition, as well as a type. `ArtifactType: Container` just means that we are storing the artifact in VSTS, rather than in an external file share, for example.

``` yaml
steps:
- task: MSBuild@1
  displayName: Build the database project
  inputs:
    solution: 'samples/databases/wide-world-importers/wwi-ssdt/wwi-ssdt/WideWorldImporters.sqlproj'
    
- task: PublishBuildArtifacts@1
  inputs:
    PathtoPublish: 'samples/databases/wide-world-importers/wwi-ssdt/wwi-ssdt/bin/Debug/WideWorldImporters.dacpac'
    ArtifactName: theDacpac
    ArtifactType: Container
```
If you take a glance at the history of this file, you'll observe it took me a couple of attempts to get this working; the single quotes turned out to be more important than I originally anticipated. Having overcome that hurdle, we can see that the build succeeds, and produces a single artifact containing our `dacpac` file.

![build succeeded and produced an artifact](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/github-vsts-yaml/build-succeeded.png)

For now, this is where the story ends for YAML builds in VSTS, I'll try to return to this topic later once YAML release management is publicly available.









[^1]: Note that contrary to the current version of the docs, "Build YAML Definitions" is an account-scoped feature rather than a user-scoped feature, so if you're following along at work this will enable it for every user in your VSTS Account.