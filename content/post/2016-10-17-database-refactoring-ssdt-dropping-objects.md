+++
title=  "Database Pruning"
date =  "2016-10-17"
tags = "Refactoring, SSDT"
series = "Refactoring Databases with SSDT"
draft = true
+++

After a period of time in use, most databases, like many systems that have grown in an organic matter, can benefit from some judicious pruning. This can take the form of removing columns or even tables no longer required to support the application, or that store redundant - and hence possibly erroneous - copies of information stored elsewhere.

 ![The gardener's assistant; a practical and scientific exposition of the art of gardening in all its branches (1910) (14761716416).jpg](https://upload.wikimedia.org/wikipedia/commons/7/70/The_gardener%27s_assistant%3B_a_practical_and_scientific_exposition_of_the_art_of_gardening_in_all_its_branches_%281910%29_%2814761716416%29.jpg "[By Internet Archive Book Images [No restrictions], via Wikimedia Commons]")

## Dropping a column
Since SSDT operates in a declarative manner, each table is defined in a `CREATE TABLE` script, and deleting a column is as simple as deleting the relevant line from the script. However, there are a couple of features of SSDT that are relevant here. If the column is referenced by any other database objects such as views, functions, or stored procedures, SSDT will display an error:

![SSDT Broken Reference Error](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/ssdt-refactoring-part-1/DropColumnReferencedByProcedure.PNG "SSDT Broken Reference Error")

The full text of the error message reads `SQL71501: Procedure [dbo.UpdateInvoiceBillingAddress] has an unresolved reference to object [dbo].[Invoice].[BillingPostalCode]`, and the offending reference in the stored procedure[^1] has acquired a "red squiggly". There's no "builtin" refactoring action defined in the right-click context menu for deletions,  






[^1]: This procedure isn't in the original Chinook database, I added it for the purpose of this example.