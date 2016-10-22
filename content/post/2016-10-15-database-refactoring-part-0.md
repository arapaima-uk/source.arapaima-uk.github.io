+++
title=  "Refactoring Databases with SSDT"
date =  "2016-10-15"
tags = "Refactoring, SSDT"
draft = true
+++

The book [Refactoring Databases](http://databaserefactoring.com/) by Scott Ambler and Pramod Sadalage, first published over ten years ago, is something of a modern classic in the field of agile database delivery.  The authors give a definition (in fact taken from an [earlier book](http://eu.wiley.com/WileyCDA/WileyTitle/productCd-0471202835.html)) of a database refactoring as
 
> ...a simple change to a database schema that improves its design while retaining both its behavioral and informational semantics.

The book is divided into two sections, the first being a discission of agile database development techniques, placing database refactoring in a wider technical and organisational context. This is recommended reading. 

The second section is a collection of named "refactorings" along with the steps required to implement each one.

This article will be the first in a series that examines each of these named refactorings in turn and looks at how they can be implemented using Microsoft® SQL Server and Microsoft® Visual Studio, in particular through the use of [SQL Server Data Tools](https://blogs.msdn.microsoft.com/ssdt/), known as "SSDT".

The code examples in the book use Oracle with bits of Java and Hibernate thrown in as appropriate, so some modifications will need to be made where the behaviour of SQL Server differs in some relevant way. In addition, the "[declarative](https://blogs.msdn.microsoft.com/gertd/2009/06/05/declarative-database-development "The original DataDude article from way back")" development paradigm encouraged by SSDT hides a lot of the detail of the DDL behind the scenes, meaning that the steps outlined in the book to achieve each refactoring may not all occur in the same places. 

This series does presuppose some experience with SSDT; an overview can be obtained from MSDN [here](https://msdn.microsoft.com/en-us/library/hh272686(v=vs.103).aspx). In the event that I ever write any introductory material of my own I'll come back and update this link!