+++
title=  'Hosting your reveal.js presentations in a subfolder of your Github pages site'
date =  "2018-02-27"
tags = ["OffTopic", "GitHub", "revealjs"]
draft = false
+++

Someone recently asked me how I did this so I thought I'd note it down here in case it's of use to anyone else.

There are a couple of things which I think are prerequisites, namely that this site [arapaima.uk](http://arapaima.uk) is [hosted on GitHub Pages]({{< ref "fixed/BlogSetup.md#github-setup" >}}), and has a [custom domain](https://help.github.com/articles/using-a-custom-domain-with-github-pages/).

Most of the [reveal.js](https://revealjs.com) slides for the public talks I've done, at least recently, are themselves hosted on Github, in individual repos such as [this one](https://github.com/arapaima-uk/slides-tsqlt-groupby) or [this one](https://github.com/arapaima-uk/database-cd-ssdt-vsts).

## Tags

Now for the science bit. After I've finished with a talk, I create a [tag](https://git-scm.com/book/en/v2/Git-Basics-Tagging) in the repo to indicate which event it was from. Tags are created with the syntax

{{< highlight bash >}}
git tag -a SQLBits2018 -m "SQLBits 2018, February 24 2018"
{{< / highlight >}}

and can be reviewed by typing `git tag` to see a list of tags, or `git show SQLBits2018` to see the commit to which the tag refers:

{{< highlight bash >}}
[gavin@THINKPAD database-cd-ssdt-vsts]$ git show SQLBits2018 
tag SQLBits2018
Tagger: Gavin Campbell <gavin@arapaima.uk>
Date:   Tue Feb 27 17:19:44 2018 +0000

SQLBits 2017, 24 February 2018

commit bc5694ee81354a311bb37a457ec5c790ef970f8e (HEAD -> master, tag: SQLBits2018)
Author: Gavin Campbell <gavin@arapaima.uk>
Date:   Tue Feb 27 17:13:46 2018 +0000

    SQLBits Version
{{< / highlight >}}

What the tags enable me to do is show two different versions of the _same repo_ under different urls.

Before we move onto the next stage, we need to explicitly push our tag(s) to the remote (i.e. GitHub) with the command `git push --tags`.

## Submodules

The magic happens through the use of the much-maligned [`git submodule`](https://git-scm.com/docs/git-submodule) command.

First, I created an empty repo called `presentations`.


{{< highlight bash >}}
mkdir presentations && cd presentations
git init

{{< /highlight >}}

Next, I clone the repo containing the presentation into a submodule of this empty repo.


{{< highlight bash >}}
[gavin@THINKPAD presentations]$git submodule add https://github.com/arapaima-uk/database-cd-ssdt-vsts database-cd-sqlbits-2018


Cloning into '/home/gavin/presentations/database-cd-sqlbits-2018'...
remote: Counting objects: 233, done.
remote: Compressing objects: 100% (183/183), done.
remote: Total 233 (delta 48), reused 227 (delta 42), pack-reused 0
Receiving objects: 100% (233/233), 7.85 MiB | 442.00 KiB/s, done.
Resolving deltas: 100% (48/48), done.

{{< /highlight >}}

Note that I am specifying the folder name in which to create the submodule, this will form part of the url of the presentation so it has two purposes; firstly to give the folder a "pretty" name, and secondly to allow this repo to contain more than one submodule referring to the same source repo, i.e. more than one version of the same presentation, by specifying `git submodule add https://github.com/arapaima-uk/database-cd-ssdt-vsts some-other-folder`. 

The other thing to note is that the clone url of the submodule *must* use `https://` rather than `git://`, or nothing will work. _Ask me how I know this sometime._

Next, we need to change to the submodule directory, and `checkout` the tag we created earlier.

{{< highlight bash >}}

[gavin@THINKPAD database-cd-sqlbits-2018]$ git checkout SQLBits2018 
Note: checking out 'SQLBits2018'.

You are in 'detached HEAD' state. You can look around, make experimental
changes and commit them, and you can discard any commits you make in this
state without impacting any branches by performing another checkout.

If you want to create a new branch to retain commits you create, you may
do so (now or later) by using -b with the checkout command again. Example:

  git checkout -b <new-branch-name>

HEAD is now at bc5694e... SQLBits Version
[gavin@THINKPAD database-cd-sqlbits-2018]$ git status
HEAD detached at SQLBits2018
nothing to commit, working tree clean
{{< /highlight >}}

This has left our repo suffering from the dreaded "[detached head](https://www.google.co.uk/search?q=git+detached+head)" condition, as confirmed above by `git status`,  and whilst I would ordinarily regard knowing how to recover from this as a key career-enhancing ability, in this instance we don't need to do anything.

Without going into a detailed explanation of `git submodule`, if we go back to the `presentations` root directory (`cd ..`), and do `git status` again, we can see the following:

{{< highlight bash >}}
[gavin@THINKPAD presentations]$ git status
On branch master
Your branch is up-to-date with 'origin/master'.

Changes to be committed:
  (use "git reset HEAD <file>..." to unstage)

	modified:   .gitmodules
	new file:   database-cd-sqlbits-2018
{{< /highlight >}}

There are no detached heads here, the `presentations` repo is still on the `master` branch, and we are adding the `database-cd-sqlbits-2018` folder as well as modifying the `.gitmodules` file, which contains a list of submodules as well as the commits to which they point, in this case the "detached head" tags. (I think the reason mine says `modified` rather than `added` is that this isn't the first submodule I've created.)

There's one more thing we need to do, which is to prevent [Github pages]({{< ref "#repo-settings" >}}) from trying to render our [reveal.js](https://revealjs.com) presentations using [Jekyll](https://jekyllrb.com/), Github's "built-in" static site generator. To do this, we just need to create an empty file called `.nojekyll` at the root of our repo. I also created a dummy `index.html`. 

{{< highlight bash >}}
[gavin@THINKPAD presentations]$touch .nojekyll
[gavin@THINKPAD presentations]$echo "<html><body>Some Text</body></html>" > index.html

{{< /highlight >}}

_(Yes, this took me a while to figure out. If you don't do this, you will get all sorts of errors reported when you try to publish the site. The index page does get rendered at arapaima.uk/presentations, one day I'll get around to making it prettier, possibly by reading the contents of the submodules and generating it dynamically. However, it isn't linked to anywhere, not even from here!)_


Finally we need to commit these changes in the main repo, and push them to Github.

{{< highlight bash >}}
[gavin@THINKPAD presentations]$ git add .
[gavin@THINKPAD presentations]$ git commit -m "added sqlbits presentation"

{{< /highlight >}}

If you haven't done so already, create the `presentations` repo in your GitHub account:

![Creating a Repo in the Github UI](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/hosting-revealjs-github-pages/createrepo.png)
_(yes, I already had a "`presentations`", so this one is called "`presentation`"!)_

 then add it as a remote and push your changes:

{{< highlight bash>}}
git remote add origin https://github.com/arapaima-uk/presentations.git
git push -u origin master
{{< /highlight >}}

You can see my `presentations` repo on Github [here](https://github.com/arapaima-uk/presentations).

## Repo Settings

In the settings for the newly created repo, there is a section "Github Pages":

![selecting the Github pages branch in the repo settings](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/hosting-revealjs-github-pages/selectmasterbranch.png)

After selecting the `master` branch and clicking "Save", you should see the following:

![Github pages publish settings created](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/hosting-revealjs-github-pages/branchselected.png)

Now, because the main site is a Github [organisation page](https://help.github.com/articles/user-organization-and-project-pages/) with a custom domain, this project page has been created as a [subdirectory of the main site](https://help.github.com/articles/custom-domain-redirects-for-github-pages-sites/).

If all is well, and you've got to here, you should be able to see your presentation on [http://arapaima.uk/presentations/database-cd-sqlbits-2018/](http://arapaima.uk/presentations/database-cd-sqlbits-2018/), substituting your domain for [arapaima.uk](http://arapaima.uk) and your presentation title for `database-cd-sqlbits-2018`.

There's a list of all the talks I've done, of which the top few have slide decks linked in this manner, [here]({{< ref "fixed/Speaking.md#past">}}).

## Further reading

These are some of the articles I found useful when putting this all together:

* [Hosting Reveal.js Slide Decks on a Jekyll-generated blog](http://jpmoral.com/blogging/2015/07/29/hosting-revealjs-slides-on-jekyll.html)
* [Reveal.js + GitHub Pages: when developers give talks](https://www.chenhuijing.com/blog/revealjs-and-github-pages/)
* [Tie Git Submodules to a Particular Commit or Branch ](https://twoguysarguing.wordpress.com/2010/11/14/tie-git-submodules-to-a-particular-commit-or-branch/)
* [Hosting a reveal.js presentation on github pages](http://annaken.github.io/hosting-revealjs-presentation-github-pages)