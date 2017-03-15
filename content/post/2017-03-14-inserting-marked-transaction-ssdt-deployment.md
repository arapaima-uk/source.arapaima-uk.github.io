+++
title=  ""
date =  "2017-03-14"
tags = ["SSDT"]
draft = true
+++

For as long as I can remember, SSDT and its predecessors have had the option to "Back up database before deployment", currently available in the "Advanced Publish Settings" dialog, among other places. Regrettably, I've never really seen the point of this particular option. Whilst restoring from backup might be a valid strategy for recovering from a deployment disaster, this could add a great deal of time to the deployment process, assuming a database of non-trivial size. 

In any case, there are really only two kinds of database - the ones where you don't care about the data, such as development and test environments, and the ones (one?) where you do. In the former case, backups don't matter anyway, and in the latter case it is to be hoped that there is already some kind of backup solution in place, ideally managed by someone who isn't you.

Further, the "Backup database before deployment" option appears not to offer much control over _how_ the database is backed up. The backup will be created in the default backup directory of the instance, and will be a *full* rather than a *copy only* backup, which has the potential to endanger the "real" disaster recovery plans in the event that these include differential database backups, as the SSDT-generated backup will reset the differential base, meaning _this_ backup, which the DBAs don't even know about,  will be necessary, along with the subsequent differentials, in case the database needs to be restored.

It's likely that the "real" backup strategy will involve some combination of full, differential, and transaction log backups, and if you're especially lucky will be managed by some kind of "Enterprise Backup Solution", which will allow rapid restores to any point in time, just as soon as you figure out where it is that the "Enterprise Backup Solution" keeps the backup files for your database.

So, assuming the worst case scenario has arisen, your newly deployed release has been writing rubbish data to the database for the last few hours, the "war room" has been convened and someone you've never heard of called the "Problem Management Executive Consultant" has decided that the right course of action is to "Restore the database to immediately before the deployment", how are you to decide when this was?

Well, hopefully you know from your release logs what time the database was deployed, but what if there was a better way? And what if you aren't sure what timezone the deployment server is in or whether it uses daylight savings time? Well, one solution to this uses a somewhat neglected feature of SQL Server known as [Marked Transactions](https://msdn.microsoft.com/en-us/library/ms188929.aspx#Anchor_3). (See, it doesn't even get its own page in MSDN!)

## Marked Transactions

The syntax `BEGIN TRANSACTION` _tran-name_ `WITH MARK 'Mark Description'` will cause the name of the transaction to be written into the transaction log, along with the date, time, database name, LSN, etc. The description is optional, but that gets saved too. 

We can see this in action using the `pubs` database, which if you're younger than a certain age, sadly isn't what you think.

``` SQL

USE pubs;
GO

BEGIN TRANSACTION update_auths WITH MARK 'update authors entry'
UPDATE authors set 
phone = '408 496-7223' WHERE au_id = '172-32-1176'
COMMIT TRANSACTION
```
If we take a peek at the transaction log:

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
| Transaction ID | Current LSN            | Transaction Name | Operation      | Description                                                                                     | Transaction SID                                            | name              |
|----------------|------------------------|------------------|----------------|-------------------------------------------------------------------------------------------------|------------------------------------------------------------|-------------------| 
| 0000:000004f2  | 00000022:000005e8:0001 | update_auths     | LOP_BEGIN_XACT | 2017/03/14 20:34:44:637;update_auths;0x0105000000000005150000004cca9a3fa9173a6eba0c5dc9e9030000          | 0x0105000000000005150000004CCA9A3FA9173A6EBA0C5DC9E9030000 | ARAPAIMA\Arapaima |