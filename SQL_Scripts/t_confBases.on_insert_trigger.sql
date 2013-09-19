USE [Obmen1C.v2]
GO

/****** Object:  Trigger [dbo].[on_insert_trigger]    Script Date: 09/19/2013 16:27:27 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Asker
-- Create date: 19.09.2013
-- Description:	
-- =============================================
CREATE TRIGGER [dbo].[on_insert_trigger] 
   ON  [dbo].[t_confBases] 
   INSTEAD OF INSERT
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for trigger here
    INSERT INTO dbo.t_confUSN (c_TimeStamp) VALUES (GETDATE());
    INSERT INTO dbo.t_confBases([DBGuid],[DBServer],[DBName],[ExecServer],[ObmenCodeID],[ServiceLogFile],
		[Admin1CUN],[Admin1CPW],[Obmen1CUN],[Obmen1CPW],[WinLocalUN],[WinLocalPW],[WinRemoteUN],[WinRemotePW],
		[c_USNcreated])
	SELECT 
		[DBGuid],[DBServer],[DBName],[ExecServer],[ObmenCodeID],[ServiceLogFile],
		[Admin1CUN],[Admin1CPW],[Obmen1CUN],[Obmen1CPW],[WinLocalUN],[WinLocalPW],[WinRemoteUN],[WinRemotePW],
		scope_identity()
	FROM 
		Inserted
END

GO


