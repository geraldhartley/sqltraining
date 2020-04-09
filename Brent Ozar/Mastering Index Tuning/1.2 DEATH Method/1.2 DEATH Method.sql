/*
Mastering Index Tuning - The D.E.A.T.H. Method
Last updated: 2019-06-14

This script is from our Mastering Index Tuning class.
To learn more: https://www.BrentOzar.com/go/masterindexes

Before running this setup script, restore the Stack Overflow database.
Don't run this all at once: it's about interactively stepping through a few
statements and understanding the plans they produce.

Requirements:
* Any SQL Server version or Azure SQL DB
* Stack Overflow database of any size: https://BrentOzar.com/go/querystack
 


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




This first RAISERROR is just to make sure you don't accidentally hit F5 and
run the entire script. You don't need to run this:
*/
RAISERROR(N'Oops! No, don''t just hit F5. Run these demos one at a time.', 20, 1) WITH LOG;
GO


USE StackOverflow;
GO


IF DB_NAME() <> 'StackOverflow'
  RAISERROR(N'Oops! For some reason the StackOverflow database does not exist here.', 20, 1) WITH LOG;
GO


/* Create a few indexes: */
CREATE INDEX IX_LastAccessDate ON dbo.Users(LastAccessDate);
CREATE INDEX IX_Age ON dbo.Users(Age) INCLUDE (LastAccessDate);
CREATE INDEX IX_DisplayName ON dbo.Users(DisplayName) INCLUDE (LastAccessDate);
CREATE INDEX IX_DownVotes ON dbo.Users(DownVotes) INCLUDE (LastAccessDate);
CREATE INDEX IX_Location ON dbo.Users(Location) INCLUDE (LastAccessDate);
CREATE INDEX IX_Reputation ON dbo.Users(Reputation) INCLUDE (LastAccessDate);
GO



/* Get the estimated plans for these - don't actually run 'em: 
	2:25 - A 'narrow' execution plan
*/
DELETE dbo.Users WHERE Reputation = 1000000;


/* 5:00 - 	A 'wide' execution plan
1. SQL server makes a list of all the people, 
	2. delete everyone on the clustered index
	3. for each row, it takes a copy of the table, sorts by the column, and processes the delete!! Ouch

*/
DELETE dbo.Users WHERE Reputation = 1;

/* the index on DisplayName is helpful...
	the index on Last Access Date is painful!
*/
UPDATE dbo.Users
    SET LastAccessDate = GETDATE()
    WHERE DisplayName = 'Brent Ozar';
GO

/* Too many indexes cause...
-- ==============================
	Longer Delete, Updates, Inserts (DUI)
	Slower storage response
	Blocking
	Longer Maintenance Jobs take
	Less effective memory (DUI's take place in memory)

	Fewest number of queries as practical (5x5 GUIDELINE, not a rule) -
-- ==============================
		Most relevant: Slow hardware, ingestion speed is absolutely critical
		Exceptions: Read only / read biased tables, very good hardware, when DUI speed doesnt matter
*/


/* Just one index on Reputation, nothing else: 
	Great! Access is fast without Last Access Date!

*/
EXEC DropIndexes;
GO
CREATE INDEX IX_Reputation ON dbo.Users(Reputation);
GO


/* All our indexes, but WITHOUT the LastAccessDate include:
	Still fast, still no LastAccess Date!
*/
EXEC DropIndexes;
GO
CREATE INDEX IX_Age ON dbo.Users(Age);
CREATE INDEX IX_DisplayName ON dbo.Users(DisplayName);
CREATE INDEX IX_DownVotes ON dbo.Users(DownVotes);
CREATE INDEX IX_Location ON dbo.Users(Location);
CREATE INDEX IX_Reputation ON dbo.Users(Reputation);
GO

/*
	No NC Indexes = 3m
	1 - 5 Indexes without LastIndexDate - 30sec
	1 Index on LastIndexDate - 1m
	5 Indexes on LastIndexDate - 3m
*/
CREATE INDEX IX_LastAccessDate ON dbo.Users(LastAccessDate);
GO

/* Summary: The faster you want to go:
	- Understand the hot columns
	- Avoid adding these to indexes
	- Run experiements
*/

/*
	DEATH Method:
	- Just Once  - (D)edupe, (E)liminate
		- Quick and safe (as long as your diligent), not a huge bang for buck, but makes it easier to add indexes
		- Add JIRA job codes to these
		- Note for Dedupe - if the leading columns (or first few) leading columns are different, unlikely to be duplicates!
	- Weeklyish - (A)dd
		- DMV's have gotchas, can add indexes that make things slower
	- If all else fails - 
		(T)uning:
			- Identifiy the query needing tuning
			- Test to make sure you getting the right plan (not param sniffing)
			- Read the execution plan, decide what to change
			- Change it, make sure it's faster while producing the same results
			- Deploy to production (peer reciew, source control, change app etc.) - A / B testing
		(H)eaps:
			- Sometimes the table doesnt have a good candidate for clustering, and we have to add one
			- Sometimes it doesnt need a clustered index
			- Changing the index can be invasive
*/


/* Format for Index Changes:

	1. List the indexes that are not being used:
		I reviewed the Users table, and we need to drop these indexes because they're not getting used: */
		DROP INDEX IX_DisplayName ON dbo.Users;
		DROP INDEX IX_LastAccessDate ON dbo.Users;
		DROP INDEX IX_ID4 ON dbo.Users;
		GO
/* 
	2. Provide the undo script 
		In case things go wrong, here's an undo script:
		CREATE INDEX IX_DisplayName ON dbo.Users(DisplayName);
		CREATE INDEX IX_LastAccessDate ON dbo.Users(LastAccessDate);
		CREATE INDEX IX_ID4 ON dbo.Users(Id);
 
	3. List the indexes you wish to dedupe, and the identified duplicates
		This index is a narrower subset of IX_LocationWebsiteUrl, so we should drop it: */
		DROP INDEX IX_Location ON dbo.Users;
		GO
 
/*	4. In case things go wrong, here's an undo script:
		CREATE INDEX IX_Location ON dbo.Users(Location);
 
	I'd like to merge these two indexes together into one:
 
	CREATE INDEX IX_Reputation_Includes ON dbo.Users(Reputation) INCLUDE (LastAccessDate);
	CREATE INDEX IX_Reputation_Location ON dbo.Users(Reputation, Location);
 
	Into this one: */
	CREATE INDEX IX_Reputation_Location_Includes ON dbo.Users(Reputation, Location) INCLUDE (LastAccessDate);
	GO
	/* And get rid of those above two afterwards: */
	DROP INDEX IX_Reputation_Includes ON dbo.Users;
	DROP INDEX IX_Reputation_Location ON dbo.Users;
	
