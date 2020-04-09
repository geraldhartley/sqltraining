/*
Fundamentals of Index Tuning: SQL Server's Built-In Index Recommendations

v1.2 - 2019-09-04

https://www.BrentOzar.com/go/indexfund


This demo requires:
* Any supported version of SQL Server
* Any Stack Overflow database: https://www.BrentOzar.com/go/querystack

This first RAISERROR is just to make sure you don't accidentally hit F5 and
run the entire script. You don't need to run this:
*/
RAISERROR(N'Oops! No, don''t just hit F5. Run these demos one at a time.', 20, 1) WITH LOG;
GO



/* This stored procedure drops all nonclustered indexes: */
DropIndexes;
GO
/* It leaves clustered indexes in place though. */


SET STATISTICS IO ON;
GO
/* What missing index does this ask for? Are you sure? 
In plans, only the first recommendation shows (1 at a time), not even the biggest one!
There could be muliple in a plan, with an even higher impact 
*/
SELECT c.CreationDate, c.Score, c.Text, p.Title, p.PostTypeId
  FROM dbo.Users u
  INNER JOIN dbo.Comments c ON u.Id = c.UserId
  INNER JOIN dbo.Posts p ON c.PostId = p.ParentId
  WHERE u.DisplayName = 'Brent Ozar';
GO


/* And what index does this ask for? */
SELECT Location, COUNT(*)
  FROM dbo.Users
  GROUP BY Location
  ORDER BY COUNT(*) DESC;
GO

/* The recommendation system does NOT take order columns into consideration
  Every now and then you'll strike it lucky. Optimiser places:
	- equality fields first, ordered by the columns they appear in the table
	- inequality fields second, ordered by the columns as they appear in the table
  Other than this, Clippy just spits out a comma seperated list of fields...


  The optimiser's key choices are influenced by
	- How often you filter on a field
	- How selective your filter caluse is
	- The size of the field
	- What you do further upstream in the query (joining, grouping, ordering)

	Optimiser doesnt have the time to optimise, when its main job is to generate a plan in milliseconds.
	Recall that providing missing indexes is not its first job, just a secondary effect of 
	optimizing queries
*/

/* What about field ordering? */
SELECT Id
FROM dbo.Users 
ORDER BY DisplayName ;


/* Same thing, but only people in India
	Now it gives a suggestion, despite the first table 
	having more work to do!
	Not only that, but its only INCLUDED DisplayName,
	rather than adding to the key*/
SELECT Id
FROM dbo.Users
WHERE Location = 'India'
ORDER BY DisplayName

/* What optimiser can potentially miss:
	- May only be accurate for one set of parameters
	- May not show all missing indexes
	- Keys vs includes arent right
	- Column order isnt right either
*/

/* How does this query run?

	It scans the whole table, dumps the locations in buckets,
	parallel across threads, sorth them, and spills them to disk

	Every time the query runs...
		- we're going to underestimate row counts
		- we're going to underallocate memory
		- we're going to TempDB
		- we're going to burn more CPU time sorting than expected
*/
CREATE INDEX IX_Location ON dbo.Users (Location);
GO
SELECT Location, COUNT(*)
  FROM dbo.Users
  GROUP BY Location
  ORDER BY COUNT(*) DESC;
GO



SELECT Location, COUNT(*)
FROM dbo.Users
GROUP BY Location
ORDER BY COUNT(*) DESC;

DropIndexes;
GO
/* 14:53 In some cases, Clippy's suggestions can make things worse!

Note that there is no suggestion on this query*/

SET STATISTICS IO ON;

SELECT TOP 100 *
  FROM dbo.Users
  WHERE Reputation = 1
  ORDER BY CreationDate DESC;
GO

/* Generate an index on creation date
	SQL engine will now use the index, and finally the optimizer
	will bring up a suggestion
*/
CREATE INDEX IX_CreationDate ON dbo.Users(CreationDate);
GO
SELECT TOP 100 *
  FROM dbo.Users
  WHERE Reputation = 1
  ORDER BY CreationDate DESC;
GO


/* Clippy's suggestion... Key is ONLY on reuputation, include ALL The columns! 

	With the Index, nothing wrong... cpu is low, performance is great:
	Table 'Users'. Scan count 1, logical reads 469, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
*/
CREATE NONCLUSTERED INDEX IX_Clippy_Reputation
ON [dbo].[Users] ([Reputation])
INCLUDE ([AboutMe],[Age],[CreationDate],[DisplayName],[DownVotes],[EmailHash],[LastAccessDate],[Location],[UpVotes],[Views],[WebsiteUrl],[AccountId])

SELECT TOP 100 *
  FROM dbo.Users
  WHERE Reputation = 1
  ORDER BY CreationDate DESC;
GO

/* Results: 
	- If we create Clippys index, it doesnt even get used if our index is in place
	- Ok, so lets drop our index... now clippy uses it's recommendation...
	- 
	- Hol up, performance is terrible... it pulls back 1 mil rows AND sorts all of them! 
	- Size is 4 times large, logical reads jump to 14k
*/
DROP INDEX dbo.Users.IX_CreationDate;
GO
SELECT TOP 100 *
  FROM dbo.Users
  WHERE Reputation = 1
  ORDER BY CreationDate DESC;
GO

/* Lets not be too harsh, Clippy was on to something,
	just not the index it suggested
	Place both fields on the key and it runs fast again
	
	The query wanst terrible slow, but SQL server asked for an index
	
	If this was a frequent query, it might be attractive... but the 
	requested index had the ORDER BY column as an include, when it really
	should be sorted
	
	The query was much better with the columns in the key
*/
DropIndexes;
GO
CREATE INDEX IX_Reputation_CreationDate 
  ON dbo.Users(Reputation, CreationDate);
GO
SELECT TOP 100 *
  FROM dbo.Users
  WHERE Reputation = 1
  ORDER BY CreationDate DESC;
GO


/* How to identify

	-Look for high average CPU and reads on top plans
	-Dig into every operator
	-In the real world on big plans, this is time consuming
	-You have to rule out other things that may be the issue, such as 
		parameter sniffing and inefficient or out of date statistics
*/

/* sp_BlitzIndex
	
	Note that all its data comes from Clippy, meaning:
	- Index usage stats reset at odd times
	- Missing index recommendations are derp
	- Only really works in production
*/

/*
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