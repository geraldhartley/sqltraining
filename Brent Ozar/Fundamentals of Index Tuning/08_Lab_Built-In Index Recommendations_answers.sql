/*
Missing Index Details from 08_Lab_Built-In Index Recommendations.sql - (local)\sql2019_local.StackOverflow2013 (CITYCARE\hartleyg (76))
The Query Processor estimates that implementing the following index could improve the query cost by 36.6754%.
*/

-- ======
-- Badges
-- ======

USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX IX_UserId_Name_Date
ON [dbo].[Badges] ([UserId], [Name], [Date])
GO

USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX IX_Name_UserId_Date
ON [dbo].[Badges] ([Name], [UserId],  [Date])
GO

/*
USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Badges] ([Date])
INCLUDE ([Name],[UserId])
GO
*/

/*
USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Badges] ([Date])
INCLUDE ([Name],[UserId])
GO
*/

/*
USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Badges] ([Date])
INCLUDE ([Name],[UserId])
GO
*/

/*
USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Badges] ([Name])
INCLUDE ([UserId])
GO
*/


-- ======
-- Posts
-- ======


USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX IX_PostTypeId_Tags_OwnerUserId_Score_Includes
ON [dbo].[Posts] ([PostTypeId], [Tags], [OwnerUserId], [Score])
INCLUDE ([Title],[ViewCount],[AnswerCount])
GO



/*
USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Posts] ([PostTypeId])
INCLUDE ([Score],[Tags],[Title],[ViewCount])
GO
*/


/*
USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Posts] ([Score])
INCLUDE ([OwnerUserId],[PostTypeId],[Tags])
GO
*/

/*
USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Posts] ([OwnerUserId],[Score])
INCLUDE ([AcceptedAnswerId],[AnswerCount],[Body],[ClosedDate],[CommentCount],[CommunityOwnedDate],[CreationDate],[FavoriteCount],[LastActivityDate],[LastEditDate],[LastEditorDisplayName],[LastEditorUserId],[ParentId],[PostTypeId],[Tags],[Title],[ViewCount])
GO
*/


/*
USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Posts] ([PostTypeId])
INCLUDE ([AnswerCount],[CommentCount],[Score],[Title],[ViewCount])
GO
*/

/*
USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Posts] ([PostTypeId])
INCLUDE ([Score],[Tags],[Title],[ViewCount])
GO
*/

/*
USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Posts] ([Score])
INCLUDE ([OwnerUserId],[PostTypeId],[Tags])
GO
*/


/*
USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Posts] ([OwnerUserId],[Score])
INCLUDE ([AcceptedAnswerId],[AnswerCount],[Body],[ClosedDate],[CommentCount],[CommunityOwnedDate],[CreationDate],[FavoriteCount],[LastActivityDate],[LastEditDate],[LastEditorDisplayName],[LastEditorUserId],[ParentId],[PostTypeId],[Tags],[Title],[ViewCount])
GO
*/

/*
USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Posts] ([PostTypeId])
INCLUDE ([Score],[Tags],[Title],[ViewCount])
GO
*/




-- ======
-- Votes
-- ======


USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX IX_UserId_DisplayName_Bounty_PostId
ON [dbo].[Votes] ([UserId], [BountyAmount], PostId)
GO



/*
USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Votes] ([UserId])
INCLUDE ([PostId],[BountyAmount])
GO
*/


/*
USE [StackOverflow2013]
GO
CREATE NONCLUSTERED INDEX [<Name of Missing Index, sysname,>]
ON [dbo].[Votes] ([BountyAmount])
INCLUDE ([PostId],[UserId])
GO
*/

CREATE NONCLUSTERED INDEX IX_DisplayName_accountId
ON dbo.Users (Location , DisplayName, AccountId)
GO