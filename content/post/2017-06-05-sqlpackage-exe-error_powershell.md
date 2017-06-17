+++
title=  'Getting the output of `sqlpackage.exe` in a PowerShell Script'
date =  "2017-06-05"
tags = ["SSDT", "PowerShell"]
draft = true
+++

Just a quick note, but I ran into this at work and decided to write it down here in case it proved more generally useful. Given a dacpac test.dacpac and a simple deploy and test script:

```
sqlpackage.exe /Action:Publish 

```

The problem we encountered was that in the event the deployment failed, the script would continue regardless, resulting in a "false positive" for the deployment and a "false negative" for the tests, neither of which is a particularly desirable outcome.