/*
Mastering Index Tuning - Index Usage DMV Gotchas
 
This script is from our Mastering Index Tuning class.
To learn more: https://www.BrentOzar.com/go/tuninglabs
 
License: Creative Commons Attribution-ShareAlike 3.0 Unported (CC BY-SA 3.0)
More info: https://creativecommons.org/licenses/by-sa/3.0/
 
You are free to:
* Share - copy and redistribute the material in any medium or format
* Adapt - remix, transform, and build upon the material for any purpose, even 
  commercially
 
Under the following terms:
* Attribution - You must give appropriate credit, provide a link to the license,
  and indicate if changes were made.
* ShareAlike - If you remix, transform, or build upon the material, you must
  distribute your contributions under the same license as the original.
*/



/* Doorstop */
RAISERROR(N'Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO



/* DMVs
	Good: well documented by MS and blogs, easy to find scripts and tools that use them
	Bad: User written doco is wrong, misleading context, contents can reset unexpectedly, hit-or-miss coverage in Azure, keeps changing

	sys.dm_db_index_usage_stats (isnt really correct, stays around forever)
		- Shows # of executions where a plan included an operator (does NOT show if the operater was used, or how often it was accessed)
		- Number and last date of reads (seeks, scans, lookups)
		- Number and last date of last write (insert/update/deletes all called updates
		- Data is since startup or when the index was modified

	sys.dm_db_index_operational_stats  (very correct when it's correct, but not sure when its cleared)
		- Lower level, more transitory
		- Lock waits (page and row)
		- Access counts (doesnt distingush between full scans / range scans, or even range scans and seeks)
		- Data only persisted while objects metadata is in memory
		- No good way to tell when it was last cleared 
*/

USE StackOverflow;
GO
EXEC DropIndexes;
GO
CREATE INDEX IX_LastAccessDate ON dbo.Users(LastAccessDate);
GO
EXEC sp_BlitzIndex @SchemaName='dbo', @TableName='Users';
GO


/* Look at the Usage Stats and Operational Stats columns */
/* These comes from sys.dm_db_index_usage_stats and sys.dm_db_index_operational_stats 
	Technically this looks like an index scan, but it's hard to see that from the index
	usage DMV's.... 

	l
*/


/* Look at the page reads for this query. */
/* Did it scan the whole index? 
	Usage stats indicates 

*/
SET STATISTICS IO ON;
GO
SELECT TOP 10 Id
FROM dbo.Users
ORDER BY LastAccessDate;
GO


/* Can you tell if it's a bad scan from the index DMVs? */
exec sp_BlitzIndex @SchemaName='dbo', @TableName='Users';
GO



/* Try a descending one. Does it read the whole table? */
SELECT TOP 10 Id
FROM dbo.Users
ORDER BY LastAccessDate DESC;
GO
/* Look in the properties of the NC index scan-- it did a backwards scan */


exec sp_BlitzIndex @SchemaName='dbo', @TableName='Users';
GO



/* Reset the index usage statistics. Man, I wish there was an easier way to do this in 2016. */
USE [master]
GO
ALTER DATABASE [StackOverflow] SET  OFFLINE WITH ROLLBACK IMMEDIATE;
GO
ALTER DATABASE [StackOverflow] SET ONLINE;
GO
USE StackOverflow;
GO



/* This plan is slightly different, it has a key lookup */
SELECT TOP 10 Id, Location
FROM dbo.Users
ORDER BY LastAccessDate;
GO


/* Compare how the key lookup is recorded differently in index_stats and usage_stats */
exec sp_BlitzIndex @SchemaName='dbo', @TableName='Users';
GO





/* Reset the index usage statistics. Man, I wish there was an easier way to do this in 2016. */
USE [master]
GO
ALTER DATABASE [StackOverflow] SET  OFFLINE WITH ROLLBACK IMMEDIATE;
GO
ALTER DATABASE [StackOverflow] SET ONLINE;
GO
USE StackOverflow;
GO




/* This plan is slightly different, it has a key lookup - but it doesn't get executed. */
SELECT TOP 10 Id, Location
FROM dbo.Users
WHERE LastAccessDate > GETDATE()
ORDER BY LastAccessDate;
GO


/* How does that show up in the DMVs? */
exec sp_BlitzIndex @SchemaName='dbo', @TableName='Users';
GO