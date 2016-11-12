+++
title=  "Database Pruning"
date =  "2016-10-25"
tags = ["Refactoring", "SSDT"]
series = ["Refactoring Databases with SSDT"]
draft = false
+++

After a period of time in use, most databases, like many systems that have grown in an organic matter, can benefit from some judicious pruning. This can take the form of removing columns or even tables no longer required to support the application, or that store redundant - and hence possibly erroneous - copies of information stored elsewhere. Equally there may be stored procedures, functions, and even triggers that contain out-of-date versions of application logic.

 ![The gardener's assistant; a practical and scientific exposition of the art of gardening in all its branches (1910) (14761716416).jpg](https://upload.wikimedia.org/wikipedia/commons/7/70/The_gardener%27s_assistant%3B_a_practical_and_scientific_exposition_of_the_art_of_gardening_in_all_its_branches_%281910%29_%2814761716416%29.jpg "[By Internet Archive Book Images [No restrictions], via Wikimedia Commons]")

## Dropping a column
> Refactoring Databases, p 72

Since SSDT operates in a declarative manner, each table is defined in a `CREATE TABLE` script, and deleting a column is as simple as deleting the relevant line from the script. However, there are a couple of features of SSDT that are relevant here. If the column is referenced by any other database objects such as views, functions, or stored procedures, SSDT will display an error:

![SSDT Broken Reference Error](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/ssdt-refactoring-part-1/DropColumnReferencedByProcedure.PNG "SSDT Broken Reference Error")

The full text of the error message reads `SQL71501: Procedure [dbo.UpdateInvoiceBillingAddress] has an unresolved reference to object [dbo].[Invoice].[BillingPostalCode]`, and the offending reference in the stored procedure[^1] has acquired a "red squiggly". There's no "builtin" refactoring action defined in the right-click context menu for deletions, presumably as it's difficult to programmatically determine the "intent" of a deleting a column.


![Refactoring Context Menu](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/ssdt-refactoring-part-1/Refactoring+Menu.PNG "Refactoring Context Menu")

What is possible, however, is to use the "find all references" tool _before_ deleting the column to enable us to take appropriate action.

![Find All References](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/ssdt-refactoring-part-1/findAllReferences.PNG "Find All References") 

## Dropping a table
> Refactoring Databases, p 77

This is where things get more serious. The same technique of using the "Find All References" tool to assess the damage we're about to do applies here, but there is a subtle difference in what happens when we actually brandish the pruning shears. It turns out that removing an entire table referenced by a stored procedure is only worthy of a warning or five rather than an error. This is due to an oddity of [deferred name resolution](https://technet.microsoft.com/en-us/library/ms190686.aspx) for stored procedures, namely that it is permitted to reference a non-existent table in the text of a stored procedure, but not permitted to reference a non-existent column in a table that _does_ exist.

![Removing a table is only a warning](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/ssdt-refactoring-part-1/RemovingATableIsOnlyAWarning.PNG "Removing a table is only a warning")

Interestingly, if we convert our stored procedure to a user-defined function [^2] the warnings turn into errors. It turns out deferred name resolution doesn't work at all for functions, presumably as being "purely functional" and not side-effecting it is less likely that there will be objects that exist at runtime but not at creation time.

![Functions don't support deferred name resolution](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/ssdt-refactoring-part-1/FunctionsDontSupportDeferredNameResolution.PNG  "Functions don't support deferred name resolution")



## Dropping Programmable Objects (Views, Functions, Stored Procedures, other miscellany in [`sys.sql_modules`](https://msdn.microsoft.com/en-us/library/ms175081.aspx))
>Refactoring Databases, p 79

On the face of it this is simpler, as there is no data being thrown out with the bathwater.

### Dropping Triggers
You should do this without hesitation. It's 2016.

### Dropping views and functions

Generally, this is unproblematic. Since these don't support deferred name resolution, you can get error checking in SSDT.

![Name checking in views](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/ssdt-refactoring-part-1/NameCheckingInViews.PNG "Name checking in views")

## Pulling the trigger[^3]

There's one more thing to consider, which is what happens when we come to deploy our changes. Whether we do this by publishing from Visual Studio or at the command line using `sqlpackage.exe`, if we are dropping a table or a column that contains data we will get an error along the lines of

``` 
(48,1): SQL72014: .Net SqlClient Data Provider: Msg 50000, Level 16, State 127, Line 6 Rows were detected. The schema update is terminating because data loss might occur.
(43,0): SQL72045: Script execution error.  The executed script:
IF EXISTS (SELECT TOP 1 1
           FROM   [dbo].[PlaylistTrack])
    RAISERROR (N'Rows were detected. The schema update is terminating because data loss might occur.', 16, 127)
        WITH NOWAIT;
```

The `IF EXISTS` check gets inserted into the deployment script for every table, and every table containing a column, that is being dropped. It is worth noting that since the check is for `EXISTS (SELECT TOP 1 1)`, this check will fail and the deployment will be blocked even if we are dropping a column that only contains `NULL` values - I have found this to be mildly irritating in the past, particularly for "inadvertently" created columns.

To inhibit this behaviour and allow our potentially destructive change to proceed, we need to specify this at deploy time, the mechanism for which depends on the method we are using to deploy our project.

* For projects deployed using the Visual Studio "Publish" dialog, uncheck "Block Incremental Deployment if Data Loss might Occur" in the "Advanced Publish Settings" dialog available by clicking "Advanced" in the "Publish" dialog.

* For projects deployed using `sqlpackage.exe`, we need to specify the parameter `/p:BlockOnPossibleDataLoss=False`

* For projects that use a publish profile to specify deployment options, we need to add the element `<BlockOnPossibleDataLoss>False</BlockOnPossibleDataLoss>` to the `.publish.xml` file.

In each case, the default is "true", meaning potentially destructive changes are blocked by default. This is for the benefit of those "enterprise" customers that deploy direct to production with no testing - remember that these people aren't our problem but they are the SSDT development team's problem, since they are paying to keep the lights on at SSDT HQ!

In general, this should always be set to false, meaning "allow potentially destructive changes". This is unproblematic as long as production isn't the _first_ environment where you deploy your changes.

Similarly, the default behaviour of SSDT is _not_ to drop objects that are in the target (i.e. the database) but not in the source (i.e. the database project). To allow these changes to be applied, we need to do one of the following.

* For projects deployed using the Visual Studio "Publish" dialog, check "Drop objects in target but not in source" in the "Advanced Publish Settings" dialog available by clicking "Advanced" in the "Publish" dialog.

* For projects deployed using `sqlpackage.exe`, we need to specify the parameter `/p:DropObjectsNotInSource=True`

* For projects that use a publish profile to specify deployment options, we need to add the element ` <DropObjectsNotInSource>True</DropObjectsNotInSource>` to the `.publish.xml` file.

### A note on "Drop objects not in source"

If this option is selected, SSDT will drop _all_ objects from the target database that are not defined in the project. Rather inconveniently, this includes users, permissions - including, cruciallly, the `CONNECT` permission - and all the other things we need to be present for our application (or us!) to be able to connect to the database. Rather than specify all these items as part of the project, it is often simpler to ignore these at deployment time using the publish profile. The most important ones are probably users, permissions, roles, and role memberships, but anyone with a more obscure security model (Application Roles??) might want to investigate some of the other options.

![Advanced Publish Settings showing drop objects](http://aksidjenakfjg.s3.amazonaws.com/ssdt-refactoring-part-1/Options-for-drop-objects.PNG "Advanced Publish Settings showing drop objects")

The difference between the "Drop" and "Ignore" settings is that the former apply _only_ to the target - so selecting object types here prevents objects of that type from being dropped. The "ignore" settings allow us to specify that objects of the selected types are not dropped in the target if they are absent from the source, but also not created or modified in the target even if they are present in the source.

As above, these settings can also be specified as command-line arguments to `sqlpackage.exe` or as xml in a publish profile.






[^1]: This procedure isn't in the original Chinook database, I added it for the purpose of this example.
[^2]: which it should have been in the first place, as it doesn't modify any data!
[^3]: No, not that kind of trigger, this refers to the metaphorical kind.