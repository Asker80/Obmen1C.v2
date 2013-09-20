
/****** Object:  Table [dbo].[t_confBases]    Script Date: 09/19/2013 16:56:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[t_confBases](
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
 CONSTRAINT [PK_t_ObmenBases] PRIMARY KEY CLUSTERED 
(
	[DBGuid] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO


