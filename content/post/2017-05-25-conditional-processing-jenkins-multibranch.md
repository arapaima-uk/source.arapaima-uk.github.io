+++
title=  'Enabling per-branch configuration in a Jenkins Multibranch Pipeline'
date =  "2017-05-25"
tags = ["Jenkins"]
draft = false
+++

For reasons, you might want your [Jenkins Multibranch Pipeline](https://jenkins.io/doc/book/pipeline/multibranch/) jobs to do a different thing depending on which branch is being built.

Fortunately, the multibranch plugin provides us with a built-in variable `BRANCH_NAME`, which we can use to figure out which branch we are currently building.

In such scenarios, it's not a bad idea to create a minimal `Jenkinsfile` at the repo root that contains just enough logic to figure out which branch we are on,  and then call another groovy script that contains the actual build definition:

{{<gist gavincampbell 480843552e43efa84c60f9bb4840d6c1 "Jenkinsfile" >}}

In this script we load an external groovy file based on the current branch, and then call the function defined therein. In this particular case, the `run_build()` functions don't do anything particularly exciting, but they probably do enough to demonstrate this mechanism. 

#### The script for the master branch:
{{<gist gavincampbell 480843552e43efa84c60f9bb4840d6c1 "master.groovy" >}}

#### The script for any other branch:
{{<gist gavincampbell 480843552e43efa84c60f9bb4840d6c1 "not-master.groovy" >}}

The most important line in each of these scripts is the `return this` at the end; as [documented](https://jenkins.io/doc/pipeline/steps/workflow-cps/#code-load-code-evaluate-a-groovy-source-file-into-the-pipeline-script), this is required for the functions to be callable from the outer script. The `checkout scm` step in the root `Jenkinsfile` is also required, as without it the rest of the scripts won't be fetched from the repo. All three of these files are in the root of the repo, this is because gist doesn't support folders. In "real life", it's probably a good idea to create a separate folder for these scripts, and provide the path to the `load` function.

## Trying this out at home

If you don't have a Jenkins server handy, you can create a new one with `docker run -p 8080:8080 jenkinsci/jenkins:lts`[^1] and connect to it on http://localhost:8080. After that, it's just a question of creating a new job of type "Mutibranch Pipeline" and specifying an appropriate name. 

In the "Branch Sources" section, add a source of type "Git" (not "Github"!), and provide it with the path to the source repo, in this case the gist.

### Using a gist as a source repo?

It might be a lesser known fact about Github that gists are [really just repos with a few extra rules](https://help.github.com/articles/forking-and-cloning-gists/) that can be forked and cloned like any other Github repo. What it doesn't say in that linked page is that you can also create branches, even if these new branches aren't visible in the Gist UI. So, if you create a fork of https://gist.github.com/gavincampbell/480843552e43efa84c60f9bb4840d6c1, you should end up with an identical gist in your own Github account. You can then paste the url of this gist into the Jenkins job definition as shown:

![Gist url in git scm step](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/jenkins-multibranch-gist/multibranch-pipeline-from-gist.png)

The other thing to note here is the checkbox for "Scan Multibranch Pipeline Triggers"; since we aren't configuring any push notifications from our git repo, we need to get Jenkins to scan the repo periodically to look for any new branches, or new commits in existing branches. (In my particular case, since the Jenkins instance is just an ephemeral Docker image, there's no route to it anyway.)

When you save the job configuration, Jenkins will scan the source repo, and create the first pipeline job:

![pipeline job for master branch](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/jenkins-multibranch-gist/master-pipeline-job.png)

### Creating a new branch

As noted above, there's nothing in the gist UI to support creating new branches. However, if we clone the gist repo to a local folder we can create the branch and push it back to the origin. You can substitute the url to your own fork of the gist in place of mine (there's only one branch in mine, and you don't have permission to create more!). The downside of this approach of using a gist rather than a "proper" repo is that by default you get a long guid instead of a readable folder name.

```console

$ mkdir j && cd j;
$ git clone https://gist.github.com/gavincampbell/480843552e43efa84c60f9bb4840d6c1
Cloning into '480843552e43efa84c60f9bb4840d6c1'...
remote: Counting objects: 32, done.
remote: Compressing objects: 100% (32/32), done.
remote: Total 32 (delta 7), reused 0 (delta 0), pack-reused 0
Unpacking objects: 100% (32/32), done.
Checking connectivity... done.
$ cd 480843552e43efa84c60f9bb4840d6c1/
$ git status
On branch master
Your branch is up-to-date with 'origin/master'.
nothing to commit, working tree clean
$ git checkout -b fancyFeature
Switched to a new branch 'fancyFeature'
$ git push --set-upstream origin fancyFeature

Total 0 (delta 0), reused 0 (delta 0)
To https://gist.github.com/gavincampbell/480843552e43efa84c60f9bb4840d6c1
 * [new branch]      fancyFeature -> fancyFeature
Branch fancyFeature set up to track remote branch fancyFeature from origin.
```

The next time the repo is scanned,  the new job will be created in Jenkins:

![job created for new branch] (https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/jenkins-multibranch-gist/job-created-for-new-branch.png)


When the branch is deleted, the job wil disappear too:

```console

$ git push origin --delete fancyFeature

To https://gist.github.com/gavincampbell/480843552e43efa84c60f9bb4840d6c1
 - [deleted]         fancyFeature

```

Looking in the "Multibranch Pipeline Log" confirms this:
```console
[Thu May 25 22:40:36 UTC 2017] Finished branch indexing. Indexing took 1.7 sec
Evaluating orphaned items in jenkins-branch-conditions
Will remove fancyFeature as it is #1 in the list
Finished: SUCCESS
```


[^1]:Depending on your system configuration, this step may have one or more prerequisites!