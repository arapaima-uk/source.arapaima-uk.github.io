+++
title=  'Recovering from the "La-La-Land Moment"'
date =  "2017-03-16"
tags = ["SSDT"]
draft = false
+++
# How SSDT can help with restoring a SQL Server database to "just before that last deployment"

For as long as I can remember, SSDT and its predecessors have had the option to "Back up database before deployment", currently available in the "Advanced Publish Settings" dialog, among other places. Regrettably, I've never really had much use for this particular option. Whilst restoring from backup might be a valid strategy for recovering from some kinds of deployment disaster, this could add a great deal of time to the deployment process, assuming a database of non-trivial size. 

In any case, there are really only two kinds of database - the ones where you don't care about the data, such as development and test environments, and the ones (one?) where you do. In the former case, backups don't matter anyway, and in the latter case it is to be hoped that there is already some kind of backup solution in place, ideally managed by someone who isn't you.

Further, the "Backup database before deployment" option appears not to offer much control over _how_ the database is backed up. The backup will be created in the default backup directory of the instance, and will be a *full* rather than a *copy only* backup, which has the potential to endanger the "real" disaster recovery plans in the event that these include differential database backups, as the SSDT-generated backup will reset the differential base, meaning _this_ backup, which the DBAs don't even know about,  will be necessary, along with the subsequent differentials, in case the database needs to be restored.

It's likely that the "real" backup strategy will involve some combination of full, differential, and transaction log backups, and if you're especially lucky will be managed by some kind of "Enterprise Backup Solution", which will allow rapid restores to any point in time, just as soon as you figure out where it is that the "Enterprise Backup Solution" keeps the backup files for your database.

So, assuming the worst case scenario has arisen, your newly deployed release has been writing rubbish data to the database for the last few hours, the "war room" has been convened and someone you've never heard of called the "Problem Management Executive Consultant" has decided that the right course of action is to "Restore the database to immediately before the deployment", how are you to decide when this was?

Well, hopefully you know from your release logs what time the database was deployed, but what if there was a better way? And what if you aren't sure what timezone the deployment server is in or whether it uses daylight savings time? Well, one solution to this involves a somewhat neglected feature of SQL Server known as [Marked Transactions](https://msdn.microsoft.com/en-us/library/ms188929.aspx#Anchor_3). (See, it doesn't even get its own page in MSDN!)

## Marked Transactions

The syntax `BEGIN TRANSACTION` _tran-name_ `WITH MARK 'Mark Description'` will record the name of the transaction in the transaction log, along with the date, time, LSN, etc. The description is optional, but that gets saved too. 

We can see this in action using the [`pubs`](https://technet.microsoft.com/en-us/library/ms143221.aspx) database, which if you're younger than a certain age, sadly isn't what you think. 

Note that if you're playing along at home, there are a couple of extra considerations; the database needs to be using the full (or bulk-logged) recovery model and _a full backup must already have been taken_, i.e. the database is not in the [pseudo-simple](http://www.sqlskills.com/blogs/paul/new-script-is-that-database-really-in-the-full-recovery-mode/) recovery model.

``` SQL

USE pubs;
GO

BEGIN TRANSACTION update_auths WITH MARK 'update authors entry'
UPDATE authors set 
phone = '408 496-7223' WHERE au_id = '172-32-1176'
COMMIT TRANSACTION
```
If we take a peek at the transaction log we can see our marked transaction there:

``` SQL
SELECT  [Transaction ID] ,
        [Current LSN] ,
        [Transaction Name] ,
        [Operation] ,
        Description ,
        [Transaction SID] ,
        sp.name
FROM    fn_dblog(NULL, NULL) AS f
        JOIN sys.server_principals sp ON f.[Transaction SID] = sp.sid
WHERE   [transaction Name] = 'update_auths'

```
 Transaction ID | Current LSN | Transaction Name | Operation | Description | Transaction SID | name        
----------------|-------------|------------------|-----------|-------------|-----------------|------
 0000:000004ee  | 00000022:000005f2:0001 | update_auths| LOP_BEGIN_XACT | 2017/03/16 18:09:58:327;update_auths;0x0105000000000005150000004cca9a3fa9173a6eba0c5dc9e9030000 | 0x0105000000000005150000004CCA9A3FA9173A6EBA0C5DC9E9030000 | ARAPAIMA\Arapaima  

The `logmarkhistory` table in `msdb` also stores a list of our marked transactions:

```SQL
SELECT * FROM msdb..logmarkhistory
```

 database_name | mark_name| description | user_name         | lsn               | mark_time  
---------------|--------------|----------------------|-------------------|-------------------|------------------------- 
 pubs          | update_auths | update authors entry | ARAPAIMA\Arapaima | 34000000152200003 | 2017-03-16 18:09:58.327  

So, it seems we can use this functionality to give us a named point in the transaction log to restore to in the event of career-threatening disaster. 

The thing to note is that we need to update _something_ in the database where we're creating the mark, but it doesn't really matter _what_ we update. It's often useful to have a `Releases` table in our databases where we can store the version number, date, and other fun facts about our database, so this is as good a candidate as any.

```SQL
CREATE TABLE [dbo].[Releases]
(
        ReleaseVersion VARCHAR(20) NOT NULL PRIMARY KEY,
        DateDeployed DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME() 
        --Not taking any chances with the time zone!

)
```
We need to create this table and add it to our database project.

I've created a proc to do the inserting:

``` SQL
CREATE PROCEDURE [dbo].[spFireInTheHole]
	@ReleaseVersion varchar(20)
AS
BEGIN TRANSACTION @ReleaseVersion WITH MARK @ReleaseVersion 
  INSERT INTO dbo.Releases(ReleaseVersion) VALUES (@ReleaseVersion);
COMMIT TRANSACTION
RETURN 0
```
And now for the tricky part...

The _first_ time we deploy the database project after adding these objects, they won't be present in the target database, so we won't be able to call them from the pre-deployment script. This means we need to wrap them with `IF EXISTS` in the pre-deployment script so that they don't get called if they don't exist. The drawback of this approach, naturally, is that "Release 0.0.1" won't be recorded in your database for posterity. In my experience of such matters, the gap between Release 0.0.1 and Release 0.0.2 is normally measured in minutes rather than years, so I'm not particularly concerned about this.

Finally, we are going to use a `sqlcmd` *variable* to hold the release number; this means we can pass it in at deployment time. Most deployment tools know how to do this, for this example we'll just pass it on the command line.

### The pre-deployment script

```SQL
/*
 Pre-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be executed before the build script.	
 Use SQLCMD syntax to include a file in the pre-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the pre-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/

IF EXISTS(SELECT * FROM sys.tables where name = 'Releases') 
AND 
EXISTS (SELECT * FROM sys.procedures WHERE NAME = 'spFireInTheHole')
BEGIN
	
        EXEC spFireInTheHole @ReleaseVersion = '$(ReleaseVersion)';
END
```
Now, after we build our `dacpac`, we supply the version number at deploy time:

```
sqlpackage.exe /Action:Publish /SourceFile:pubs.dacpac /TargetServerName:(local) /TargetDatabaseName:pubs /v:ReleaseVersion=0.2.0

```

If we run a few "Releases", we can see the marks building up in `msdb..logmarkhistory`:

 database name      | mark name      | description           | user name         | lsn               | mark_time  
--------------------|----------------|-----------------------|-------------------|-------------------|------------------------- 
 pubs               |   0.0.2        |  0.0.2                | ARAPAIMA\Arapaima | 34000000172100002 | 2017-03-16 20:06:40.490 
 pubs               |   0.0.3        |  0.0.3                | ARAPAIMA\Arapaima | 34000000172200003 | 2017-03-16 20:07:14.673 
 pubs               |   0.0.3        |  0.0.3                | ARAPAIMA\Arapaima | 34000000172300002 | 2017-03-16 20:08:16.183 
 pubs               |   0.0.4        |  0.0.4                | ARAPAIMA\Arapaima | 34000000172400003 | 2017-03-16 20:08:39.760 


In this particular setup, you'll get an error if you try to supply the same version number more than once, as `ReleaseVersion` is the primary key of the `Releases` table.

### Disaster Strikes

So, the career-threatening disaster has happened, and we need to restore our database to its state immediately prior to release 0.6.0. If there hasn't been a log backup since the deployment, the first step is to make one.

Then, with a bit of DBA magic, we can restore our database to just before the deployment started. I generated these scripts from SQL Server Management Studio, unless you've got a competent adult handy I suggest you do the same. The crucial bit is in the last line where we specify `STOPBEFOREMARK`, which is exactly what we want to do.

```SQL

USE [master]
BACKUP LOG [pubs] TO  DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup\pubs_LogBackup_2017-03-16_21-05-56.bak' WITH NOFORMAT, NOINIT,  NAME = N'pubs_LogBackup_2017-03-16_21-05-56', NOSKIP, NOREWIND, NOUNLOAD,  NORECOVERY ,  STATS = 5
RESTORE DATABASE [pubs] FROM  DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup\pubs.bak' WITH  FILE = 2,  NORECOVERY,  NOUNLOAD,  STATS = 5
GO
RESTORE LOG [pubs] FROM  DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup\pubs.bak' WITH  FILE = 3,  NORECOVERY,  NOUNLOAD,  STATS = 10
GO
RESTORE LOG [pubs] FROM  DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup\pubs.bak' WITH  FILE = 4,  NORECOVERY,  NOUNLOAD,  STATS = 10
GO
RESTORE LOG [pubs] FROM  DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup\pubs.bak' WITH  FILE = 5,  NOUNLOAD,  STATS = 10,  STOPBEFOREMARK = N'0.6.0' AFTER N'2017-03-16T20:46:07'
GO
```

And with that, the database is restored to its state immediately prior to the deployment - you can check this by looking at the `Releases` table - , and all that is left to do is blame the guy that left last month for the "rogue code" that "crept" into the release. This is normally possible by editing old git commit messages and force pushing the master branch, but that's a topic for another day.