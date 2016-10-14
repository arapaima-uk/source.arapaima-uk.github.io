+++
title = "Building this Site"
sidebar =  true
weight =  "10"
+++

# Overview

This blog is created using the [Hugo](http://gohugo.io/) static site generator and hosted on [GitHub Pages](https://pages.github.com/). It is built and deployed with [Travis CI](https://travis-ci.org/), meaning that changes and additions are pushed to the public website as soon as they are committed. For now this is an [MVP](http://dilbert.com/strip/2016-06-21), I'll add more moving parts and update this page accordingly as time goes on.

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
[Params]
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

I started with the following lines in mine

``` yaml
language: go
sudo: required
install: 
    - sudo pip install Pygments
    - go get -v github.com/spf13/hugo
script:
  - hugo
```


Now, when you commit and push the repo with the `.travis.yml` file included