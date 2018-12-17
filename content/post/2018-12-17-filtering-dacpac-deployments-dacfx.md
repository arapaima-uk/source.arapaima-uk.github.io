+++
title=  'Filtering Dacpac deployments with DacFX and Powershell'
date =  "2018-12-17"
tags = ["DacFX","SSDT"]
draft = false

+++

Prompted by some discussion on the [SQL Community Slack](https://sqlps.io/slack/), I thought I'd revisit [this old post](https://blogs.msdn.microsoft.com/ssdt/2016/09/20/schema-compare-in-sqlpackage-and-the-data-tier-application-framework-dacfx/) on the SSDT Team Blog which outlines how to filter specific objects from a dacpac deployment using the [Schema Compare API](https://docs.microsoft.com/en-us/dotnet/api/microsoft.sqlserver.dac.compare?view=sql-dacfx-140.3881.1).

In the past, I've used [Ed Elliott's](https://the.agilesql.club/) [filtering deployment contributor](https://github.com/GoEddie/DeploymentContributorFilterer) for this kind of thing, but in the interest of experimentation I thought I'd have a look at what comes "in the box", not least because deployment contributors can, ironically, be a bit of a pain to _deploy_.

I've created a [simple project](https://github.com/arapaima-uk/FilteringDemo/tree/master/FilteringDemo) you can use to play along at home, with two schemas, named `Production` and `UnProduction`, each containing a single table. I've also included a publish profile that can be used to publish the project to a local database called "Unfiltered".

In this example, we'll use the schema compare API to allow only the `Production` schema and the table it contains to deployed.

The action takes place in the powershell script [Filtered Deploy.ps1](https://github.com/arapaima-uk/FilteringDemo/blob/master/FilteringDemo/FilteredDeploy.ps1), which I've reproduced in its entirety here:

``` powershell
$serverName = 'localhost'
$databaseName = 'Filtered'
$schemaToInclude = 'Production'
$dacFxDll='C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin\Microsoft.SqlServer.Dac.Extensions.dll'

$dacpacPath = "$PSScriptRoot\bin\Debug\FilteringDemo.dacpac"

Add-Type -Path $dacFxDll

$sourceDacpac = New-Object Microsoft.SqlServer.Dac.Compare.SchemaCompareDacpacEndpoint($dacpacPath);

$targetDatabase = New-Object Microsoft.SqlServer.Dac.Compare.SchemaCompareDatabaseEndpoint("Data Source=$serverName;Initial Catalog=$databaseName;Integrated Security=True;")

$comparison = New-Object Microsoft.SqlServer.Dac.Compare.SchemaComparison($sourceDacpac, $targetDatabase)

$comparisonResult = $comparison.Compare()

$comparisonResult.Differences | %{
	if( $_.SourceObject.name.parts[0] -ne $schemaToInclude){
		Write-Output "Excluding Object $($_.SourceObject.name)"
		$comparisonResult.Exclude($_) | Out-Null

	}

}

$publishResult =  $comparisonResult.PublishChangesToTarget();

if ($publishResult.Success){
	Write-Output "Worky"
}
else{
	Write-Output "NoWorky"
}

```
Briefly, we load the dll that contains the classes we need to use, and set up a schema comparison between a source dacpac and a target database. There are two key pre-requisites for this, which are

* the dacpac must exist, meaning that the project must have been built
* the target database must exist, meaning that this script can't be used for "first-time" deployment. _This is a departure from the "usual way" of working with SSDT, and IMV the biggest limitation of this approach._
  
Moving on, we execute the comparison using `SchemaComparison.Compare()`, then iterate the list of differences looking for source objects that match - or in this case don't match - our filter.  This kind of thing is useful for excluding objects that only need to exist in dev and test environments.

It's perfectly valid to do this comparison the other way around, examining objects in the target database - indeed this is what the C# snippet in the original blog post does. This would be useful if there were objects in your target database created by a third party outside of your deployment process that needed to be specifically excluded from consideration.

Having excluded the relevant objects from the comparison results, we go ahead and deploy the changes with `PublishChangesToTarget()`.

``` powershell
~\source\repos\FilteringDemo\FilteringDemo [master ≡]> .\FilteredDeploy.ps1
Excluding Object [UnProduction].[UnimportantStuff]
Excluding Object [UnProduction]
Worky
~\source\repos\FilteringDemo\FilteringDemo [master ≡]>
```

This is a pretty simplistic example, it relies on the fact that both tables and schemas have the schema name in the first element of the `SourceObject.name.Parts[]` collection, but more complex filtering criteria can be implemented with a bit of API speleology.