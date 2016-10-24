+++
title=  "Refactoring Databases with SSDT"
date =  "2016-10-21"
tags = "Refactoring, SSDT"
series = "Refactoring Databases with SSDT"
draft = false
+++

The book [Refactoring Databases](http://www.pearsoned.co.uk/bookshop/detail.asp?WT.oss=refactoring%20databases&WT.oss_r=1&item=100000000444392) by Scott Ambler and Pramod Sadalage, first published over ten years ago, has become something of a modern classic in the field of agile database delivery. The authors give a definition (in fact taken from an [earlier book](http://eu.wiley.com/WileyCDA/WileyTitle/productCd-0471202835.html)) of a database refactoring as
 
> ...a simple change to a database schema that improves its design while retaining both its behavioral and informational semantics.

The book is divided into two sections, the first being a discussion of agile database development techniques, placing database refactoring in a wider technical and organisational contect. This material, intended to be read in order, is recommended reading for anyone struggling to improve the working practices associated with database delivery in any organisation, irrespective of the tools being used. 

The second is a collection of named "refactorings" along with the steps required to implement each one, and is structured as a reference work rather than as a continuous narrative. There are online versions of this catalog maintained at the websites of [Scott Ambler](<http://www.agiledata.org/essays/databaseRefactoringCatalog.html) and [Pramod Sadalage](http://databaserefactoring.com/) respectively.

This article marks the start of a series that examines a number of these named "refactorings" and looks at how they can be implemented using Microsoft® SQL Server and Microsoft® Visual Studio, in particular through the use of [SQL Server Data Tools](https://blogs.msdn.microsoft.com/ssdt/), known as "SSDT".

The code examples in the book use Oracle with bits of Java and Hibernate thrown in as appropriate, so the examples here will differ where the behaviour of SQL Server differs in some relevant way. In addition, the "[declarative](https://blogs.msdn.microsoft.com/gertd/2009/06/05/declarative-database-development "The original DataDude article from way back")" development paradigm encouraged by SSDT hides a lot of the detail of the DDL behind the scenes, meaning that the steps outlined in the book to achieve each refactoring may not all occur in the same places. 

That said, it is worth referring to the discussions of each individual refactoring contained in the book, since these provide a checklist of considerations before embarking on any change, including motivations, tradeoffs, schema update and data migration mechanics, and required application changes, most of which are outside the scope of SSDT. I will attempt to provide page numbers where appropriate, though I realise these are less useful for those with access to only an electronic copy of the book. 

In general, the applicability of SSDT is restricted to managing schema changes, with a couple of extensibility points - namely [Pre-deployment and Post-deployment scripts](https://msdn.microsoft.com/en-us/library/jj889461(v=vs.103).aspx) -  to manage data movements.

This series does presuppose some experience with SSDT; an overview can be obtained from MSDN [here](https://msdn.microsoft.com/en-us/library/hh272686(v=vs.103).aspx), particularly the material relating to [Project-Oriented Offline Database Development](https://msdn.microsoft.com/en-us/library/hh272702(v=vs.103).aspx). In the event that I ever get around to writing any introductory material of my own I'll come back and add links here as appropriate. Most of the examples use the "Chinook" sample database available from [codeplex](https://chinookdatabase.codeplex.com/).