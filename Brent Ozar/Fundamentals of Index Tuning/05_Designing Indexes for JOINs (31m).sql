/*
Fundamentals of Index Tuning: JOIN Clauses

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

/* Get the estimated plan: 

	Query with 1 Join, no filtering - Likelihood: Low 
	No WHERE clause, so will scan both tables... 
		Q. Which one does it scan first?
		A. Table with the fewer records
*/
SELECT u.DisplayName, c.CreationDate, c.Text
  FROM dbo.Users u
  INNER JOIN dbo.Comments c
    ON u.Id = c.UserId;
GO

/* The Optimiser identifies that the Comments table is harder to traverse...
	it recommends placing an index on the comments table, sorted by UserId
	However, the optimiser is smoking crack (lol) because it also has an INCLUDE
	for the Text field!!! WHY???
*/


/* Let's try a more realistic query first: add a WHERE clause
	The execution plan scans the Users tables to find all the ID's with the Display Name of 'Brent Ozar'
	Then it scans the comments table, doing a look up the UserId's it found in the Users table (ie. WHERE UserId = X)

	In a sense, a JOIN is just a WHERE clause, where the RHS is another query set:
		eg. */
		SELECT c.* FROM dbo.Comments c WHERE UserId IN (SELECT UserID FROM dbo.Users WHERE DisplayName = 'Brent Ozar')

SELECT u.DisplayName, c.CreationDate, c.Text
  FROM dbo.Users u
  INNER JOIN dbo.Comments c
    ON u.Id = c.UserId
  WHERE u.DisplayName = 'Brent Ozar'
GO
/* Do we need an index on Users? On what fields?
   Do we need an index on Comments? On what fields?
*/

CREATE INDEX IX_DisplayName ON dbo.Users(DisplayName);
CREATE INDEX IX_UserId ON dbo.Comments(UserId);
GO

/* Then try again. Does the query use our indexes? */
SELECT u.DisplayName, c.CreationDate, c.Text
  FROM dbo.Users u
  INNER JOIN dbo.Comments c
    ON u.Id = c.UserId
  WHERE u.DisplayName = 'Brent Ozar';
GO


/* Getting a little more complex, adding ORDER BY
	Note that the execution plan has a sort inside... 
	is this due to the ORDER BY CreationDate statement?
: */
SELECT u.DisplayName, c.CreationDate, c.Text
  FROM dbo.Users u
  INNER JOIN dbo.Comments c
    ON u.Id = c.UserId
  WHERE u.DisplayName = 'Brent Ozar'
  ORDER BY c.CreationDate;
GO


/* Does a separate index on CreationDate help? */
CREATE INDEX IX_CreationDate ON dbo.Comments(CreationDate);
GO
SELECT u.DisplayName, c.CreationDate, c.Text
  FROM dbo.Users u
  INNER JOIN dbo.Comments c
    ON u.Id = c.UserId
  WHERE u.DisplayName = 'Brent Ozar'
  ORDER BY c.CreationDate;
GO


/* What if we widen up the index on UserId, CreationDate? 
	Wait a sec... there's still a sort, but I think I see why...
	Unfortunately, DisplayName returns multiple user ID's for DisplayName  = 'Brent Ozar'
	Therefore it will do multiple seeks to each of these user ID's (
		ie. SELECT UserID from User where DisplayName = 'Brent Ozar' )
	Once it's done that, we need to order these by CreationDate...
	this wasn't so bad with only 1 userID...
	Now we're dealing with multiple UserID's, we need to resort our data sets,
	because the CreationDate's will vary across multiple UserId's
	
*/
CREATE INDEX IX_UserId_CreationDate ON dbo.Comments(UserId, CreationDate);
GO
SELECT u.DisplayName, c.CreationDate, c.Text
  FROM dbo.Users u
  INNER JOIN dbo.Comments c
    ON u.Id = c.UserId
  WHERE u.DisplayName = 'Brent Ozar'
  ORDER BY c.CreationDate;
GO


/* To understand why, use a different user name and show the User.Id: */
SELECT u.DisplayName, u.Id, c.CreationDate, c.Text
  FROM dbo.Users u
  INNER JOIN dbo.Comments c
    ON u.Id = c.UserId
  WHERE u.DisplayName = 'JamesBrownIsDead'
  ORDER BY c.CreationDate;
GO


/* However, is the sort so bad? Without the Index, we were doing
	1079417 reads... with index on Comments.UserId. 46012
	Now with index on Users.DisplayName, we're down to 583, even with the sort in place

	Even with a sort in place, it's still a substantial improvement.
	We should be aiming to make things 'good enough for most cases'
	Cut it off once we hit our expectations, or else suffer diminishing returns
*/


DropIndexes;
GO


/* 12:35 - Mixing Joins and Filters */

/* Does it matter where we put filters, the JOIN or the WHERE? 
	
	13:!6 In this case they're effectively the same thing.
	SQL Server has the same work to do. It event reverse engineers
	the query plan and produces the same plan regardless
*/
-- In the Join
SELECT u.DisplayName, u.Id, c.CreationDate, c.Text
  FROM dbo.Users u
  INNER JOIN dbo.Comments c
                ON u.Id = c.UserId
                AND c.Score > 0
  WHERE u.DisplayName = 'JamesBrownIsDead'
  ORDER BY c.CreationDate;

 -- In the Where clause
SELECT u.DisplayName, u.Id, c.CreationDate, c.Text
  FROM dbo.Users u
  INNER JOIN dbo.Comments c
                ON u.Id = c.UserId
  WHERE u.DisplayName = 'JamesBrownIsDead'
    AND c.Score > 0
  ORDER BY c.CreationDate;
GO

/* Writing the query any which way shouldnt matter... but it does
	It does in the case where we try to tack on lots of joins
*/





DropIndexes;
GO
/* We want the question, answer to the question, text of the question, and the upvotes
	16:32 - With a where statement on the users and the Posts (Questions) table,
		what does SQL server process first?
	A: 
		1. Scans the user table to find the Brent Ozars
		2. Scans the comments table to find the comments
		3. Scans the Posts to find the answers
		4. Scans the Posts table to find the questions

		This replicates the order of the join query, but only by coincidence
*/
SELECT Question.Id AS QuestionId, Question.Title, Answer.Body, c.Text, c.Score
  FROM dbo.Users u
    INNER JOIN dbo.Comments c ON u.Id = c.UserId
    INNER JOIN dbo.Posts Answer ON c.PostId = Answer.Id
    INNER JOIN dbo.Posts Question ON Answer.ParentId = Question.Id
  WHERE u.DisplayName = 'Brent Ozar'
    AND Question.Title LIKE 'SQL Queries%';
GO

/*	What really determines this? Selectivity...  
	18:00 When SQL Server has to figure out what to do first,
	it's not just about how many rows match (eg. SELECT color FROM Trees WHERE color = 'yellow')
	it's also how big is the forest (eg. SELECT COUNT(*) FROM Trees)

	... we're constantly filtering for different things in different tables, inside the 
	same query

	It comes down to
		- how selective the filters are
		- indexes in place
		- order of how the data is returned...

	etc.
*/
SELECT COUNT(*) FROM dbo.Users WHERE DisplayName = 'Brent Ozar'; -- 45k 8k page reads
SELECT COUNT(*) FROM dbo.Posts WHERE Title LIKE 'SQL Queries%'; -- 4mil 8k page reads!!!
GO




/* Try rewriting the query in the opposite order, with Questions first. 
	Turns out that it still does the same thing. SQL still considers the Users
	table to be the most selective, therefore processes first

*/
SELECT Question.Id AS QuestionId, Question.Title, Answer.Body, c.Text, c.Score
  FROM dbo.Posts Question
    INNER JOIN dbo.Posts Answer ON Question.Id = Answer.ParentId
    INNER JOIN dbo.Comments c ON Answer.Id = c.PostId
    INNER JOIN dbo.Users u ON c.UserId = U.Id
  WHERE Question.Title LIKE 'SQL Queries%'
    AND u.DisplayName = 'Brent Ozar';
GO

/* Create an index on Posts.Title to make that part of the filtering easier
	Now we have an index that makes the Question table super selective, and easier
	to filter through

	Note: SQL's suggested index was an against the comments table, even though we didn't
	ask to filter on the comments table... However, the join itself ( Answer.Id = c.PostId )
	IS a filter on the comments table
*/
CREATE INDEX IX_Title ON dbo.Posts(Title);
GO

/* Does that change which table gets processed first? 
	Same syntax, now with the index...

	What we thought would happen:

	1. Find Questions where Title like '%SQL Queries%'
	2. Find the Answers of those Questions
	3. Find the Comments on those Answers
	4. Look up the users for each of those comments and check if they're Brent Ozar
*/
SELECT Question.Id AS QuestionId, Question.Title, Answer.Body, c.Text, c.Score
  FROM dbo.Posts Question
    INNER JOIN dbo.Posts Answer ON Question.Id = Answer.ParentId
    INNER JOIN dbo.Comments c ON Answer.Id = c.PostId
    INNER JOIN dbo.Users u ON c.UserId = U.Id
  WHERE Question.Title LIKE 'SQL Queries%'
    AND u.DisplayName = 'Brent Ozar';
GO

/* Not the case, what acutually happened??
	1. Find question where Title like 'SQL Queries%'
	Meanwhile, AT THE SAME TIME (Parallelism)
	1. Find users named Brent Ozar
	2. Find the comments they've left
	3. Look up what Answers they were placed on
	4. Finally, join this to the SQL query questions
*/

CREATE INDEX IX_UserId ON dbo.Comments(UserId);
GO
SELECT Question.Id AS QuestionId, Question.Title, Answer.Body, c.Text, c.Score
  FROM dbo.Posts Question
    INNER JOIN dbo.Posts Answer ON Question.Id = Answer.ParentId
    INNER JOIN dbo.Comments c ON Answer.Id = c.PostId
    INNER JOIN dbo.Users u ON c.UserId = U.Id
  WHERE Question.Title LIKE 'SQL Queries%'
    AND u.DisplayName = 'Brent Ozar';
GO

/* If we index everything we see in the query...

	Add Index on Posts.Title - 1,077,063 Logical Reads
	Plus Index on Comments.UserId - 46,600 Logical Reads
	Plus Index on Users.DisplayName - 1165 Logical Reads

	Or start over again, and add index only on Comments.UserId - 47,373 Logical reads

	As we can see, the join on the Comments is where the real hard work sits...
	fewer indexes for the same / similar impact!

	While the WHERE clause is where we pay the most attention, remember that the JOIN
	is effectively a WHERE clause... we may find that the hardest work sits there
*/

CREATE INDEX IX_DisplayName ON dbo.Users(DisplayName);
GO
SELECT Question.Id AS QuestionId, Question.Title, Answer.Body, c.Text, c.Score
  FROM dbo.Posts Question
    INNER JOIN dbo.Posts Answer ON Question.Id = Answer.ParentId
    INNER JOIN dbo.Comments c ON Answer.Id = c.PostId
    INNER JOIN dbo.Users u ON c.UserId = U.Id
  WHERE Question.Title LIKE 'SQL Queries%'
    AND u.DisplayName = 'Brent Ozar';
GO



/* Index your foreign keys
25:00	This advice is only useful when they're actually used
		in the joins

		Index 5x5 Rule - 5 indexes per table, no more than 5 columns for each
		- keep in mind, no hard and fast rules... Indexing is a game of comprimise!!!

		When you first build a table, create a clustered index, then an index
		based on foreign key relationships
*/


/* WHERE EXISTS 
	Q. What indexes do I need on these tables?
*/


DropIndexes;
GO

SELECT *
  FROM dbo.Users u
  WHERE u.Location = 'Antarctica'
  AND EXISTS (SELECT * FROM dbo.Comments c WHERE u.Id = c.UserId);
GO

/* SQL Server's thought process:
	1. Easy to scan the small User's table to find LOCATION = 'Antarctica'...
	2. Once I have their user ID's, its gonna be painful to scan the giant friggin
		Comments table to find their comments
	3. Most efficient index in this case would be on Comments.UserId
*/

CREATE INDEX IX_UserId ON dbo.Comments(UserId);
GO
SELECT *
  FROM dbo.Users u
  WHERE u.Location = 'Antarctica'
  AND EXISTS (SELECT * FROM dbo.Comments c WHERE u.Id = c.UserId);
GO
/* Ok, now we apply the index... now Clippy tells us we need an index on Location
	which is fine...
	It also asks for an Include on absolutely everything! This is not required,
	as a Key Lookup will be sufficient because... 
		- There is little difference in performance between the two operations
		- Storage overhead of including these in the index is massive

	The index on Location is created
*/
CREATE INDEX IX_Location ON dbo.Users(Location);
GO
SELECT *
  FROM dbo.Users u
  WHERE u.Location = 'Antarctica'
  AND EXISTS (SELECT * FROM dbo.Comments c WHERE u.Id = c.UserId);
GO

/*
30:24 Joins are interesting

Joins are like filters: 
	- only show me the rows from Table1 that have a matching partner in Table2
	- Their selectivity isnt just about row count, also size of the tabel

Join operations can benefit from pre-sorting:
	- If I want to join two tables together, it can help if they're already stored in order
	- Join supported indexes radically change plan shape.

"Joins are a lot like filters. We dont usually think of joins as filters that we
want to index - we usually look to the where clause as the first things we want to index
but it turns out that joining lots of tables together, especially joining large tables,
are the most expensive parts of the query plan"
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