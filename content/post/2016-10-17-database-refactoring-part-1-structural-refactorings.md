+++
title=  "Database Refactoring Part 1: Structural Refactorings"
date =  "2016-10-17"
tags = "Refactoring, SSDT"
draft = true
+++

The first type of refactoring addressed in the book is structural refactorings, namely those that change the structure of the tables in the database.

## Drop Column

This is an apparently simple operation, but there are a couple of details worth examining. 

Since SSDT operates in a declarative manner, each table is defined in a `CREATE TABLE` script, and deleting a column is as simple as deleting the relevant line from the script. However, there are a couple of features of SSDT that can hold us up here. If the column is referenced by any other database objects such as views, functions, or stored procedures, SSDT will display an error:
![SSDT Broken Reference Error](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/ssdt-refactoring-part-1/DropColumnReferencedByProcedure.PNG "SSDT Broken Reference Error")