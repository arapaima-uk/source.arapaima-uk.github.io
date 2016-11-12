+++
title=  "What's in a name?"
date =  "2016-11-12"
tags = ["Refactoring", "SSDT"]
series = ["Refactoring Databases with SSDT"]
draft = false
+++

Continuing our horticultural theme, in this article we'll look at the built-in support in SSDT for renaming database objects including tables, columns, and programmable objects, as well as peering into the details of how these changes are managed at deployment time.

![That which we call a rose. By any other name would smell as sweet](https://upload.wikimedia.org/wikipedia/commons/6/66/Rosa_laxa.jpg "That which we call a rose. By any other name would smell as sweet")

## Renaming columns
>Refactoring Databases, p 109

### The easy way

We can rename a column just by right-clicking in the `CREATE TABLE` script and selecting Refactor &rarr; Rename. 

![Renaming the InvoiceId Column by right-clicking in the editor window](http://aksidjenakfjg.s3.amazonaws.com/ssdt-refactoring-part-2/RefactorRenameSelected.PNG "Renaming the InvoiceId Column by right-clicking in the editor window" )

Under normal circumstances, renaming the Primary Key column of a table such as "Invoices" would be a recipe for disaster, but SSDT can help to ease such changes by automatically updating all references to the column to use the new name. In this case we are renaming the column InvoiceId to Invoice_Id, and by specifying the option to preview the changes, we can see a list of all the objects that reference this column by its old name. 

![SSDT shows a preview of which objects will be updated to refer to the new name](http://aksidjenakfjg.s3.amazonaws.com/ssdt-refactoring-part-2/rename%20column%20preview.PNG "SSDT shows a preview of which objects will be updated to refer to the new name")


There's something of note here, which is that _only_ the InvoiceId column from the Invoices table is being renamed, any other columns called InvoiceId (such as the one in the InvoiceLine table) are unaffected. The foreign key constraint on that particular column, however, _is_ updated to use the new name of the referenced column.

What this demonstrates is that there is something more than global search and replace going on here; SSDT is using its in-memory model of the database to determine which changes need to be made[^1].

### The refactorlog

When we click apply, two things happen. The first is that all the references to this column are updated to use the new name. The second is that a new file appears in the solution, with the extension `.refactorlog`.
``` xml
<?xml version="1.0" encoding="utf-8"?>
<Operations Version="1.0" xmlns="http://schemas.microsoft.com/sqlserver/dac/Serialization/2012/02">
  <Operation Name="Rename Refactor" Key="209f3afd-7195-401f-853f-aa3a906d39db" ChangeDateTime="11/08/2016 20:02:31">
  <Property Name="ElementName" Value="[dbo].[Invoice].[InvoiceId]" />
  <Property Name="ElementType" Value="SqlSimpleColumn" />
  <Property Name="ParentElementName" Value="[dbo].[Invoice]" />
  <Property Name="ParentElementType" Value="SqlTable" />
  <Property Name="NewName" Value="[Invoice_Id]" />
  </Operation>
</Operations>
```
This file is how `sqlpackage.exe` (or SSDT publish, or DacFX.Deploy) will detemine _at deploy time_ that we are renaming this column from InvoiceID to Invoice_Id rather than dropping the InvoiceID column and creating a new column called Invoice_ID. We can see in the XML that this is specifying the column and table name, and the precise action to perform. This is known, in the jargon, as "preserving the intent" of the refactoring. If we build a project containing a `.refactorlog` file and examine the resulting `.dacpac`, we can see that the regular `.dacpac` contents have been joined by a `refactor.xml` file. 

``` bat
$ unzip -l Refactoring.Chinook.dacpac
Archive:  Refactoring.Chinook.dacpac
  Length      Date    Time    Name
---------  ---------- -----   ----
    69711  2016-11-10 05:44   model.xml
      606  2016-11-10 05:44   refactor.xml
      203  2016-11-10 05:44   DacMetadata.xml
     1118  2016-11-10 05:44   Origin.xml
      175  2016-11-10 05:44   [Content_Types].xml
---------                     -------
    71813                     5 files
```
The contents of this file are the same as the `.refactorlog` file from our solution.

When we publish the project we see the following output:
``` bat
The following operation was generated from a refactoring log file 209f3afd-7195-401f-853f-aa3a906d39db
Rename [dbo].[Invoice].[InvoiceId] to Invoice_Id
Caution: Changing any part of an object name could break scripts and stored procedures.

Altering [dbo].[InvoicesWithLineTotals]...
Altering [dbo].[UpdateInvoiceBillingAddress]...
Update complete.
```
The publish action has read the `refactorlog` file and taken the appropriate action. In addition, the "key" for this refactoring has been stored in a new table in our database called `dbo._RefactorLog`, which gets created the first time we deploy a dacpac containing a `refactor.xml` file:
``` sql
-- Refactoring step to update target server with deployed transaction logs
IF NOT EXISTS (SELECT OperationKey FROM [dbo].[__RefactorLog] WHERE OperationKey = '209f3afd-7195-401f-853f-aa3a906d39db')
INSERT INTO [dbo].[__RefactorLog] (OperationKey) values ('209f3afd-7195-401f-853f-aa3a906d39db')
```
On subsequent deployments, this table is read and any refactorings recorded here are skipped from the deployment.

### Appearances can be deceptive

There's another UI wrinkle here which is worth examining, so we will rename another column, this time using the table designer.

Another entry has been added to the `refactorlog` file, and it appears as if the references to this column elsewhere in the model have been updated (note the red tick showing that `PlaylistTrack.sql` and `InvoiceLine.sql` have been modified.)
![Renaming a column using the table designer](http://aksidjenakfjg.s3.amazonaws.com/ssdt-refactoring-part-2/Renaming%20a%20Column%20in%20the%20table%20designer.PNG "Renaming a column using the table designer")
However, when we go to build the project, we get an error:
```
SQL71501: Procedure: [dbo].[ChangeTrackPriceByFactor] has an unresolved reference to object [dbo].[Track].[TrackId].	
```
(Alternatively, the error will appear in the SSDT UI as soon as the Intellisense catches up). There was a stored procedure referencing this column by name, which is now causing the build to fail (remember that [deferred name resolution works for table names but not for column names]({{< relref "post/2016-10-25-database-refactoring-ssdt-dropping-objects.md#dropping-a-table" >}}).

This is because of a detail of how foreign keys - and primary keys, for that matter - are maintained by SQL Server itself. If we look at the contents of `sys.foreign_key_columns`, there isn't a column name in sight (`sys.index_columns` looks much the same):

|constraint_ object_id|constraint_ column_id|parent_ object_id|parent_ column_id|referenced_ object_id|referenced_ column_id|
|---|---|---|---|---|---|
|1045578763|1|885578193|3|565577053|1|
|917578307|1|565577053|3|597577167|1|
|965578478|1|725577623|2|629577281|1|
|933578364|1|629577281|13|661577395|1|
|...|...|...|...|...|...|


If we fix the reference in our stored procedure and go on to generate a publish script, all we see for this change is 
```sql
PRINT N'The following operation was generated from a refactoring log file 8a905288-76de-4cc4-aad9-c6dddf081a17';

PRINT N'Rename [dbo].[Track].[TrackId] to Track_Id';


GO
EXECUTE sp_rename @objname = N'[dbo].[Track].[TrackId]', @newname = N'Track_Id', @objtype = N'COLUMN';


GO
PRINT N'Altering [dbo].[ChangeTrackPriceByFactor]...';


GO
ALTER PROCEDURE [dbo].[ChangeTrackPriceByFactor]
	@TrackID int,
	@Factor NUMERIC(10, 2)
AS
	UPDATE Track SET UnitPrice *= @Factor WHERE Track_Id = @TrackID;

RETURN 0
GO
-- Refactoring step to update target server with deployed transaction logs
IF NOT EXISTS (SELECT OperationKey FROM [dbo].[__RefactorLog] WHERE OperationKey = '8a905288-76de-4cc4-aad9-c6dddf081a17')
INSERT INTO [dbo].[__RefactorLog] (OperationKey) values ('8a905288-76de-4cc4-aad9-c6dddf081a17')

GO
```

The `refactorlog` is updated to include this change, but there are no changes deployed to any of the tables that referenced the `TrackId` column via foreign keys. This is because foreign keys - as noted above - don't _really_ use column names, they use object and column ids, so it is sufficient to rename the referenced column with `sp_rename`. Stored Procedures, triggers, and other programmable objects, however, *do* reference columns and tables by name - in `sys.sql_modules` - so these references aren't updated automatically.

However, SSDT itself takes into consideration that when we rename a column referenced by a foreign (or primary) key, the definition required to create the constraint from scratch will need to be updated, which is why the files containing the referencing tables are all updated.

This behaviour may seem inconsistent, but it is in fact consistent with the [behaviour of `sp_rename` itself](https://msdn.microsoft.com/en-gb/library/ms188351.aspx#Anchor_3 "MSDN documentation for sp_rename"), which is to say that constraints and indexes aren't broken by `sp_rename`, but stored procedures, triggers, etc. are.

### The wrong way

In contrast, renaming a column by editing the Transact-SQL file directly delivers the promised disaster, as SSDT will attempt to drop the column with the old name and create a new column with the new name.

In the best-case scenario we get a validation error that stops the project from building, assuming the renamed column is referenced by some other object in the project.

![Renaming a column by editing the .sql file](
http://aksidjenakfjg.s3.amazonaws.com/ssdt-refactoring-part-2/renaming%20a%20key%20column%20in%20the%20sql%20file.PNG "Renaming a column by editing the .sql file]")

In all other scenarios, the script executed at deploy time is as follows:
``` sql
PRINT N'Altering [dbo].[Genre]...';

GO
ALTER TABLE [dbo].[Genre] DROP COLUMN [Name];

GO
ALTER TABLE [dbo].[Genre]
    ADD [GenreName] NVARCHAR (120) NULL;
```

The only safety net left at this point is the [BlockOnPossibleDataLoss]({{< relref "post/2016-10-25-database-refactoring-ssdt-dropping-objects.md#pulling-the-trigger-3" >}}) deploy-time option, which is enabled by default. This will stop the deployment from proceeding.
```
Msg 50000, Level 16, State 127, Line 48
Rows were detected. The schema update is terminating because data loss might occur.
** An error was encountered during execution of batch. Exiting.
```



## Renaming tables
>Refactoring Databases, p 113

There are two options in the refactoring context menu that are relevant to naming tables; "Rename" and "Move to Schema". In some RDBMSs, notably [Oracle](https://docs.oracle.com/database/122/CNCPT/tables-and-table-clusters.htm#GUID-72E247B5-F39A-47F1-9445-72D9221F57E3 "Introduction to schema objects, Oracle 12.2"), the notion of a schema is tightly coupled to the notion of a user, such that the user account in question "owns" the tables and other objects contained therein. SQL Server implemented a similar concept prior to SQL Server 2005, when the [link between users and schemas was severed](https://technet.microsoft.com/en-us/library/dd283095.aspx "SQL Server Best Practices – Implementation of Database Object Schemas") such that a schema became more like a namespace, or even a filesystem folder, since a schema remains a securable object. Under either analogy - namespace or folder - the name of the schema can be considered to be a part of the (qualified) name of the table, meaning that moving an object to a new schema is merely a special case of renaming.

### The right way
![Right-click refactor menu for a table](http://aksidjenakfjg.s3.amazonaws.com/ssdt-refactoring-part-2/refactoring-menu.PNG "Right-click Refactor menu for a table")

When we rename a table, we get the usual "refactor preview" showing the changes about to be applied to the project:

![Refactor preview for renaming a table](http://aksidjenakfjg.s3.amazonaws.com/ssdt-refactoring-part-2/Refactor%20renaming%20a%20table.PNG "Refactor preview for renaming a table")

On clicking apply, the relevant objects are updated and a new entry is inserted into the `refactorlog` file:
```xml
<Operation Name="Rename Refactor" Key="cce28c30-adb0-4019-876e-d93cc2ca0011" ChangeDateTime="11/12/2016 14:22:18">
   <Property Name="ElementName" Value="[dbo].[Artist]" />
   <Property Name="ElementType" Value="SqlTable" />
   <Property Name="ParentElementName" Value="[dbo]" />
   <Property Name="ParentElementType" Value="SqlSchema" />
   <Property Name="NewName" Value="[Artiste]" />
 </Operation>
  ```
The process for moving a table between schemas is similar, we are presented with a preview of the changes about to be made:

![Refactor preview for move to schema](http://aksidjenakfjg.s3.amazonaws.com/ssdt-refactoring-part-2/move%20to%20schema%20preview.PNG "Refactor preview for move to schema")

and a new entry is made in the `refactorlog` file.

```xml
<Operation Name="Move Schema"Key="985e03c6-37f8-48c8-8ce8-5ed37fbb7c00"ChangeDateTime="11/12/2016 14:46:31">
  <Property Name="ElementName" Value="[dbo].[Invoice]" />
  <Property Name="ElementType" Value="SqlTable" />
  <Property Name="NewSchema" Value="Sales" />
  <Property Name="IsNewSchemaExternal" Value="False" />
</Operation>
  ```
Finally, when we come to deploy our change, the table is moved to the new schema and all the referencing objects are updated:

```
PRINT N'The following operation was generated from a refactoring log file 985e03c6-37f8-48c8-8ce8-5ed37fbb7c00';

PRINT N'Move object [dbo].[Invoice] to different schema [Sales]';

GO
ALTER SCHEMA [Sales] TRANSFER [dbo].[Invoice];

GO
ALTER VIEW [dbo].[InvoicesWithLineTotals] 
	AS SELECT I.[Invoice_Id],
	InvoiceTotal
	FROM [Sales].Invoice AS I CROSS APPLY dbo.CalculateInvoiceTotal(I.[Invoice_Id]);
GO
```

### The wrong way

As with columns, if we rename a table by editing the `.sql` file directly, we get a potentially undesirable outcome, namely that a new table will created with the new name, possibly at the expense of the current table. If we are lucky we get a validation error that stops the project from building:

![Error from renaming a table in the sql file](http://aksidjenakfjg.s3.amazonaws.com/ssdt-refactoring-part-2/rename%20validation%20error.PNG "error from renaming a table in the .sql file")

If we are less lucky we may get some warnings (remember that deferred name resolution means that a missing table is only a warning rather than an error in a stored procedure), but at deploy time we will get a new table created with the new name, and possibly even a `DROP TABLE` for the existing table, assuming we have the appropriate options set. (By default, SSDT won't drop objects from the database unless we specify "[Drop objects in target but not in source]({{< relref "post/2016-10-25-database-refactoring-ssdt-dropping-objects.md#a-note-on-drop-objects-not-in-source" >}})").

``` sql
PRINT N'Dropping [dbo].[PlaylistTrack]...';
GO
DROP TABLE [dbo].[PlaylistTrack];
GO
PRINT N'Creating [dbo].[Playlist_Track]...';
GO
CREATE TABLE [dbo].[Playlist_Track] (
    [PlaylistId] INT NOT NULL,
    [TrackId]    INT NOT NULL,
    CONSTRAINT [PK_PlaylistTrack] PRIMARY KEY NONCLUSTERED ([PlaylistId] ASC, [TrackId] ASC)
);

```
## Renaming Programmable Objects (Views, Functions, Stored Procedures, other miscellany in [`sys.sql_modules`]
>Refactoring Databases, p 117

As noted in the [discussion of dropping programmable objects]({{< relref "post/2016-10-25-database-refactoring-ssdt-dropping-objects.md#dropping-programmable-objects-views-functions-stored-procedures-other-miscellany-in-sys-sql-modules-https-msdn-microsoft-com-en-us-library-ms175081-aspx" >}}), operations involving these objects involve substantially less risk of catastrophic data loss and consequent unemployment than similar operation involving tables and columns.

It is still important to use the Refactor &rarr; Rename and Refactor &rarr; Move to Schema techniques to rename these objects rather than directly editing the `.sql` files, so that an entry is written to the `.refactorlog` file. This will ensure that the existing object is altered rather than a new one created at the expense of the old one.

```xml
<Operation Name="Rename Refactor" Key="fc4b928d-9b00-4028-9cac-5859ba9b666c" ChangeDateTime="11/12/2016 22:50:20">
  <Property Name="ElementName" Value="[dbo].[ChangeTrackPriceByFactor]" />
  <Property Name="ElementType" Value="SqlProcedure" />
  <Property Name="ParentElementName" Value="[dbo]" />
  <Property Name="ParentElementType" Value="SqlSchema" />
  <Property Name="NewName" Value="[ChangeTrackPriceByMultiplier]" />
</Operation>
  ```

[^1]: It isn't magic, this doesn't work with dynamic SQL, for instance.

