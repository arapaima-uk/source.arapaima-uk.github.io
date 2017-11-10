+++
title = "Building this Site"
sidebar =  true
weight =  "10"
draft = false
toc = true
+++

# Overview

> This page is somewhat out of date now, I'm in the process of moving to new hosting in any case so will write a new post then.

This site is created using the [Hugo](http://gohugo.io/) static site generator and hosted on [GitHub Pages](https://pages.github.com/). It is built and deployed with [Travis CI](https://travis-ci.org/), meaning that changes and additions are pushed to the public website as soon as they are committed. For now this is an [MVP](http://dilbert.com/strip/2016-06-21), I'll add more moving parts and update this page accordingly as time goes on. There are a couple of features right "out of the box" such as drafts and scheduled posts.

## Github setup

To publish a personal or organizational site on GitHub Pages, all that is required is to create a repo named _\<username>_.github.io, where _\<username>_ is your GitHub user name or organization name. This site is for the organization arapaima-uk, so the repo is named [arapaima-uk.github.io](https://arapaima-uk.github.io), which also happens to be a url for the home page of the site. You can see the repository details at <https://github.com/arapaima-uk/arapaima-uk.github.io>. Now, how this works is that the contents of the master branch of this "special" repo are served as a static website. Since static site generators work by transforming some input files (markdown, reStructuredText, etc. ) into a static website (html, javascript, css, etc.) I decided to create a separate repo to hold the "source code" of the site, and use Travis CI to "build" and deploy the output to the master branch of the [arapaima-uk.github.io](https://arapaima-uk.github.io) repo. The "source" repo is [source.arapaima-uk.github.io](https://github.com/arapaima-uk/source.arapaima-uk.github.io). Note that this isn't a "special" repo, there's no page being served at <http://source.arapaima-uk.github.io/>.

## Hugo

### Getting Hugo
I started by downloading the latest release (v0.17) from [hugo's github releases page](https://github.com/spf13/hugo/releases). I followed the [instructions here](https://gohugo.io/tutorials/installing-on-windows/) to create the folders `D:\Hugo\bin` and `D:\Hugo\Sites`, and extracted the contents of the downloaded zip file to `D:\Hugo\bin`. I also renamed `hugo_0.17_windows_amd64.exe` to `hugo.exe`. Running `hugo help` from the bin folder is the easiest way to check that everything is working. Optionally, add the `hugo\bin` folder to your system path to avoid having to type the full path to the executable every time.

### Scaffolding the site

This is as easy as running `hugo new site source.arapaima-uk.github.io` from within our `hugo\Sites` folder. All being well, this will result in the following output:
````
$ ..\bin\hugo new site source.arapaima-uk.github.io
Congratulations! Your new Hugo site is created in "D:\\Hugo\\Sites\\source.arapaima-uk.github.io".

Just a few more steps and you're ready to go:

1. Download a theme into the same-named folder.
   Choose a theme from https://themes.gohugo.io/, or
   create your own with the "hugo new theme <THEMENAME>" command.
2. Perhaps you want to add some content. You can add single files
   with "hugo new <SECTIONNAME>/<FILENAME>.<FORMAT>".
3. Start the built-in live server via "hugo server".

Visit https://gohugo.io/ for quickstart guide and full documentation.
````

### Themes

After much consideration, I settled on the [Lanyon](http://themes.gohugo.io/lanyon/) theme for Hugo. Installing a theme is as simple as cloning the relevant repo into the `themes` folder under the root of your site.

````
D:\Hugo\Sites\source.arapaima-uk.github.io\themes
$ git clone https://github.com/tummychow/lanyon-hugo.git
Cloning into 'lanyon-hugo'...
remote: Counting objects: 320, done.
remote: Compressing objects: 100% (3/3), done.
remote: Total 320 (delta 0), reused 0 (delta 0), pack-reused 317 eceiving objects:  91% (292/320)
Receiving objects: 100% (320/320), 283.68 KiB | 0 bytes/s, done.
Resolving deltas: 100% (103/103), done.
Checking connectivity... done.
````
You can specify a theme with the `-t` flag when running `hugo` (to generate your site) or `hugo server` (to preview the site on a local webserver) at the command line. Given that I had only downloaded the one theme, I decided to lock in this choice by adding the line `theme = "lanyon-hugo"` to the `config.toml` file at the root of the site.

You should now be able to run `hugo server` from the root of your site, and view the (empty) site on <http://localhost:1313>

#### Customising the Theme

Customising themes in Hugo works by adding files to the root, or "working directory" of your site that override their counterparts inside the theme folder itself. This means that in order to override the favicons stored at `arapaima-uk.github.io\themes\lanyon-hugo\static\assets` , we create an `assets` folder under the `source.arapaima-uk.github.io\static` folder in our site and add our own `favicon.ico` as well as the all-important `apple-touch-icon-144-precomposed.png` (I have no idea what this does).

Likewise, we can override the pre-canned sidebar content by copying the file `sidebar.html` from  `\source.arapaima-uk.github.io\themes\lanyon-hugo\layouts\partials` to our own `\arapaima-uk.github.io\layouts\partials` folder. I made quite a few changes to this file, you can check them out directly on github [here](https://github.com/arapaima-uk/source.arapaima-uk.github.io/blob/master/layouts/partials/sidebar.html).

Now is a good time to have another look at the `config.toml` file that defines much of the behaviour of the site. The first section holds a few site-wide configuration items, whilst the `[params]` section holds variables that can be used by the templates that make up our theme. (_some_ changes in this file don't get read until the site is rebuilt, so if you are using `hugo server` to follow along you _may_ need to restart it.)
```
languageCode = "en-gb"
baseurl = "http://arapaima.uk/"
title = "Arapaima (UK)"
theme = "lanyon-hugo"
[params]
    DateForm =  "2006-01-02"
    Title = "arapaima.uk"
    Tagline =  "Data, Databases, Delivery"
    Author  = "Gavin Campbell"
```
### Static Pages

These are often used for "About me" or similar, I don't have one of those yet so we'll make do with the [file that contains the source for this article](https://raw.githubusercontent.com/arapaima-uk/source.arapaima-uk.github.io/master/content/fixed/BlogSetup.md). This is a markdown file called `BlogSetup.md`, that goes in the `\content\fixed\` folder of our working directory. There is a bit of metadata at the top, enclosed by plus signs, again in TOML format. The interesting items here are `sidebar="true"`, which will create a link in the sidebar for this page, and `weight = "10"`, which sets the relative ordering of sidebar items (heaviest weights sink to the bottom.) 
``` 
+++
title = "Building this Site"
sidebar =  true
weight =  "10"
+++
```

### A First Post

This is just a [markdown file](https://raw.githubusercontent.com/arapaima-uk/source.arapaima-uk.github.io/master/content/post/2016-10-13-verschlimmbesserung.md) with a bit of front matter (title, date) that goes in the `/content/post` folder.

### Syntax highlighting

For this site, we'll use server-side (i.e. pre-processed) syntax highlighting with [Pygments](http://pygments.org/). This requires installing [Python](https://www.python.org/downloads/), then running `pip install pygments` to install the module. You can run `pygmentize -h` to make sure everything is working, and that Hugo is able to find the command in your path. You can list the installed pygments styles with `pygmentize -L styles`. This turned out to be important, as the hugo default (monokai) turned out to be almost invisble against the background created by the lanyon theme. I decided on the "lovelace" theme, and set this by adding 
```
PygmentsCodeFences = "true"
PygmentsStyle = "lovelace"
```
to the `config.toml` file. The `PygmentsCodeFences` line allows specifying a style in markdown directly after the ```` ``` ```` , for example the following block is styled ```` ```c ````.

``` c
#include <stdio.h>
main()
{
    printf("Hello, world!\n");
}
```

## Github

We've got enough for a working site, time for a first commit. Before we start, we'll add a `.gitignore` file to the `public` folder of the site containing the following lines:
```
*
*/
!.gitignore
```
Since this is where the generated output ends up, we don't want to track the contents of this folder in our source repo on Github, the only place we need these files is on the public site itself. The three lines are telling git to ignore, respectively, all files in this folder, all files in subfolders of this folder, but not this `.gitignore` file itself. 


Now we just need to `git init`, hook our local repo up to Github with 
```
git remote add origin https://github.com/arapaima-uk/source.arapaima-uk.github.io.git
git branch --set-upstream master origin/master
git add .
git commit -m "Witty commit message goes here"
git push
```
## Travis CI

After signing into Travis CI with Github credentials, you need to flick the switch to enable Travis to access your source repository. There are a couple of extra setting hidden behind the little cog in the list of repos, notably "Build Only if .travis.yml is present" (set this to "on"), "Build Pushes" (set to "on"), and "Build Pull Requests (I set this to "off". I'm not taking pull requests right now...)

Next, we need to create a `.travis.yml` file in the root of the source repository.
### Build
I started with the following lines in mine:

``` yaml
sudo: required
install: 
  - wget https://github.com/spf13/hugo/releases/download/v0.17/hugo_0.17-64bit.deb
  - sudo dpkg -i hugo_0.17-64bit.deb
  - sudo pip install Pygments
   
script:
  - hugo -v
```
This will download and install pygments and hugo, then call the `hugo` executable to build our site. One detail here is that I'm fetching a specific version of hugo; I initially tried fetching the latest with `go get`, but this seemed to result in compatibility nightmares.

Now, when we commit and push the repo with the `.travis.yml` file included, Travis will fetch our code and build our site. If this step isn't working, there's not much point continuing, so take a moment to ensure that everything is green. You will observe that Travis isn't all that fast; I got a car for free once and it wasn't all that fast either.

### Deploy

Most of the instructions in this part are based on [this](http://www.steveklabnik.com/automatically_update_github_pages_with_travis_example/) article. There are a few security hoops to jump through here. You need to create a Github Access Token [here](https://github.com/settings/tokens/new), which Travis will use to authenticate to the Github Pages repo. The scope of the token needs to be "repo". You need to paste this into another window straight away, as Github will only show it to you once.

This needs to be pasted into an environment variable named GH_TOKEN in the settings of your repo on Travis CI, there is a switch for "Display value in build log", which you want to have set to "off". 

The next step uses the Travis command line ruby gem, you'll need to install ruby followed by `gem install travis` if you haven't got this already. If you do this from the root directory of your repo, the key will be automatically added to your `.travis.yml` file.

```
travis encrypt -r username/reponame GH_TOKEN=[the token you created before] --add
```
Finally we need a deploy script to copy the files from Travis back to the Github pages repo. The following script, in the root of the repo, does the following:

  - Saves the hash at the head of the source repo to use in the commit message for the target
  - Deletes the `.gitignore` file so that our content pages don't get ignored when we push to the new site (ask me how I figure this out...)
  - Creates a _new_ git repo to hook up to our target.
  - Writes the CNAME file needed by GitHub pages to redirect our `.github.io` name to our "real" domain name. If this is currently pointing somewhere else at your DNS provider, your site will be hosed after you do this as your `github.io` name will redirect your "real" name, which is still pointing somewhere else! If you encounter problems here it's probably best to delete this line until everything is working again.
  - Touches every file in the repo so they look "new".
  - Pushes the pages to our GH Pages Repo


``` bash
#!/usr/bin/env bash

rev=$(git rev-parse --short HEAD)

cd public
rm .gitignore

git init
git config user.name "Travis CI"
git config user.email "travis@arapaima.uk"

git remote add upstream "https://$GH_TOKEN@github.com/arapaima-uk/arapaima-uk.github.io.git"
git fetch upstream
git reset upstream/master

echo "arapaima.uk" > CNAME

touch .

git add -A .
git commit -m "rebuild pages at ${rev}"
git push -q upstream HEAD:master
```

### DNS stuff

If you're using a custom domain, now is a good time to log into your DNS provider and follow the steps [here](https://help.github.com/articles/using-a-custom-domain-with-github-pages/). It took a while for my ISP to get the change, clearly their DNS servers don't get up as early on a Saturday as I do.

# Profit!

Having got to here, we definitely want to have one of those build status buttons in the sidebar of our site.

This can be done by adding the following to the template, substituting the name of your source repo (not the Github Pages one! as appropriate).

``` html
  <div class = "sidebar-item">
  <p> <a href = "https://travis-ci.org/arapaima-uk/source.arapaima-uk.github.io">
      <img src = "https://travis-ci.org/arapaima-uk/source.arapaima-uk.github.io.svg?branch=master" alt = "Travis CI Build Status" title = "Travis CI Build Status">
      </a>
    </p>
  </div>
  ```

  In fact, I think I'll have one here too: [![Build Status](https://travis-ci.org/arapaima-uk/source.arapaima-uk.github.io.svg?branch=master)](https://travis-ci.org/arapaima-uk/source.arapaima-uk.github.io) You can get these links in various formats by clicking on the build status icon in the home page of your repo on Travis.

# Bells and Whistles

## Talk is cheap

One of the more difficult things to do on a static site is to support user-generated content such as comments. Many sites resort to hosted services such as [Disqus](https://disqus.com/), but I wasn't too keen on this option for the usual tinfoil-hat reasons; inline adverts, tracking cookies, _"7 Secrets UK Billionaires Don't want You to Know"_, etc., etc.

### Options for hosting comments on statically generated sites

There are a number of self-hosted alternatives available, most notably [Discourse](https://discourse.org/), which provides a full-featured discussion forum that can be pressed into service as a comments engine. 

I did play with this in an earlier incarnation of this site, and I think it's great, but it is fairly demanding of server resources; their recommended configuration costs $20 a month at DigitalOcean at the time of writing, which is a bit much for a site that otherwise costs $0. If this were a bigger, more popular site, I'd definitely be considering it, but given that 90% of the visitors to these pages could probably phone me if they wished to comment on any of the material here it seems like overkill. 

I liked the look of [isso](https://posativ.org/isso/) too, this still requires a VPS to host, but a much lower specfication one will do. [Hashover](https://github.com/jacobwb/hashover-next) also looked promising, and can apparently be made to work on cheap shared hosting without a VPS. I also looked at [lambda-comments](https://github.com/jimpick/lambda-comments), which I think is a very interesting example of a "serverless" service and has given me a couple of ideas of my own. What all these approaches have in common is that the comments are stored somewhere other than on the main site - probably in a database of some description. This means at least _thinking_ about maybe backing this data up, even if the thought is just "really should get around to backing that data up".

This content will need to be read and rendered somehow every time the page is served.

### Storing the comments in the repo along with the rest of the content

I was aware, however, from some previous experimentation with [Pelican](https://getpelican.com/), that there were techniques available for storing comments as text - or markdown, yaml, whatever - files in the repo along with the rest of the content, and using the GitHub "Pull Request" mechanism to provide a means for comment moderation. Some searching brought me to [Staticman](https://staticman.net/), a free service that promises to do just this, either via their own hosted instance or via a private instance hosted on your own server. 

## Staticman

I went for the Staticman hosted version, and managed to get pretty well set up by following the instructions on the website. Staticman seems to be mainly aimed at [Jekyll](https://jekyllrb.com/) users, but there is an [example Hugo site](https://hugo.staticman.net/) with source code on [Github](https://github.com/eduardoboucas/hugo-plus-staticman) that was a great help in the Hugo-specific templates (and I borrowed the [css](https://github.com/arapaima-uk/source.arapaima-uk.github.io/blob/master/static/css/comments.css) for the form from there too!).

In principle, the user fills in a form on your page, and the comment is sent to the Staticman web service, which turns the comment into a pull request - or a commit, if moderation is turned off - in your source repo. For this to work, the staticmanapp user needs to be added as a "collaborator" on your Github project - this is, as far as I can see, the main motivation for using a self-hosted instance of the service, but I decided to take the risk that the Staticman developer will go crazy and start posting lewd messages to his users' repos!

Each message is stored as a separate file, in a folder that corresponds to the post. In my configuration, file and folder names are md5 checksums, so not the most user friendly, but the [post-comments.html](https://github.com/arapaima-uk/source.arapaima-uk.github.io/blob/master/layouts/partials/post-comments.html) partial is able to use these to make sure the right comments get displayed with the right post. All of this behaviour - and much more - is configurable through the [staticman.yml](https://github.com/arapaima-uk/source.arapaima-uk.github.io/blob/master/staticman.yml) file stored in the root of the source repo. It follows from this that users are able to edit their comments by finding the appropriate file in the repo and submitting a new pull request!

All of this has the huge advantage that comments aren't summoned up from any external source at page load time; they are simply baked into the html source of the page by the Hugo build process.
