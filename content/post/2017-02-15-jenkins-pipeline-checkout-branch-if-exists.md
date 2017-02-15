+++
title=  "Testing whether a branch exists before checking out in Jenkins Pipeline"
date =  "2017-02-17"
tags = ["Jenkins"]
draft = false
+++

For reasons, I recently found myself in a scenario where I needed to test whether a branch existed before checking it out, and resorting to a sensible default - such as checking out `master`, if it didn't. From the command line, this is a simple matter of `git branch -l | grep myBranch`, but I needed to do this from the context of a Jenkins pipeline job.

## Preliminaries
For simplicity, I'm creating a local repo I can point my Jenkins job at, right inside the `JENKINS_HOME` folder.

``` bash
jenkins@d99f4f77acdb:/$ cd $JENKINS_HOME
jenkins@d99f4f77acdb:~$ mkdir testBranch ; cd testBranch
jenkins@d99f4f77acdb:~/testBranch$ git init
Initialized empty Git repository in /var/jenkins_home/testBranch/.git/
jenkins@d99f4f77acdb:~/testBranch$ echo "Half a league, half a league, Half a league onward." > myFile.txt
jenkins@d99f4f77acdb:~/testBranch$ git add .
jenkins@d99f4f77acdb:~/testBranch$ git commit -m "Initial Commit"
[master (root-commit) 7ef4b3b] Initial Commit
 1 file changed, 1 insertion(+)
 create mode 100644 myFile.txt
jenkins@d99f4f77acdb:~/testBranch$ git checkout -b thisBranchExists
Switched to a new branch 'thisBranchExists'
jenkins@d99f4f77acdb:~/testBranch$ echo "All in the valley of Death Rode the six hundred" >> myFile.txt
jenkins@d99f4f77acdb:~/testBranch$ git commit -am "a change"
jenkins@d99f4f77acdb:~/testBranch$ git checkout master
Switched to branch 'master'
jenkins@d99f4f77acdb:~/testBranch$ git log --oneline --decorate --all --graph
* 550587f (thisBranchExists) a change
* 7ef4b3b (HEAD, master) Initial Commit
```
With that out of the way, we have a repo with two branches, one of which is a single commit ahead of the other. Our goal, in the pipeline script, is to checkout the `thisBranchExists` branch, if it exists, or to fall back to `master` if it doesn't.

## The Pipeline script

I've created a simple script in the Pipeline UI to demonstrate the use of [`resolveScm`](https://jenkins.io/doc/pipeline/steps/workflow-multibranch/#resolvescm-resolves-an-scm-from-an-scm-source-and-a-list-of-candidate-target-branch-names) to figure out whether the branch we want exists. `resolveScm` will go through the contents of `targets` in order, and return the first one that matches a branch name in the repo. We then checkout the branch and print the contents of the file to the console with `cat`.

``` groovy
node{
def b = resolveScm source: [$class: 'GitSCMSource', credentialsId: '', 
    excludes: '', id: '_', ignoreOnPushNotifications: false, includes: '*', 
    remote: 'file://$JENKINS_HOME/testBranch'], targets: ['thisBranchExists', 'master']
checkout b
sh 'cat myFile.txt'
   
}
```

## The Happy path
When we run this job we get the following output, indicating that our branch was located successfully. The contents of the file after the second commit are printed to the console.

``` bash
Running on master in /var/jenkins_home/workspace/checkout_branch_if_exists
[Pipeline] {
[Pipeline] resolveScm
Checking for first existing branch from [thisBranchExists, master]...
 > git rev-parse --is-inside-work-tree # timeout=10
Setting origin to file://$JENKINS_HOME/testBranch
 > git config remote.origin.url file://$JENKINS_HOME/testBranch # timeout=10
Fetching & pruning origin...
Fetching upstream changes from origin
 > git --version # timeout=10
 > git fetch --tags --progress origin +refs/heads/*:refs/remotes/origin/* --prune
Getting remote branches...
Seen branch in repository origin/master
Seen branch in repository origin/thisBranchExists
Seen 2 remote branches
Checking branch master
Checking branch thisBranchExists
Found thisBranchExists at revision 550587fa43778989f50ca314feea38fdee50b21c
[Pipeline] checkout
 > git rev-parse --is-inside-work-tree # timeout=10
Fetching changes from the remote Git repository
 > git config remote.origin.url file:///var/jenkins_home/testBranch # timeout=10
Fetching upstream changes from file:///var/jenkins_home/testBranch
 > git --version # timeout=10
 > git fetch --tags --progress file:///var/jenkins_home/testBranch +refs/heads/*:refs/remotes/origin/*
Checking out Revision 550587fa43778989f50ca314feea38fdee50b21c (thisBranchExists)
 > git config core.sparsecheckout # timeout=10
 > git checkout -f 550587fa43778989f50ca314feea38fdee50b21c
 > git rev-list 550587fa43778989f50ca314feea38fdee50b21c # timeout=10
[Pipeline] sh
[checkout_branch_if_exists] Running shell script
+ cat myFile.txt
Half a league, half a league, Half a league onward.
All in the valley of Death Rode the six hundred
[Pipeline] }
[Pipeline] // node
[Pipeline] End of Pipeline
Finished: SUCCESS
```

## The "less-happy" path

Lets see what happens if we change our list of `targets` to `['thisBranchDoesNotExist', 'master']`. This time we don't find our "preferred" branch, so we fall back to `master` and print the contents of the file as it was after the first commit.

```bash
[Pipeline] node
Running on master in /var/jenkins_home/workspace/checkout_branch_if_exists
[Pipeline] {
[Pipeline] resolveScm
Checking for first existing branch from [thisBranchDoesNotExist, master]...
 > git rev-parse --is-inside-work-tree # timeout=10
Setting origin to file://$JENKINS_HOME/testBranch
 > git config remote.origin.url file://$JENKINS_HOME/testBranch # timeout=10
Fetching & pruning origin...
Fetching upstream changes from origin
 > git --version # timeout=10
 > git fetch --tags --progress origin +refs/heads/*:refs/remotes/origin/* --prune
Getting remote branches...
Seen branch in repository origin/master
Seen branch in repository origin/thisBranchExists
Seen 2 remote branches
Checking branch thisBranchExists
Checking branch master
Done.
Found master at revision 7ef4b3b3eaf296528e47cdf8946545b38f49fb95
[Pipeline] checkout
 > git rev-parse --is-inside-work-tree # timeout=10
Fetching changes from the remote Git repository
 > git config remote.origin.url file:///var/jenkins_home/testBranch # timeout=10
Fetching upstream changes from file:///var/jenkins_home/testBranch
 > git --version # timeout=10
 > git fetch --tags --progress file:///var/jenkins_home/testBranch +refs/heads/*:refs/remotes/origin/*
Checking out Revision 7ef4b3b3eaf296528e47cdf8946545b38f49fb95 (master)
 > git config core.sparsecheckout # timeout=10
 > git checkout -f 7ef4b3b3eaf296528e47cdf8946545b38f49fb95
 > git rev-list 550587fa43778989f50ca314feea38fdee50b21c # timeout=10
[Pipeline] sh
[checkout_branch_if_exists] Running shell script
+ cat myFile.txt
Half a league, half a league, Half a league onward.
[Pipeline] }
[Pipeline] // node
[Pipeline] End of Pipeline
Finished: SUCCESS
```

## The Unhappy path

Finally, let's see what happens if none of the branches we specify in `targets` exist in the repo. Regrettably, the output is rather shorter, as the step fails if no matching branches are found.

``` bash
Running on master in /var/jenkins_home/workspace/checkout_branch_if_exists
[Pipeline] {
[Pipeline] resolveScm
Checking for first existing branch from [thisBranchDoesNotExist, thisBranchDoesNotExistEither]...
 > git rev-parse --is-inside-work-tree # timeout=10
Setting origin to file://$JENKINS_HOME/testBranch
 > git config remote.origin.url file://$JENKINS_HOME/testBranch # timeout=10
Fetching & pruning origin...
Fetching upstream changes from origin
 > git --version # timeout=10
 > git fetch --tags --progress origin +refs/heads/*:refs/remotes/origin/* --prune
Getting remote branches...
Seen branch in repository origin/master
Seen branch in repository origin/thisBranchExists
Seen 2 remote branches
Checking branch master
Checking branch thisBranchExists
Done.
Could not find any matching branch%n
[Pipeline] }
[Pipeline] // node
[Pipeline] End of Pipeline
ERROR: Could not find any matching branch
Finished: FAILURE
```