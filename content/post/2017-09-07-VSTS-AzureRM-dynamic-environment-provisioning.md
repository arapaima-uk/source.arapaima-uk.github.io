+++
title=  'Automatically provisioning a brand new environment for every feature branch using VSTS and AzureRM'
date =  "2017-09-07"
tags = ["VSTS", "Azure", "AzureRM"]
draft = false
+++

It's fairly uncontentious to suggest that, all else being equal, providing each developer with an individual "sandbox", or private development environment, is a [worthwhile endeavour](http://www.agiledata.org/essays/sandboxes.html).

Often, these can be provisioned on the developers individual desktops, but when the application involves PaaS services such as databases, message queues, and other cloud-based services, things become more complicated. It's generally possible to emulate _most_ things on the desktop, but there are often small gaps in this emulation, not least in the communication and authentication protocols that link the services together.

The rest of this article will discuss how to use [Visual Studio Team Services](https://www.visualstudio.com/team-services/) in conjunction with [Azure Resource Manger](https://azure.microsoft.com/en-gb/features/resource-manager/) (henceforward AzureRM) templates to automatically provision a new environment for every branch created in source control, and automatically destroy the environment using a service hook to [Azure Automation](https://azure.microsoft.com/en-gb/services/automation/) when the branch is merged to master and deleted.

I stumbled on this technique whilst working on a proof of concept involving the data-related Azure services, such as Data Factory, Data Lake, and Azure SQL Data Warehouse, but the present example consists of a serverless [Azure Function](https://azure.microsoft.com/en-gb/services/functions/) that writes to a [Cosmos DB](https://azure.microsoft.com/en-gb/services/cosmos-db/) PaaS Database. 

This technique should generalise to most Azure PaaS services, and yes, I'm sure you can do similar things with AWS and friends but I haven't had cause to think about them for the time being.

### The application code

The project I'm using for this example can be downloaded from [this Github repo](https://github.com/arapaima-uk/KebabAzureRmDemo). The Github version of the code is mirrored from the version in VSTS using the [Git Tasks](https://marketplace.visualstudio.com/items?itemName=nkdagility.gittasks) extension for VSTS


The repo contains a Visual Studio (2017) solution with four projects:

* FavouriteKebab - this is the Azure Function App
* KebabDbResourceGroup - this is the AzureRM template that defines our infrastructure
* KebabTests - contains a single test written with the MSTest framework
* HelperScripts - a Powershell Script project containing a single script used in the build pipeline

![Solution Explorer View](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/solutionexplorerview.PNG)

### The next Instagram?
The details of what the app actually _does_ aren't particularly important for this example, but in brief it is expecting a JSON structure:

``` json
{
"name": "Bill",
"favouriteKebab":"Adana"
}
```

in the body of a `POST` message, which it will then store in the Cosmos DB database.

``` csharp

[FunctionName("KebabPost")]
public static HttpResponseMessage Run(
[HttpTrigger(AuthorizationLevel.Anonymous, "post")]
HttpRequestMessage req,
[DocumentDB("kebabDb", "kebabPreferences",
ConnectionStringSetting = "DB_CONNECTION", CreateIfNotExists =true)] out dynamic nameAndKebabType, 
    TraceWriter log)
{

    log.Info("C# HTTP trigger function processed a request.");

    // Get request body
    dynamic data = req.Content.ReadAsAsync<object>().Result;

    // Set name to query string or body data
    nameAndKebabType = new {
    name = data?.name,
    favouriteKebab = data?.favouriteKebab
};
    if (data?.name == null || data?.favouriteKebab == null)
    {
        return req.CreateResponse(HttpStatusCode.BadRequest, 
            "Name and kebab are both required!");
    }

    else
    {
        return req.CreateResponse(HttpStatusCode.OK);
    }
}
```        
The name of the DocumentDB database and collection will be the same in every environment, so I've just hardcoded them in the file (`"kebabDB"` and `"kebabPreferences"`). The other thing to note is that I am passing `CreateIfNotExists=true` in the binding options for the DocumentDB collection; it turns out to be non-trivial to create the database and the collection from an AzureRM template, so we let the app create them at runtime if required.

The test project contains a single test, which exercises the behaviour described above:
```csharp
[TestMethod]
public void KebabPost_ValidInput_StoresValuesInDb()
{
string content = "{ 'name':'Barry' , 'favouriteKebab':'Kofte' }";

using (var client = new HttpClient())
{
    var response = client.PostAsync(functionUrl,
        new StringContent(content, Encoding.UTF8, "application/json")).Result;
    
}

using (var client = new DocumentClient(docDbUri, docDbKey))
{
    IQueryable<KebabPrefs> kebabPrefsQuery = client
    .CreateDocumentQuery<KebabPrefs>(
        UriFactory
        .CreateDocumentCollectionUri("kebabDb", "kebabPreferences"))
        .Where(kp => kp.name == "Barry");

    Assert.AreEqual("Kofte", kebabPrefsQuery.ToList()
        .First().favouriteKebab);


    }
```

Unit Testing enthusiasts will have noticed that this isn't really a Unit Test at all; there are no fakes or mocks, we are using the "real" dependencies for everything. 

If our Azure function were a bit bigger, it would be worth splitting out the "core" functionality into a separate assembly that _could_ be meaningfully unit tested, but in the interests of brevity I've not done that here.

_Integration_ tests of this kind are pretty common in PaaS projects, and a glance at the [full source code of the test project ](https://github.com/arapaima-uk/KebabAzureRmDemo/blob/master/KebabTests/KebabTests.cs) will reveal many of the common "characteristics" of coded integration tests; acres of boilerplate code to read config files and set up the initial conditions, POCOs not present in the main application whose only purpose is to hold data for our test, etc. etc. Still, all of this fragility and maintenance difficulty is probably a price worth paying for increased confidence in our deployment pipeline.

## The AzureRM Template

The [full template](https://github.com/arapaima-uk/KebabAzureRmDemo/blob/master/KebabDbResourceGroup/azuredeploy.json) is a bit too long to reproduce here, so I'll call out some edited highlights. 

``` json

  "parameters": {
    "database_account_name": {
      "defaultValue": "[concat('kebabdac', uniqueString(resourceGroup().id))]",
      "type": "string"
    },
    "hostingPlanName": {
      "defaultValue": "[concat('kebabhp', uniqueString(resourceGroup().id))]" ,
      "type": "string"
    },
    "functionAppName": {
      "defaultValue": "[concat('kebabApp', uniqueString(resourceGroup().id))]",
      "type": "string"
    },
    "storageAccountName": {
      "defaultValue": "[concat('kebabstor', uniqueString(resourceGroup().id))]",
      "type": "string"
    }
  }

  ```
  The thing to note is that the template takes four parameters, each of which has a default value.

  Each of the defaults consists of a prefix that identifies the resource type, combined with the result of the function `uniqueString(resourceGroup().id)`. These unique strings are required as there are some objects in Azure (storage accounts or web apps for example) that require _globally_ unique names that can be incorporated into a url of the form `https://myapp.azurewebsites.net` or similar. I can never remember which objects do require unique names and which ones don't, so I tend to use `uniqueString()` for everything. 
  
  The template goes on to create a storage account, a Cosmos DB account, a Function App, and all the supporting bits these require. These end up with some pretty funky names thanks to the use of `uniqueString()`, but since you never really need to type these names anywhere this is more of an aesthetic consideration than a practical problem:

  ![Azure resource names generated with uniqueString](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/resources.png)

  At the end of the template is an `outputs` section:

``` json
  "outputs": {
    "functionAppName": {
      "type": "string",
      "value": "[parameters('functionAppName')]"

    },
    "docDbUri": {
      "type": "string",
      "value": "[Concat('https://',parameters('database_account_name'),'.documents.azure.com:443')]"
    },
    "docDbKey": {
      "type": "string",
      "value": "[listKeys(resourceId('Microsoft.DocumentDb/databaseAccounts', parameters('database_account_name')), '2015-04-08').primaryMasterKey]"
    }
  }
```
This defines three outputs, the Function App name, the Cosmos DB uri, and the Cosmos DB key. This is necessary as we didn't specify these values ourselves, so we need AzureRM to _tell us what it just created_ in order that we can use these names for other tasks in our build process.

### The Build Definition

![The Build Steps in VSTS](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/builddefinition.png)

This is a fairly standard workflow, with a couple of things of note. We build the solution at the beginning and save the artifacts, but before we run our integration test(s?), we run the AzureRM template to "Create or Update" a resource group, and then deploy our Function App inside this resource group. This is so that we can run our integration tests with the real dependencies. The "trick", such as it is, is in the AzureRM deployment step:

![AzureRM Deploy step showing parameters](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/AzureRMStep.png).

By passing the _name of the branch we are building_ as the name of the resource group, this means that the first time we build any given branch we will get a brand new environment with a Cosmos DB, a Function App, etc. etc., exclusively for that build. 

After the template is deployed, we need a bit of Powershell to retrieve the outputs from the template.

``` powershell

param ([string]$resourceGroup)

$outputs = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroup | Sort Timestamp -Descending | Select -First 1).Outputs

$outputs.Keys | % { Write-Host ("##vso[task.setvariable variable="+$_+";]"+$outputs[$_].Value) }

```
What this does is to find the most recent deployment for the specified resource group - i.e. the one we just did - and map the _outputs_ of the template to _build variables_ in VSTS by name. This means that for every output in the template, we need to define a build variable with _exactly_ the same name, which indeed we have done:

![Build variables view](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/buildvars.png)

The values are all empty, as they will be assigned by the above script during each build.

We can then use these variables in the Function App deployment step to tell it where to deploy our Function:

![FunctionAppDeployment](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/appServiceDeploy.png)

as well as in the Integration Testing step, where we use these variables to overwrite the values in the `runsettings` file used by the `vstest` test runner.

![runsettings](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/runsettings.png)

The final step is just to update the Github mirror of the VSTS repo; in most corporate environments this won't be necessary!

### The Build Trigger

![https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/buildtrigger.png](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/buildtrigger.png)

This build will be run for every new commit on every branch. A moment's reflection will reveal that if the branch is created through the UI on the server, the build will be triggered immediately, as there will be a new branch with a new (to that branch) commit. The first build will always be the slowest, as this is the one that will create the resource group from scratch.

Equally, a new build will be triggered every time the developer pushes new commits to the feature branch, following which the artifacts will be deployed and the integration tests run, _in the private environment dedicated to that branch_. 

Subsequent builds will be faster; the time penalty associated with creating the resource group from scratch is around two minutes in this particular case, using the hosted queue (2:32 to create from scratch, 0:38 to revalidate on subsequent builds). The overall build time is around 5 minutes the first time, and 3 minutes on subsequent runs. (since there's only one integration test, the slowest part is the nuget restore!).

### Branch Policy

In addition to enforcing a build on every commit, we can force another build at the point a pull request is made from our feature branch to master:

![Master branch policy in vsts](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/masterbranchpolicy.png)

This will "pre-merge" our feature branch into master, and trigger a new build. This will have the side effect of creating a new resource group called "merge", in which the tests will be run again. However, since the same branch name is used for every pull-request build, the "merge" resource group will only be created once, and won't be modified unless the AzureRM template changes.

### Merging a Pull Request

![Merging a PR](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/closingapr.png)

This screenshot shows the "moment of truth" immediately prior to merging a pull request. The "pre-merged" branch has been built successfully, and when we click "Complete Merge" the source branch will be deleted. The resource group, however, will still be hanging around incurring charges, and this could become an expensive business if we are creating a new environment for every single feature and never tearing them down.

### Tearing down the environment

This is achieved by calling an Azure Automation runbook in a Service Hook from VSTS. 

To create the hook, we first need to define our Automation runbook and give it a web endpoint. The integration of Azure Automation and source control is a "work in progress", so I've stored the body of the runbook in a gist

{{<gist gavincampbell a12a87477bd38402b310262040509a56>}}.

This script will parse the JSON payload from VSTS, find the source branch name (from the refspec), and delete the resource group with that name. This runbook is associated with an endpoint url, which we provide to VSTS in the Web hook configuration.

The runbook requires an Azure Automation Account.  I have created these in a separate resource group, not "managed" from VSTS. 

We set the event to track to "Pull request merge commit created" - there's no "branch deleted" event available here. Remember, the branch gets deleted when the PR is merged, assuming the box is ticked. Notably, we are only firing this event on merges *to* master.

![Service Hook p1](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/servicehookp1.png)

On the second page of the dialog, we just supply the endpoint url for our Automation runbook. 

![Service Hook p2](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/servicehookp2.png)


## Release Management

Once the branch is merged to master and its environment torn down, then what? We release the feature, of course:

![Release Management in VSTS](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/releaseprocess.png)

This Release definition is triggered on every new build of the master branch. Since the branch is protected by a policy, these will only occur when a pull request has been created, successfully built, reviewed, and merged. 

![Release Trigger](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/releasetrigger.png)

As soon as the release is triggered, we do a deployment to QA. The "little man with a clock" next to the "Production" environment indicated that there is a manual approval required before a release can be deployed to production.

![QA trigger](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/qatrigger.png)

### The deployment process

As is typical, the Release Definition is much simpler than the Build Definition. In this instance it consists of only two steps, deploying the Azure RM template and deploying the Function to our Function App.

![Release tasks in VSTS](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/deploymenttasks.png)

What's notable though, is that we are using the same Azure RM template for QA and Production as we used for the ephemeral development environments. The only difference is that instead of allowing the parameters to default to their "unique string" values, we explicitly set all these parameters to "well known" values in the step definition:

![Azure RM Release Step Definition](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/overridetemplateparameters.png)

as well as in the step that deploys the function to our function app:

![Azure Function Release Step Definition](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/overrideAppServicename.png)

The Production environment definition is exactly the same as the QA one, except that the "well known" values for the resource names are different.

This means that it doesn't matter if the QA and Prod environments are maintained by a different team, or if they are created in a different subscription or in a different tenant; as long as we know the values to plug into our template, we can override our defaults with the "permanent" names. 

The "permanent" resource names still need to respect the rules for uniqueness though, so if these names are important it is probably wise to create these resources in advance to avoid disappointment at deployment time.

## Summary

If you're still reading, you'll be aware that this has been a somewhat "epic" article. The scenario outlined above allows us to automatically create and tear down a new environment for every single feature. Under normal circumstances, there will be four "persistent" resource groups, namely "QA" and "Production", as well as "merge" - used for building and testing "pre-merged" pull requests, and "master" - used to rebuild and retest "master" after every merge commit. 

The extra resource group for Azure Automation is also visible in this screenshot, as is the resource group for a feature branch, which will be automatically torn down when the branch is merged.

![resource groups in the Azure Portal](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/vsts-azurerm/ResourceGroups.png)

All of the above is still a work in progress, if there are any glaring errors or omissions please do get in touch via the comments or via the [contact form]({{< relref "fixed/About.md">}}) on the site.