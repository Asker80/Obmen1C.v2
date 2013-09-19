USE [Obmen1C.v2]
GO

/****** Object:  Table [dbo].[t_confBases_History]    Script Date: 09/19/2013 16:51:41 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[t_confBases_History](
	[DBGuid] [uniqueidentifier] NOT NULL,
	[DBServer] [nvarchar](50) NOT NULL,
	[DBName] [nvarchar](50) NOT NULL,
	[ExecServer] [nvarchar](50) NOT NULL,
	[ObmenCodeID] [nvarchar](50) NOT NULL,
	[ServiceLogFile] [nvarchar](256) NULL,
	[Admin1CUN] [nvarchar](50) NULL,
	[Admin1CPW] [nvarchar](50) NULL,
	[Obmen1CUN] [nvarchar](50) NULL,
	[Obmen1CPW] [nvarchar](50) NULL,
	[WinLocalUN] [nvarchar](50) NULL,
	[WinLocalPW] [nvarchar](50) NULL,
	[WinRemoteUN] [nvarchar](50) NULL,
	[WinRemotePW] [nvarchar](50) NULL,
	[c_USNcreated] [bigint] NULL,
	[c_USNchanged] [bigint] NULL,
	[c_USNdeleted] [bigint] NULL,
	[c_Action] [smallint] NULL
) ON [PRIMARY]

GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'0=Update,1=Delete' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N't_confBases_History', @level2type=N'COLUMN',@level2name=N'c_Action'
GO


