+++
title=  'Building and Deploying "traditional" Microsoft BI projects to Windows Azure Virtual Machines using VSTS'
date =  "2018-03-20"
tags = ["VSTS","SSDT"]
draft = true

+++

"Lifting and Shifting" of on-premises BI systems into cloud hosting seems to be all the rage in certain circles right now, and for many organisations a migration to "Infrastructure-as-a-Service", also known as "IaaS", also known as "a bunch of VMs in the cloud" represents the "lowest risk" - and, of course, "lowest reward" - approach to moving processing out of your data centre and into somebody else's.

This article will consider the advantages of being able to build and deploy "traditional" BI projects such as SSIS, SSAS, and SSRS to Windows Azure Virtual Machines using the facilities provided by Visual Studio Team Services.

## The sample project

The project consists of a source database - which, for convenience, we will host using Windows Azure SQL Database - an SSIS package to do some ETL, a "Data Warehouse" database, a Tabular SSAS model, and some SSRS reports. All of these components other than the source database will be installed on a single Windows Azure Virtual Machine running SQL Server. 

In "real life", of course, it's quite uncommon for a single developer - or even a single team - to be responsible for both the application databases which are the sources for our ETL pipeline, as well as the SSIS packages, data warehouse design , SSAS models, and SSRS reports used for reporting. However, in the interests of presenting an end-to-end solution, I have included the definition of the source database in the same Visual Studio solution as all the other projects.

## Provisioning the Infrastructure

For this example, the only infrastructure we require is an Azure SQL Database to act as the data source, and a Virtual Machine with the SQL Server Database Engine, SQL Server Integration Services, SQL Server Analysis Services, and SQL Server Reporting Services components installed. 

I have created an Azure Resource Manager Template which will create everything we need and submitted it to the Azure RM Samples Gallery. It can be installed in your own Azure subscription by clicking here:

