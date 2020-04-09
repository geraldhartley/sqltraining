/*
Fundamentals of Index Tuning: ORDER BY Clause

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

SET STATISTICS IO ON; 

/* This stored procedure drops all nonclustered indexes: */
DropIndexes;
GO
/* It leaves clustered indexes in place though. */



/* Create the perfect index for this - note the equality on Location: 
2:50 - Earlier we mentioned that the order of equality in the WHERE clause doesnt matter
*/
SELECT Id, DisplayName, Location
    FROM dbo.Users
    WHERE DisplayName = 'alex'
        AND Location = 'Seattle, WA'
  ORDER BY Reputation;
GO


/* Create our earlier indexes, but add Reputation to them: */
CREATE INDEX IX_DisplayName_Location_Reputation
  ON dbo.Users(DisplayName, Location, Reputation);

/* Create our earlier indexes, but include Reputation: */
CREATE INDEX IX_DisplayName_Location_Includes
  ON dbo.Users(DisplayName, Location) INCLUDE (Reputation);

CREATE INDEX IX_Location_DisplayName_Reputation
  ON dbo.Users(Location, DisplayName, Reputation);

/* Plus a third idea: */
CREATE INDEX IX_Reputation_DisplayName_Location
  ON dbo.Users(Reputation, DisplayName, Location);
GO

/* Measure them: */
-- Logical Reads - 45184, Num Rows Read - 2465713
SELECT Id, DisplayName, Location
    FROM dbo.Users WITH (INDEX = 1)
    WHERE DisplayName = 'alex'
        AND Location = 'Seattle, WA'
  ORDER BY Reputation;

 -- Logical Reads - 4
SELECT Id, DisplayName, Location
    FROM dbo.Users WITH (INDEX = IX_DisplayName_Location_Reputation)
    WHERE DisplayName = 'alex'
        AND Location = 'Seattle, WA'
  ORDER BY Reputation;

  -- Logical Reads - 4
SELECT Id, DisplayName, Location
    FROM dbo.Users WITH (INDEX = IX_Location_DisplayName_Reputation)
    WHERE DisplayName = 'alex'
        AND Location = 'Seattle, WA'
  ORDER BY Reputation;

-- Logical Reads - 14007, Num Rows Read - 2465713
SELECT Id, DisplayName, Location
    FROM dbo.Users WITH (INDEX = IX_Reputation_DisplayName_Location)
    WHERE DisplayName = 'alex'
        AND Location = 'Seattle, WA'
  ORDER BY Reputation;
GO



/* Count the number of pages in each index: */
SELECT COUNT(*)
    FROM dbo.Users WITH (INDEX = 1);

SELECT COUNT(*)
    FROM dbo.Users WITH (INDEX = IX_DisplayName_Location_Reputation);

SELECT COUNT(*)
    FROM dbo.Users WITH (INDEX = IX_Location_DisplayName_Reputation);

SELECT COUNT(*)
    FROM dbo.Users WITH (INDEX = IX_Reputation_DisplayName_Location);
GO

/* Which one does SQL Server pick? */
SELECT Id, DisplayName, Location
    FROM dbo.Users
    WHERE DisplayName = 'alex'
        AND Location = 'Seattle, WA'
  ORDER BY Reputation;
GO




/* Create the perfect index for this - note the INequality on Location: */
SELECT Id, DisplayName, Location
    FROM dbo.Users
    WHERE DisplayName = 'alex'
        AND Location <> 'Seattle, WA'
  ORDER BY Reputation;
GO


/* Turn on actual plans: */
SELECT Id, DisplayName, Location
    FROM dbo.Users
    WHERE DisplayName = 'alex'
        AND Location <> 'Seattle, WA'
  ORDER BY Reputation;
GO

/* Visualize the index: */
SELECT DisplayName, Location, Reputation, Id
FROM dbo.Users
ORDER BY DisplayName, Location, Reputation;


CREATE INDEX IX_DisplayName_Location_Includes 
  ON dbo.Users(DisplayName, Location) INCLUDE (Reputation);
GO

SET STATISTICS IO, TIME ON;

 --  8:00 Because our index already sorts by DisplayName and Location
 --		  adding Reputation Key to our index (ordering at the third level)
 --		  wont help in the ORDER BY statement
SELECT Id, DisplayName, Location
    FROM dbo.Users WITH (INDEX = IX_DisplayName_Location_Reputation)
    WHERE DisplayName = 'alex'
        AND Location <> 'Seattle, WA'
  ORDER BY Reputation;

 -- Logical Reads - 4
 --		We can see that both queries use the same plan, despite one in the key and one in the includes
SELECT Id, DisplayName, Location
    FROM dbo.Users WITH (INDEX = IX_DisplayName_Location_Includes)
    WHERE DisplayName = 'alex'
        AND Location <> 'Seattle, WA'
  ORDER BY Reputation;
GO

-- Essentially, once we add an inequality search, it throws out the column key order...
-- So how do we get rid of that pesky sort in the plan?

/* ...Promote Reputation one level: 
	The plan now seeks to the alex's, sorted in order of reputation, and now just throws
	away the locations that arent required, which is easy as they are sorted!
*/
CREATE INDEX IX_DisplayName_Reputation_Location 
  ON dbo.Users(DisplayName, Reputation, Location);
GO

/* And the sort is gone: */
SELECT Id, DisplayName, Location
    FROM dbo.Users WITH (INDEX = IX_DisplayName_Reputation_Location)
    WHERE DisplayName = 'alex'
        AND Location <> 'Seattle, WA'
  ORDER BY Reputation;
GO

/* 14:45 - Will we use this trick a lot? Well no...
	However, as we layer more and more statements to the query 
	(eg. starting with WHERE equality searchs, then inequality searches, 
		 then adding ORDER BY, GROUP BY, HAVING, JOIN etc.
	can change the way SQL executes, or changes the way the data needs to be organised
*/

/* Which one does SQL Server pick? */
SELECT Id, DisplayName, Location
    FROM dbo.Users
    WHERE DisplayName = 'alex'
        AND Location <> 'Seattle, WA'
  ORDER BY Reputation;
GO


/* We've learnt that putting WHERE clause statements first may not be the best thing to do in every case,
   especially when it comes to inequality statements ...
   Does that mean we should *always* put equality statements at the start... think again (thanks to TOP)

*/

EXEC DropIndexes;
GO

/* The original query: */
SELECT TOP 100 Id, Reputation, CreationDate
    FROM dbo.Users
    WHERE Reputation > 1
    ORDER BY CreationDate ASC;
GO

-- Note: The top 100 people with the lowest Reputations 
-- are likely to be the newest users...
CREATE INDEX IX_Reputation_CreationDate
  ON dbo.Users(Reputation, CreationDate);

  -- The top 100 people with the earliest CreationDates (ie. early adopters and developers) 
-- are likely to have more than 1 reputation point...
CREATE INDEX IX_CreationDate_Reputation
  ON dbo.Users(CreationDate, Reputation);
GO


/* Test 'em */
SELECT TOP 100 Id, Reputation, CreationDate
    FROM dbo.Users WITH (INDEX = 1)
    WHERE Reputation > 1
    ORDER BY CreationDate ASC;

-- this one leads with reputation
-- for reputation 1, we we'll find the oldest creation dates
-- for reputation 2, we may find even older creation dates
-- for reputation 3, we may find creation dates that are older still!
-- etc. etc.
-- Reputation is not helpful to begin the ordering...
SELECT TOP 100 Id, Reputation, CreationDate
    FROM dbo.Users WITH (INDEX = IX_Reputation_CreationDate)
    WHERE Reputation > 1
    ORDER BY CreationDate ASC;

/*  Now ordered by CreationDate, we know from our data that 
	its highly likely (almost guaranteed) that the top 100 users will have a Reputation > 1
	While it results in a nasty old "scan" from the start of the table, 
	it stops when it reaches 100 records that match... This wont take too long
*/
SELECT TOP 100 Id, Reputation, CreationDate
    FROM dbo.Users WITH (INDEX = IX_CreationDate_Reputation)
    WHERE Reputation > 1
    ORDER BY CreationDate ASC;
GO

/* Check object sizes: */
SELECT COUNT(*)
    FROM dbo.Users WITH (INDEX = IX_Reputation_CreationDate);

SELECT COUNT(*)
    FROM dbo.Users WITH (INDEX = IX_CreationDate_Reputation);
GO



/* Let's say we call the below one the winner: */
DropIndexes;
GO
CREATE INDEX IX_CreationDate_Reputation
  ON dbo.Users(CreationDate, Reputation);
GO

/* Recap: Selectivity isnt about the layout of the data
	its also about looking at the contents of the queries

	A TOP is just like a WHERE clause... 
	When we say 
		'only give me 100 rows ORDERED BY CreationDate', 
	what we're saying is:
		'WHERE CreationDate is in the first set of rows for this data'

	In this case, the super selective WHERE clause filters down the set of data we need... 
	but only for this query... so lets go change the query
*/


/* The original query: */
SELECT TOP 100 Id, Reputation, CreationDate
    FROM dbo.Users
    WHERE Reputation > 1
    ORDER BY CreationDate ASC;

/* The new one looking for Jon Skeet: 
	However, the game changes when we have a WHERE clause with highly selective
	filter (ie. not many rows that match criteria), such as Reputation > 1000000
	Now it takes a lot more reads to scan the table from one end, to find 
	100 users with reputation > 1000000


*/
SELECT TOP 100 Id, Reputation, CreationDate
    FROM dbo.Users
    WHERE Reputation > 1000000
    ORDER BY CreationDate ASC;
GO

-- 	In this case, its makes sense for Reputation to go first!


/* The question is, which one do I want to optimise?
	The WHERE clause to reduce the records I read
	The ORDER BY clause to reduce the number of records I need to search by?

   Essentially, there are just 2 inequality searches...

	   SELECT TOP 100 Id, Reputation, CreationDate
	   FROM dbo.Users
	   WHERE REputation > 1000000
	   ORDER BY CreationDate ASC;

   Consider Stored Procs, where the engine has to build a single plan
   for any range of parameter values that it is given...
   How do we determine the plan that is best to use?
   Note that you may not handle every parameter value.
   The aim is to make an index that is 'good enough' to cover as many scenarios as you can

   - What has the higher IO load?
   - What parameters do you want to go fast (most commonly used, most interested in... comprimise on this)
   - What takes longer?
   - Which is used more?
   - What plan provides the best performance for the biggest range of values
   - Which is the lesser of the two evils?
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


-- Query
SELECT TOP 100 DisplayName, Location, WebsiteURL, Reputation, Id
FROM dbo.Users
WHERE Location <> '' AND WebsiteUrl <> ''
ORDER BY Reputation DESC


-- Index - CREATE IX_Website_Url_Location_Includes
SELECT WebsiteUrl, Location, Reputation, Id FROM dbo.Users ORDER BY WebsiteUrl, Location

-- Q1. How easy is it to find WebsiteUrl <> '' 
--	- Since NULL's aren't included, blanks are at the top of the list... quite easy
-- Q2. How easy is it to find Location <> '' given Q1?
--	- Likewise, since nulls are included and blanks are at the top of our list, quite easy
-- Q3. Of those, how easy is it to sort by reputation?
--	- Reputation points are scattered all over the place... our user with the highest reputation person could be all the way at the bottom of our list!
--	- Have to read almost all these rows, even though we only need the top 100! Ouch


-- Index - CREATE IX_Reputation_Includes
SELECT Reputation, WebsiteUrl, Location, DisplayName, Id FROM dbo.Users ORDER BY Reputation, WebsiteUrl, Location

-- Q1. If we sort by reputation, we have satisfied our order clause... 
--		how easy is it then to scan the rest of the index, and pick the top 100 entries
--		which don't have a WebsiteUrl or Location?
-- Q2. If we have an index that orders on Reputation, WebsiteURL, and Location.... harder than you think... 
--		- the data set tells us that not many people with a Reputation of 1 have a blank WebsiteURL AND Location!
--		- its actually quicker, and less expensive, to find the Top 100 rows when sorted only by Reputation (not inlcuding WebsiteURL and Location in the index key)

