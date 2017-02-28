+++
title=  "A script to download and install the Pester testing framework for PowerShell"
date =  "2017-02-28"
tags = ["PowerShell", "Pester", "TDD"]
draft = false
+++

I finally got around to looking into [Pester](https://github.com/pester/Pester) for test-driven development with PowerShell. In case it's useful to anyone, and so that I don't lose it, I created a script to download the latest release version, store it in the user's PowerShell modules folder, and run a quick test to make sure everything is working. The script is stored in a [GitHubGist](https://gist.github.com/gavincampbell/05c803654ff70d21d538b49f0e363a6a) and is reproduced below. The steps are roughly as follows:

* Figure out what the latest release number is.
* Assemble the correct url to download the zip file.
* Download and "Unblock" the zip file.
* Figure out where the user's modules folder is and create it if it doesn't exist. I had to exclude the [vscode](https://code.visualstudio.com/) modules folder for this to work for me.
* Unzip the downloaded file to the right place.
* Import the newly installed modules.
* Scaffold a test with `New-Fixture`. The name is randomised to minimise the chance of overwriting something that's already there.
* Hack the generated files about a bit.
* Run the test.
* Clean up the generated files.
* Profit!


## The script

{{<gist gavincampbell 05c803654ff70d21d538b49f0e363a6a>}}
