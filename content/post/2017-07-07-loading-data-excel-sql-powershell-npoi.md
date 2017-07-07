+++
title=  'Loading Data from Excel to SQL Server with PowerShell and NPOI'
date =  "2017-07-07"
tags = ["Powershell", "SQL Server"]
draft = true
+++

It's all too common to come across a finely crafted "Enterprise" data architecture that contains a few "exceptions", where "the source system didn't have the data" and other excuses. It's also common to find these gaps being plugged by allowing some mechanism for importing additional reference data from Excel, often with SSIS.

Notwithstanding the [world of pain](https://stackoverflow.com/search?q=excel+ssis+error "Link to StackOverflow search for 'Excel SSIS Error'") that is SSIS and Excel, loading small amounts of data into from spreadsheets isn't really the strong point of SSIS, which is a great tool for loading _large_ amounts of data into a database for further processing.

Worse still, as I came across recently, when the client wants to move from an in-house SQL Server to a PaaS database such as Azure SQL Database or Amazon RDS, there's nowhere to run the package, leaving the client faced with the expense of standing up, licensing, maintaining, and patching an additional IaaS virtual machine with SSIS installed, all dedicated to the task of loading a few dozen rows from Excel into SQL Server.

There have been a few approaches to this over the years, many involving having Excel installed on the server where the data needs to be loaded, which even Microsoft [think is a bad idea](https://support.microsoft.com/en-gb/help/257757/considerations-for-server-side-automation-of-office). A better way is with [EPPlus](https://epplus.codeplex.com/), currently on codeplex and also used by the [PSExcel](https://github.com/RamblingCookieMonster/PSExcel) Powershell, which allows direct reading and writing of `.xlsx` files without any dependency on Excel.

However, I'd recently had some success with [Apache POI](https://poi.apache.org/), a Java (don't ask) library with similar functionality, and discovered that this also had a .NET derivative called [NPOI](https://github.com/tonyqus/npoi), handily available as a [nuget](https://www.nuget.org/packages/NPOI) package.


```
PS C:\Users\GavinCampbell> Register-PSRepository -Name NugetOrg -SourceLocation https://www.nuget.org/api/v2 -PublishLoc
ation https://www.nuget.org/api/v2/Packages -PackageManagementProvider NuGet

NuGet provider is required to continue
PowerShellGet requires NuGet provider version '2.8.5.201' or newer to interact with NuGet-based repositories. The NuGet
 provider must be available in 'C:\Program Files\PackageManagement\ProviderAssemblies' or
'C:\Users\GavinCampbell\AppData\Local\PackageManagement\ProviderAssemblies'. You can also install the NuGet provider by
 running 'Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force'. Do you want PowerShellGet to install
and import the NuGet provider now?
[Y] Yes  [N] No  [S] Suspend  [?] Help (default is "Y"): Y
```
installing the dll:

```
PS C:\Users\GavinCampbell> Save-Module -Name "NPOI" -Repository "NugetOrg" -Path "myProj"-Force -RequiredVersion 2.3.0
PS C:\Users\GavinCampbell> tree myProj
Folder PATH listing
Volume serial number is 0000019B DEFA:2F64
C:\USERS\GAVINCAMPBELL\MYPROJ
├───NPOI
│   └───2.3.0
│       ├───lib
│       │   ├───net20
│       │   └───net40
│       └───logo
└───SharpZipLib
    └───0.86.0
        └───lib
            ├───11
            ├───20
            ├───SL3
            └───SL4
PS C:\Users\GavinCampbell>

```
Save module works even though this isn't a powershell module; specifying the path allows us to have a "local" copy of the dependency.