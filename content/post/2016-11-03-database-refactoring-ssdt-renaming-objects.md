+++
title=  "What's in a name?"
date =  "2016-11-03"
tags = ["Refactoring", "SSDT"]
series = ["Refactoring Databases with SSDT"]
draft = true
+++

Continuing our horticultural theme, in this article we'll look at the built-in support in SSDT for renaming database objects including tables, columns, and programmable objects, as well as peering into the details of how these changes are managed at deployment time.

![That which we call a rose. By any other name would smell as sweet](https://upload.wikimedia.org/wikipedia/commons/6/66/Rosa_laxa.jpg "That which we call a rose. By any other name would smell as sweet")

## Renaming a column

We can rename a column just by right-clicking in the table definition and selecting Refactor &rarr; Rename. Under normal circumstances, renaming the Primary Key of a table such as "Invoices" would be a recipe for disaster, but SSDT can help to ease such changes by automatically updating all references to the column to use the new name. In this case we are renaming the column InvoiceId to Invoice_Id, and by specifying the option to preview the changes, we can see a list of all the objects that reference this column by its old name.

There's something of note here, which is that _only_ the InvoiceId column from the Invoices table is being renamed, any other columns called InvoiceId (such as the one in the InvoiceLine table) are unaffected. The foreign key constraint on that particular column, however, _is_ updated to use the new name of the referenced column.

What this demonstrates is that there is something more than global search and replace going on here; SSDT is using its in-memory model of the database to determine which changes need to be made[^1].

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
This refactorlog file is how SSDT will detemine _at deploy time_ that we are renaming this column from InvoiceID to Invoice_Id rather than dropping the InvoiceID column and creating a new column called Invoice_ID. This is known, in the jargon, as "preserving the intent" of the refactoring. If we build a project containing a `.refactorlog` file and examine the resulting `.dacpac`, we can see that the regular `.dacpac` contents have been joined by a `refactor.xml` file. The contents of this file are the same as the `.refactorlog` file from our solution.

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

This file is what tells `sqlpackage.exe` (or SSDT publish, or DacFX.Deploy) what to do when it encounters this difference at deploy time.

Apart from the XML gubbins, we can see that this is specifying the column and table name, and the precise action to perform.

When we publish the project we see the following output:
``` bat
The following operation was generated from a refactoring log file 209f3afd-7195-401f-853f-aa3a906d39db
Rename [dbo].[Invoice].[InvoiceId] to Invoice_Id
Caution: Changing any part of an object name could break scripts and stored procedures.

Altering [dbo].[InvoicesWithLineTotals]...
Altering [dbo].[UpdateInvoiceBillingAddress]...
Update complete.
```
The publish action has read the `refactorlog` file and taken the appropriate action.

There's another UI wrinkle here which is worth examining, so we will rename another column, this time using the table designer.

Another entry has been added to the `refactorlog` file, and _without prompting_ the references to this column elsewhere in the model have been updatedd (note the red tick showing that `PlaylistTrack.sql` has been modified.)

Rename Table

Rename View

[^1]: It isn't magic, this doesn't work with dynamic SQL, for instance.

