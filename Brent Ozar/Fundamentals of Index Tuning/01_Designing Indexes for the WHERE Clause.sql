-- 1. Fundamentals of Indexing
   SET STATISTICS IO ON;
-- Display Actual Execution Plan


-- 01 Designing Indexes for the WHERE Clause
-- https://www.brentozar.com/training/fundamentals-of-index-tuning-instant-replay/01-designing-indexes-for-the-where-clause/

-- Note the recommendation from the Actual Execution Plan
-- The recommendation only states the DisplayName, which doesnt satisfy our query
-- However it only has a matter of milliseconds to make a decision, and therefore identifies
-- the Where clause first and foremost, perhaps spot a few other things if it's lucky, it will spot other
-- It's main job is to get you across the finish line to get query results, with missing index recommendations as a bonus
SELECT Id, DisplayName, Location FROM dbo.Users u WHERE u.DisplayName = 'alex' ;

-- Better, user created index.
-- Notice that it does not have Id key in the index, as it is already the clustering key in the table 
--		it's always going to be included whether its included or not 
--		the one time it will be included is if the Primary Key is changed to something else.... rare, but happens
CREATE INDEX IX_DisplayName_Includes ON dbo.Users(DisplayName) INCLUDE (Location) ;

-- Contents of the Index
-- ======================
-- Run this query and inspect Actual Execution Plan. If you did your job right,
-- you should see just an Index Scan in the visualisation... no sorts, no seeks
SELECT DisplayName, Location, Id FROM dbo.Users u ORDER BY DisplayName ;


-- Testing our problem query
-- =========================
-- Run this query again and inspect Actual Execution Plan. If you did your job right,
-- you should see just an Index Seek in the visualisation... no scans, no filtering
-- Seek isn't always the best for every query, but is the best for this query
SELECT Id, DisplayName, Location FROM dbo.Users u WHERE u.DisplayName = 'alex' ;

-- WHERE statement with 2 Equality Operators
-- =========================================
-- We need an Index for this, so how should the index be ordered?
-- Running this returns an Index Seek, which may jump ahead to the values of the first column (DisplayName = 'alex')
--		... but not necessarily to the 'alex's that live also live in 'Seattle, WA' (see selectivity below)
SELECT Id, DisplayName, Location  FROM dbo.Users  WHERE DisplayName = 'alex' AND Location = 'Seattle, WA';

	-- Lets look at query selectivity... while DisplayName appears to be 'more selective', selective doesnt necessarily
	-- mean the uniqueness of the column itself...
	SELECT COUNT(DISTINCT DisplayName) AS DistinctDisplayNames, COUNT(DISTINCT Location) AS DistinctLocations
	FROM dbo.Users ;


-- Decoding the Popup
---------------------
-- Hover over the Index Seek on the query, and examine the popup
--  (13:47) Seek Predicates (DisplayName)  
--		- It seeked directly into Alex, and it started reading then, but it read more rows than that.
--  (14:12) Estimated Number of Rows (4.29), Estimated Number of Rows to be Read (3488) 
--		- "I think there's going to be 3488 Alex's, and 4 of them live in Seattle, WA"
--  (14:31) Predicate (Location)
--		- On Location, but note that it doesn't have the word "seek" in front of it... this is called a residual predicate
--		- We 'seeked' to the Alex, but 'scanned' the rest of the rows

-- Visualise the Index
----------------------
-- Note that while our index finds all the Alex's, the Locations are all over the place
-- That means we'll need to read all of these rows whether they're in Seattle or not
SELECT DisplayName, Location FROM dbo.Users WHERE DisplayName = 'alex' 


-- Build the Index
------------------
-- Now what makes the most sense in terms of column order?
CREATE INDEX IX_DisplayName_Location ON dbo.Users(DisplayName, Location)
-- OR 
CREATE INDEX IX_Location_DisplayName ON dbo.Users(Location, DisplayName)

-- Test with Clustered Index
SELECT Id, DisplayName, Location FROM dbo.Users WITH (INDEX=1) WHERE DisplayName = N'alex' AND Location = N'Seattle, WA'

-- Test with DisplayName_Location
SELECT Id, DisplayName, Location FROM dbo.Users WITH (INDEX=IX_DisplayName_Location) WHERE DisplayName = N'alex' AND Location = N'Seattle, WA'

-- Test with Location_DisplayName
SELECT Id, DisplayName, Location FROM dbo.Users WITH (INDEX=IX_Location_DisplayName) WHERE DisplayName = N'alex' AND Location = N'Seattle, WA'

-- Results
-- =======
-- Clustered Index (white pages) - 45184
-- IX_DisplayName_Includes - 16
-- IX_DisplayName_Location - 4	*** Winner, but not by very much
-- IX_Location_DisplayName - 5

-- What Does SQL Pick?
-- ===================
-- Run query without hints
SELECT Id, DisplayName, Location FROM dbo.Users  WHERE DisplayName = N'alex' AND Location = N'Seattle, WA'

-- In this case it chose Location_DisplayName, even though this was not the query with the lowest logical reads above
-- However, this index works better for the query that was run earlier... 
-- While the chosen index may not be the best for this query, SQL optimiser has determined it's the best at covering MULTIPLE queries

-- WHERE with both equality and inequality searches
-- ================================================
-- Update the statement with an inequality operator (<>) on location
SELECT Id, DisplayName, Location 
FROM dbo.Users  WITH (INDEX = IX_DisplayName_Location) --(INDEX = IX_Location_DisplayName)
WHERE 
	DisplayName = N'alex' 
	AND Location <> N'Seattle, WA'

SELECT Id, DisplayName, Location 
FROM dbo.Users  WITH (INDEX = IX_Location_DisplayName)
WHERE 
	DisplayName = N'alex' 
	AND Location <> N'Seattle, WA'

-- Using IX_DisplayName_Location - Seeks to all the 'Alex's', then reads all the Location's that arent Seattle (13 logical reads, 703 rows read)
-- Using IX_Location_DisplayName - Scans through Location's that aren't Seattle, and then read through the display names for Alex's! (4566 logical reads, 586161 rows read!)
--   Why? 
--		- We can't just jump to Alex's... sorted by location, he's scattered throughout the entire index! 
--		- We can't seek to Seattle, because we're looking for everything other than Seattle!
--		- LSS, we're going to have to scan most of the index!
--		- Also note the difference of sizes between the arrows on each plan (not the count of the rows returned)

-- Seek Predicates
--=================
--	 On both queries, the SQL engine will 
--		1. "Seek" to the start 'Seattle, WA' and start reading backwards...
--		2. "Seek" to the end of 'Seattle, WA' and start reading forwards...
--	Not terribly efficient

-- Q: Is it true then that an equality search will always hold a preference than inequality search
--		when selecting the index?
--	  Therefore, is it always the case that equality search fields go first?
-- A: Not necessarily, but its a good starting point

-- Selectivity
-- ===========
-- Selectivity is relative to the WHERE clause, not necessarily the content of the table
--	eg. We know based on our data that:
--		1. SELECT * FROM EventJob WHERE EventJobID < 0 -- will always return a 0
--		2. SELECT * FROM EventJob WHERE Created > GETDATE() -- will also return 0, can't create something in the future

--	Summary
-- ========
--  - A WHERE statement with only equality searches - Field order doesn't necessarily matter
--  - A WHERE statement with only inequality searches - Field order matters
--  - Usually, WHERE statements go first (but not always the case, as we'll see shortly)

