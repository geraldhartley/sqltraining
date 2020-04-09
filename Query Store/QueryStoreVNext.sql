-- TUTORIAL: The Query Store and Query Tuning in SQL Server - https://www.youtube.com/watch?v=TlanVeGci8s


USE AdventureWorks2014;
GO

ALTER DATABASE AdventureWorks2014 SET QUERY_STORE = ON;


--CREATE OR ALTER PROC dbo.AddressByCity 
--	@City NVARCHAR(30)
--AS
--	SELECT
--		a.AddressId,
--		a.AddressLine1,
--		a.AddressLine2,
--		sp.Name,
--		a.PostalCode
--	FROM Person.Address AS a
--	JOIN Person.StateProvince AS sp
--		ON a.StateProvinceID = sp.StateProvinceID
--	WHERE a.City = @City ;



EXEC dbo.AddressByCity
    @City = N'London';



SELECT  qsq.query_id,
        qsqt.query_text_id,
        qsqt.query_sql_text
FROM    sys.query_store_query AS qsq
JOIN    sys.query_store_query_text AS qsqt
        ON qsqt.query_text_id = qsq.query_text_id;









ALTER DATABASE AdventureWorks2014 SET QUERY_STORE = OFF;



SELECT  qsq.query_id,
        qsqt.query_text_id,
        qsqt.query_sql_text
FROM    sys.query_store_query AS qsq
JOIN    sys.query_store_query_text AS qsqt
        ON qsqt.query_text_id = qsq.query_text_id;



SELECT  *
FROM    Sales.SalesOrderHeader AS soh
JOIN    Sales.SalesOrderDetail AS sod
        ON sod.SalesOrderID = soh.SalesOrderID
WHERE   sod.SalesOrderID = 49386;




SELECT  qsq.query_id,
        qsqt.query_text_id,
        qsqt.query_sql_text
FROM    sys.query_store_query AS qsq
JOIN    sys.query_store_query_text AS qsqt
        ON qsqt.query_text_id = qsq.query_text_id;



ALTER DATABASE AdventureWorks2014 SET QUERY_STORE CLEAR;



SELECT  qsq.query_id,
        qsqt.query_text_id,
        qsqt.query_sql_text
FROM    sys.query_store_query AS qsq
JOIN    sys.query_store_query_text AS qsqt
        ON qsqt.query_text_id = qsq.query_text_id;




ALTER DATABASE AdventureWorks2014 SET QUERY_STORE = ON;










--gather data about query store
SELECT * FROM sys.database_query_store_options AS dqso



--modify query store behavior

ALTER DATABASE AdventureWorks2014 SET QUERY_STORE (MAX_STORAGE_SIZE_MB = 200);
 


ALTER DATABASE AdventureWorks2014 SET QUERY_STORE (MAX_PLANS_PER_QUERY = 20);





--before a planned reboot
--writes in-memory information to disk
EXEC sys.sp_query_store_flush_db;





--back to slides











--query stats
EXEC dbo.AddressByCity
    @City = N'London';





SELECT  *
FROM    sys.query_store_query AS qsq
JOIN    sys.query_store_query_text AS qsqt
        ON qsqt.query_text_id = qsq.query_text_id;




-- 30:50
-- Can pull together interesting information like query_parameterization_type, number of compiles, last exectuion time, optimization duration
SELECT  qsqt.query_sql_text,
        qsqt.statement_sql_handle,
        qsq.object_id,
        qsq.query_parameterization_type_desc,
        qsq.last_execution_time,
        qsq.count_compiles,
        qsq.avg_optimize_duration,
        qsq.avg_compile_duration
FROM    sys.query_store_query AS qsq
JOIN    sys.query_store_query_text AS qsqt
        ON qsqt.query_text_id = qsq.query_text_id;


--31:35
-- Can combine with DMV query stats from cache... not many reasons why you want to, but you can?
SELECT  deqs.last_execution_time,
        qsqt.query_sql_text
FROM    sys.query_store_query AS qsq
JOIN    sys.query_store_query_text AS qsqt
        ON qsqt.query_text_id = qsq.query_text_id
JOIN    sys.dm_exec_query_stats AS deqs
        ON qsqt.statement_sql_handle = deqs.statement_sql_handle;













-- 34:26
-- In some cases, this may show multiple rows for a single plan... perhaps there may be more than one plan for a given query?
-- Perhaps this ran in two different time intervals?
select qsqt.query_sql_text,
        qsq.avg_compile_duration,
        CAST(qsp.query_plan AS XML), -- may cause a problem if we have a nested plan so deep that we can't parse
		qsp.query_plan,
        qsrs.execution_type_desc,
        qsrs.count_executions,
        qsrs.avg_duration,
        qsrs.min_duration,
        qsrs.max_duration,
        qsrs.avg_cpu_time,
        qsrs.avg_logical_io_reads,
        qsrs.avg_logical_io_writes,
        qsrs.avg_physical_io_reads,
        qsrs.avg_query_max_used_memory,
        qsrs.avg_rowcount
FROM    sys.query_store_query AS qsq
JOIN    sys.query_store_query_text AS qsqt
        ON qsqt.query_text_id = qsq.query_text_id
JOIN    sys.query_store_plan AS qsp
        ON qsp.query_id = qsq.query_id
JOIN    sys.query_store_runtime_stats AS qsrs
        ON qsrs.plan_id = qsp.plan_id
WHERE   qsq.object_id = OBJECT_ID('dbo.AddressByCity');




--Workaround
SELECT qsqt.query_sql_text,
        qsq.avg_compile_duration,
        qsp.query_plan,
        qsrs.execution_type_desc,
        qsrs.count_executions,
        qsrs.avg_duration,
        qsrs.min_duration,
        qsrs.max_duration,
        qsrs.avg_cpu_time,
        qsrs.avg_logical_io_reads,
        qsrs.avg_logical_io_writes,
        qsrs.avg_physical_io_reads,
        qsrs.avg_query_max_used_memory,
        qsrs.avg_rowcount
		INTO #Buffer
FROM    sys.query_store_query AS qsq
JOIN    sys.query_store_query_text AS qsqt
        ON qsqt.query_text_id = qsq.query_text_id
JOIN    sys.query_store_plan AS qsp
        ON qsp.query_id = qsq.query_id
JOIN    sys.query_store_runtime_stats AS qsrs
        ON qsrs.plan_id = qsp.plan_id
WHERE   qsq.object_id = OBJECT_ID('dbo.AddressByCity')


SELECT CAST(b.query_plan AS XML), *
FROM #Buffer AS b


DROP TABLE #Buffer;





EXEC dbo.AddressByCity
    @City = N'Mentor'




SELECT * FROM sys.query_store_runtime_stats AS qsrs

SELECT * FROM sys.query_context_settings AS qcs




--finding a query
--35:00 - One snag... tracking down individual queries can be a pain in the butt. Microsoft kindly gave us a system function to help us narrow down:
--	sys.fn_stmt_sql_handle_from_sql_stmt
SELECT  qt.query_text_id,
        q.query_id,
        qt.query_sql_text,
        qt.statement_sql_handle,
        q.context_settings_id,
        qs.statement_context_id
FROM    sys.query_store_query_text AS qt
JOIN    sys.query_store_query AS q
        ON qt.query_text_id = q.query_id
CROSS APPLY sys.fn_stmt_sql_handle_from_sql_stmt(qt.query_sql_text, NULL) AS fn_handle_from_stmt
JOIN    sys.dm_exec_query_stats AS qs
        ON fn_handle_from_stmt.statement_sql_handle = qs.statement_sql_handle;




--these values are the same, plus I used the qsq.query_parameterization_type....
SELECT  qsqt.statement_sql_handle,
        fsshfss.statement_sql_handle,
        deqs.statement_sql_handle,
        qsqt.query_sql_text
FROM    sys.query_store_query AS qsq
JOIN    sys.query_store_query_text AS qsqt
        ON qsqt.query_text_id = qsq.query_text_id
LEFT JOIN sys.dm_exec_query_stats AS deqs
        ON qsqt.statement_sql_handle = deqs.statement_sql_handle
CROSS APPLY sys.fn_stmt_sql_handle_from_sql_stmt(qsqt.query_sql_text,
                                                 qsq.query_parameterization_type)
        AS fsshfss;



-- 36:29 - ad hoc query that now should end up in query store
SELECT  e.NationalIDNumber,
        p.LastName,
        p.FirstName,
        a.City,
        bea.AddressTypeID
FROM    HumanResources.Employee AS e
JOIN    Person.BusinessEntityAddress AS bea
        ON bea.BusinessEntityID = e.BusinessEntityID
JOIN    Person.Address AS a
        ON a.AddressID = bea.AddressID
JOIN    Person.Person AS p
        ON p.BusinessEntityID = e.BusinessEntityID
WHERE   p.LastName = 'Hamilton';


-- retrieve the information based on the query
SELECT * FROM sys.query_store_query_text AS qsqt
WHERE qsqt.query_sql_text = 'SELECT  e.NationalIDNumber,
        p.LastName,
        p.FirstName,
        a.City,
        bea.AddressTypeID
FROM    HumanResources.Employee AS e
JOIN    Person.BusinessEntityAddress AS bea
        ON bea.BusinessEntityID = e.BusinessEntityID
JOIN    Person.Address AS a
        ON a.AddressID = bea.AddressID
JOIN    Person.Person AS p
        ON p.BusinessEntityID = e.BusinessEntityID
WHERE   p.LastName = ''Hamilton''';




--39:00 
-- 1. If we run this, it wont appear in the QS query text table below
-- 2. Run this again with actual execution plan, open Properties on the SELECT Cost node:
--		Q. Notice the @1 in the Parameter List - despite the fact this is an ad-hoc query with a trivial plan?
--		A. Based on the hardcoded parameter, the optimiser decides to use 'simple parameterisation' to parameterise the value,
--		so that it doesn't have to compile it each time (smart!)
SELECT  *
FROM    Production.BillOfMaterials AS bom
WHERE   bom.BillOfMaterialsID = 2363;


-- The above query isn't showing? Why is that? (answer in 2. above)
SELECT  *
FROM    sys.query_store_query_text AS qsqt
WHERE   qsqt.query_sql_text = 'SELECT  *
FROM    Production.BillOfMaterials AS bom
WHERE   bom.BillOfMaterialsID = 2363';



-- 41:00 Now we can see 
SELECT  qsqt.*
FROM    sys.query_store_query_text AS qsqt
JOIN    sys.query_store_query AS qsq
        ON qsq.query_text_id = qsqt.query_text_id
CROSS APPLY sys.fn_stmt_sql_handle_from_sql_stmt('SELECT  *
FROM    Production.BillOfMaterials AS bom
WHERE   bom.BillOfMaterialsID = 2363;', qsq.query_parameterization_type) AS fsshfss;





SELECT  qsqt.*
FROM    sys.query_store_query_text AS qsqt
JOIN    sys.query_store_query AS qsq
        ON qsq.query_text_id = qsqt.query_text_id
WHERE   qsq.object_id = OBJECT_ID('dbo.AddressByCity');



-- 42:30 the one place microsoft has shot us in the foot....
SELECT  *
FROM    sys.query_store_query_text AS qsqt
WHERE   qsqt.query_sql_text LIKE '%SELECT  a.AddressID,
        a.AddressLine1,
        a.AddressLine2,
        a.City,
        sp.Name AS StateProvinceName,
        a.PostalCode
FROM    Person.Address AS a
JOIN    Person.StateProvince AS sp
        ON a.StateProvinceID = sp.StateProvinceID
WHERE   a.City = @City%'



-- still nothing
SELECT  qsqt.*
FROM    sys.query_store_query_text AS qsqt
CROSS APPLY sys.fn_stmt_sql_handle_from_sql_stmt('SELECT  a.AddressID,
        a.AddressLine1,
        a.AddressLine2,
        a.City,
        sp.Name AS StateProvinceName,
        a.PostalCode
FROM    Person.Address AS a
JOIN    Person.StateProvince AS sp
        ON a.StateProvinceID = sp.StateProvinceID
WHERE   a.City = @City;', NULL) AS fsshfss


-- Change '=' to 'LIKE', add some '%' aaand....
-- 44:04 - all because it doesnt work for stored procedures... only forced parameterisation or simple parameterisation...
--			for stored procs, need to use the 'LIKE' statement
SELECT  qsqt.*
FROM    sys.query_store_query_text AS qsqt
WHERE qsqt.query_sql_text LIKE '%SELECT  a.AddressID,
        a.AddressLine1,
        a.AddressLine2,
        a.City,
        sp.Name AS StateProvinceName,
        a.PostalCode
FROM    Person.Address AS a
JOIN    Person.StateProvince AS sp
        ON a.StateProvinceID = sp.StateProvinceID
WHERE   a.City = @City%';













--seeing different plans for a query
EXEC dbo.AddressByCity
    @City = N'London';



DECLARE @PlanHandle VARBINARY(64)

SELECT @PlanHandle = deqs.plan_handle 
FROM sys.dm_exec_query_stats AS deqs
CROSS APPLY sys.dm_exec_sql_text(deqs.sql_handle) AS dest
WHERE dest.text LIKE 'CREATE PROC dbo.AddressByCity%'

IF @PlanHandle IS NOT NULL
    BEGIN
        DBCC FREEPROCCACHE(@PlanHandle);
    END
GO


EXEC dbo.AddressByCity
    @City = N'Mentor';



SELECT  qsq.query_id,
        qsqt.query_text_id,
        qsqt.query_sql_text,
		qsp.query_plan,
		qsp.last_execution_time,
		qsq.avg_compile_duration
--INTO #Buffer
FROM    sys.query_store_query AS qsq
JOIN    sys.query_store_query_text AS qsqt
        ON qsqt.query_text_id = qsq.query_text_id
		JOIN sys.query_store_plan AS qsp
		ON qsp.query_id = qsq.query_id
WHERE qsq.object_id = OBJECT_ID('dbo.AddressByCity');

SELECT CAST(b.query_plan AS XML),* 
FROM #Buffer AS b

DROP TABLE #Buffer









-- take control of query store
DECLARE @PlanID INT;

SELECT TOP 1
        @PlanID = qsp.plan_id
FROM    sys.query_store_query AS qsq
JOIN    sys.query_store_plan AS qsp
        ON qsp.query_id = qsq.query_id
WHERE   qsq.object_id = OBJECT_ID('dbo.AddressByCity');

-- reset stats of  a given plan
EXEC sys.sp_query_store_reset_exec_stats
    @plan_id = @PlanID;



DECLARE @queryid INT 

SELECT  @queryid = qsq.query_id
FROM    sys.query_store_query_text AS qsqt
JOIN    sys.query_store_query AS qsq
        ON qsq.query_text_id = qsqt.query_text_id
WHERE   qsqt.query_sql_text = 'SELECT  e.NationalIDNumber,
        p.LastName,
        p.FirstName,
        a.City,
        bea.AddressTypeID
FROM    HumanResources.Employee AS e
JOIN    Person.BusinessEntityAddress AS bea
        ON bea.BusinessEntityID = e.BusinessEntityID
JOIN    Person.Address AS a
        ON a.AddressID = bea.AddressID
JOIN    Person.Person AS p
        ON p.BusinessEntityID = e.BusinessEntityID
WHERE   p.LastName = ''Hamilton'''

-- remove query - maybe its a mess, perhaps sensitive information
EXEC sys.sp_query_store_remove_query
    @query_id = @queryid;






DECLARE @PlanID INT;

SELECT TOP 1
        @PlanID = qsp.plan_id
FROM    sys.query_store_query AS qsq
JOIN    sys.query_store_plan AS qsp
        ON qsp.query_id = qsq.query_id
WHERE   qsq.object_id = OBJECT_ID('dbo.AddressByCity');

-- remove a plan
EXEC sys.sp_query_store_remove_plan @plan_id =@PlanID;








--GUI






-- Statistics related to Query Store
SELECT  *
FROM    sys.dm_os_wait_stats AS dows
WHERE   dows.wait_type LIKE '%qds%';













--GUI & ex events







--in memory
--sys.sp_xtp_control_query_exec_stats 


--SELECT  qsp.force_failure_count,
--        qsp.last_force_failure_reason_desc
--FROM    sys.query_store_plan AS qsp





--back to slides




--plan forcing


EXEC dbo.AddressByCity
    @City = N'London';



DECLARE @PlanHandle VARBINARY(64)

SELECT @PlanHandle = deqs.plan_handle 
FROM sys.dm_exec_query_stats AS deqs
CROSS APPLY sys.dm_exec_sql_text(deqs.sql_handle) AS dest
WHERE dest.text LIKE 'CREATE PROC dbo.AddressByCity%'

IF @PlanHandle IS NOT NULL
    BEGIN
        DBCC FREEPROCCACHE(@PlanHandle);
    END
GO


EXEC dbo.AddressByCity
    @City = N'Mentor';



EXEC dbo.AddressByCity
    @City = N'London';





-- Here we can see different plans
	-- If London is done, it uses a merge plan (returns 400 values)
	-- If the city of Mentor is done, it causes a loops plan (returns 2)
	-- Therefore behaviour changes... 
	--	The plan for 'London' works well for London, but not for any of the rest of our data...
	--	The plan for '%Mentor%' works better for all other scenarios (other than London)


-- Same Query ID (76), different plan_id's (76,120)
SELECT  qsq.query_id,
        qsqt.query_text_id,
		qsp.plan_id,
        qsqt.query_sql_text,
		--CAST(qsp.query_plan AS XML),
		qsp.last_execution_time,
		qsq.avg_compile_duration
FROM    sys.query_store_query AS qsq
JOIN    sys.query_store_query_text AS qsqt
        ON qsqt.query_text_id = qsq.query_text_id
		JOIN sys.query_store_plan AS qsp
		ON qsp.query_id = qsq.query_id
WHERE qsq.object_id = OBJECT_ID('dbo.AddressByCity');





DECLARE @PlanHandle VARBINARY(64)

SELECT @PlanHandle = deqs.plan_handle 
FROM sys.dm_exec_query_stats AS deqs
CROSS APPLY sys.dm_exec_sql_text(deqs.sql_handle) AS dest
WHERE dest.text LIKE 'CREATE PROC dbo.AddressByCity%'

IF @PlanHandle IS NOT NULL
    BEGIN
        DBCC FREEPROCCACHE(@PlanHandle);
    END
GO


EXEC dbo.AddressByCity
    @City = N'Mentor';



EXEC dbo.AddressByCity
    @City = N'London';






-- Same Query ID (76), different plan_id's (76,120)
EXEC sys.sp_query_store_force_plan 976,1072;








SELECT  qsq.query_id,
        qsp.plan_id--,
        --CAST(qsp.query_plan AS XML) AS sqlplan
FROM    sys.query_store_query AS qsq
JOIN    sys.query_store_plan AS qsp
        ON qsp.query_id = qsq.query_id
WHERE   qsq.object_id = OBJECT_ID('dbo.AddressByCity');








--undoing plan forcing
EXEC sys.sp_query_store_unforce_plan 2,781;



DECLARE @PlanHandle VARBINARY(64)

SELECT @PlanHandle = deqs.plan_handle 
FROM sys.dm_exec_query_stats AS deqs
CROSS APPLY sys.dm_exec_sql_text(deqs.sql_handle) AS dest
WHERE dest.text LIKE 'CREATE PROC dbo.AddressByCity%'

IF @PlanHandle IS NOT NULL
    BEGIN
        DBCC FREEPROCCACHE(@PlanHandle);
    END
GO


EXEC dbo.AddressByCity
    @City = N'London';




--gui




