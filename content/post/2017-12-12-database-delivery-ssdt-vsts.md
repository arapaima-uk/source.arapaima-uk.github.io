+++
title=  'Database Delivery with SSDT and VSTS: a worked example'
date =  "2017-12-12"
tags = ["VSTS", "SSDT"]
draft = true
+++

There have been a few posts similar to this on other sites over the years, but I thought I'd add my own, if only to document how I would approach a new SQL Server project, starting now, in late 2017.

## Project Overview

This article will detail importing an existing database into an SSDT project, creating `MERGE` scripts to manage reference data, adding a new feature - in an associated feature branch - with SSDT, creating and running unit tests with tSQLt, building the database project using VSTS, and deploying to Azure SQL Database as well as an on-premises SQL Server[^1].

### Software Versions

I'm using Visual Studio 2017 Version 15.5.1 on Windows 10 Version 1703. I have a local installation of SQL Server 2017 Developer Edition with Cumulative Update 2 applied. The database used in the example is the WideWorldImporters-Full sample, which can be downloaded from [GitHub](https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0). I've also downloaded tSQLt version 1.0.5873.27393 from the [tSQLt downloads page](http://tsqlt.org/downloads/).


## Importing the database into an SSDT project

I started by restoring the `.bak` file for the sample database to my local instance of SQL Server. This is analogous to how you might start this process on a real project; by restoring a backup of the production database to a development environment you can use for the import.

Next, we need to connect to our database using SQL Server Object Explorer in Visual Studio (View -> SQL Server Object Explorer). If the local SQL Server is not displayed, it can be added by clicking on the "New Server" icon, which is a picture of a server with a green "plus" sign.

Right clicking on the name of our database gives us the option to "Create a New Project".

![Context menu in SSOX](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/database-delivery-ssdt-vsts/createNewProjectFromSsox.PNG)

In the dialog that follows, we need to set a couple of options. The first of these is the Project Name, which I generally set to be the same as the database name. The second is to tick the box "Create directory for solution", which will have the effect of creating a `.sln` file at the top level, followed by a subfolder containing our `.sqlproj` project and associated files.

![Create Project Dialog from SSDT](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/database-delivery-ssdt-vsts/createProjectDialog.PNG)

The Import Database feature will scan all the objects in the database and create a separate file for each one. Under the default options, a new folder will be created for each `schema` with separate sub-folders for each object type.

```
PS C:\Users\arapaima\source\repos> tree /F
Folder PATH listing
Volume serial number is 00000012 320E:0DDE
C:.
└───WideWorldImporters
    │   WideWorldImporters.sln
    │
    └───WideWorldImporters
        │   WideWorldImporters.sqlproj
        │   WideWorldImporters.sqlproj.user
        │
        ├───Application
        │   ├───Functions
        │   │       DetermineCustomerAccess.sql
        │   │
        │   ├───Stored Procedures
        │   │       AddRoleMemberIfNonexistent.sql
        │   │       Configuration_ApplyAuditing.sql
        │   │       Configuration_ApplyColumnstoreIndexing.sql
        │   │       Configuration_ApplyFullTextIndexing.sql
        │   │       Configuration_ApplyPartitioning.sql
        │   │       Configuration_ApplyRowLevelSecurity.sql
        │   │       Configuration_ConfigureForEnterpriseEdition.sql
        │   │       Configuration_EnableInMemory.sql
        │   │       Configuration_RemoveAuditing.sql
        │   │       Configuration_RemoveRowLevelSecurity.sql
        │   │       CreateRoleIfNonexistent.sql
        │   │
        │   └───Tables
        │           Cities.sql
        │           Cities_Archive.sql
        │           Countries.sql
        │           Countries_Archive.sql
        │           DeliveryMethods.sql
        │           DeliveryMethods_Archive.sql
        │           PaymentMethods.sql
        │           PaymentMethods_Archive.sql
        │           People.sql
        │           People_Archive.sql
        │           StateProvinces.sql
        │           StateProvinces_Archive.sql
        │           SystemParameters.sql
        │           TransactionTypes.sql
        │           TransactionTypes_Archive.sql
        │
        ├───bin
        │   └───Debug
        ├───DataLoadSimulation
        │   └───Stored Procedures
        │           Configuration_ApplyDataLoadSimulationProcedures.sql
        │           Configuration_RemoveDataLoadSimulationProcedures.sql
        │           DeactivateTemporalTablesBeforeDataLoad.sql
        │           PopulateDataToCurrentDate.sql
        │           ReactivateTemporalTablesAfterDataLoad.sql
        │
        ├───Import Schema Logs
        │       WideWorldImporters_20171212115128.log
        │
        ├───Integration
        │   └───Stored Procedures
        │           GetCityUpdates.sql
        │           GetCustomerUpdates.sql
        │           GetEmployeeUpdates.sql
        │           GetMovementUpdates.sql
        │           GetOrderUpdates.sql
        │           GetPaymentMethodUpdates.sql
        │           GetPurchaseUpdates.sql
        │           GetSaleUpdates.sql
        │           GetStockHoldingUpdates.sql
        │           GetStockItemUpdates.sql
        │           GetSupplierUpdates.sql
        │           GetTransactionTypeUpdates.sql
        │           GetTransactionUpdates.sql
        │
        ├───obj
        │   └───Debug
        ├───Purchasing
        │   └───Tables
        │           PurchaseOrderLines.sql
        │           PurchaseOrders.sql
        │           SupplierCategories.sql
        │           SupplierCategories_Archive.sql
        │           Suppliers.sql
        │           Suppliers_Archive.sql
        │           SupplierTransactions.sql
        │
        ├───Sales
        │   └───Tables
        │           BuyingGroups.sql
        │           BuyingGroups_Archive.sql
        │           CustomerCategories.sql
        │           CustomerCategories_Archive.sql
        │           Customers.sql
        │           Customers_Archive.sql
        │           CustomerTransactions.sql
        │           InvoiceLines.sql
        │           Invoices.sql
        │           OrderLines.sql
        │           Orders.sql
        │           SpecialDeals.sql
        │
        ├───Security
        │       Application.sql
        │       DataLoadSimulation.sql
        │       External Sales.sql
        │       Far West Sales.sql
        │       FilterCustomersBySalesTerritoryRole.sql
        │       Great Lakes Sales.sql
        │       Integration.sql
        │       Mideast Sales.sql
        │       New England Sales.sql
        │       Plains Sales.sql
        │       PowerBI.sql
        │       Purchasing.sql
        │       Reports.sql
        │       Rocky Mountain Sales.sql
        │       Sales.sql
        │       Sequences.sql
        │       Southeast Sales.sql
        │       Southwest Sales.sql
        │       Warehouse.sql
        │       Website.sql
        │
        ├───Sequences
        │   ├───Sequences
        │   │       BuyingGroupID.sql
        │   │       CityID.sql
        │   │       ColorID.sql
        │   │       CountryID.sql
        │   │       CustomerCategoryID.sql
        │   │       CustomerID.sql
        │   │       DeliveryMethodID.sql
        │   │       InvoiceID.sql
        │   │       InvoiceLineID.sql
        │   │       OrderID.sql
        │   │       OrderLineID.sql
        │   │       PackageTypeID.sql
        │   │       PaymentMethodID.sql
        │   │       PersonID.sql
        │   │       PurchaseOrderID.sql
        │   │       PurchaseOrderLineID.sql
        │   │       SpecialDealID.sql
        │   │       StateProvinceID.sql
        │   │       StockGroupID.sql
        │   │       StockItemID.sql
        │   │       StockItemStockGroupID.sql
        │   │       SupplierCategoryID.sql
        │   │       SupplierID.sql
        │   │       SystemParameterID.sql
        │   │       TransactionID.sql
        │   │       TransactionTypeID.sql
        │   │
        │   └───Stored Procedures
        │           ReseedAllSequences.sql
        │           ReseedSequenceBeyondTableValues.sql
        │
        ├───Storage
        │       PF_TransactionDate.sql
        │       PF_TransactionDateTime.sql
        │       PS_TransactionDate.sql
        │       PS_TransactionDateTime.sql
        │       USERDATA.sql
        │       WWI_InMemory_Data.sql
        │
        ├───Warehouse
        │   └───Tables
        │           ColdRoomTemperatures.sql
        │           ColdRoomTemperatures_Archive.sql
        │           Colors.sql
        │           Colors_Archive.sql
        │           PackageTypes.sql
        │           PackageTypes_Archive.sql
        │           StockGroups.sql
        │           StockGroups_Archive.sql
        │           StockItemHoldings.sql
        │           StockItems.sql
        │           StockItemStockGroups.sql
        │           StockItems_Archive.sql
        │           StockItemTransactions.sql
        │           VehicleTemperatures.sql
        │
        └───Website
            ├───Functions
            │       CalculateCustomerPrice.sql
            │
            ├───Stored Procedures
            │       ActivateWebsiteLogon.sql
            │       ChangePassword.sql
            │       InsertCustomerOrders.sql
            │       InvoiceCustomerOrders.sql
            │       RecordColdRoomTemperatures.sql
            │       RecordVehicleTemperature.sql
            │       SearchForCustomers.sql
            │       SearchForPeople.sql
            │       SearchForStockItems.sql
            │       SearchForStockItemsByTags.sql
            │       SearchForSuppliers.sql
            │
            ├───User Defined Types
            │       OrderIDList.sql
            │       OrderLineList.sql
            │       OrderList.sql
            │       SensorDataList.sql
            │
            └───Views
                    Customers.sql
                    Suppliers.sql
                    VehicleTemperatures.sql

```

By way of explanation, the `.sln` file is a Visual Studio _Solution_ file, which is a container for one or more _Project_ files, which can be of many different types. In this case we have created a `.sqlproj` file, which is the type of project used to develop a SQL Server Database. Other project types include `.csproj` for C# projects, `.vbproj` for Visual Basic projects, `.njsproj` for node.js projects and so on. We will be adding a couple more projects to this solution as the example develops, which is why I elected to create a directory for the solution. 

The project structure can also be viewed in the Solution Explorer window in Visual Studio:

![the newly created database project in Solution Explorer](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/database-delivery-ssdt-vsts/newProjectInSolutionExplorer.PNG)


For those familiar with other build systems, you can think of the project file as being a bit like a `makefile` or a `pom.xml`, but in a format that is understood by [MSBuild](https://docs.microsoft.com/en-us/visualstudio/msbuild/msbuild), the build tool that is "behind the scenes" in Visual Studio.

As we can see, each individual object (table, view, stored procedure, function, etc) has been extracted into its own `.sql` file, stored under the project folder. This particular layout - by schema and object type - is only a matter of convention, it doesn't really matter where the files are as long as the `.sqlproj` knows where to find them.

If we take a look at one of the files, a table for example, we see a `CREATE TABLE` script along with an associated designer.

![The SSDT Table Desginer](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/database-delivery-ssdt-vsts/ssdt-table-designer.png)

This is just a text file with the extension `.sql`, the "Access-style" table designer is just a representation of the contents of the file. This is one of the more difficult points for newcomers to SSDT to grasp - at this point we are no longer connected to a database, we are only working with files on our desktop. This isn't even the file that will be run when we deploy the database project - keen-eyed readers will have observed that this file could only be run _once_ in any case, as it starts with `CREATE TABLE`, which will fail the second time we try to create a table with the same name. More on how what actually happens later. The only object type for which we get this designer is tables, stored procedures - for example -  are just stored as `.sql` files:

![A stored procedure in SSDT](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/database-delivery-ssdt-vsts/stored-procedure-in-ssdt.png)


## Adding our project to source control and creating the initial commit

Having looked briefly at SSDT, we're ready to use the Visual Studio `git` integration to add our project to source control:

![Add a solution to source control from Solution Explorer](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/database-delivery-ssdt-vsts/add-solution-to-source-control.PNG)

At first glance, it appears that menu item doesn't do anything, but in fact it does:

{{< highlight none "hl_lines=12 13">}}
PS C:\Users\arapaima\source\repos\WideWorldImporters> gci -force


    Directory: C:\Users\arapaima\source\repos\WideWorldImporters


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
d--h--       12/20/2017  11:20 PM                .git
d--h--       12/13/2017  12:02 AM                .vs
d-----       12/20/2017  10:40 PM                WideWorldImporters
-a----       12/20/2017  11:17 PM           2581 .gitattributes
-a----       12/20/2017  11:17 PM           4565 .gitignore
-a----       12/13/2017  12:13 AM           1320 WideWorldImporters.sln

{{< / highlight >}}



## Adding a new stored procedure in Visual Studio


## Extracting Reference Data into `MERGE` scripts



[^1]: Er, well, not really on-premises, as I don't have any premises, I'm typing this in a hotel room on a laptop running Linux. In a VM, really, but you get the idea.

