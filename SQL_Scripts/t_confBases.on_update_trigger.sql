USE [Obmen1C.v2]
GO

/****** Object:  Trigger [dbo].[on_update_trigger]    Script Date: 09/19/2013 16:48:49 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Asker
-- Create date: 19.09.2013
-- Description:	
-- =============================================
CREATE TRIGGER [dbo].[on_update_trigger] 
   ON  [dbo].[t_confBases] 
   AFTER UPDATE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for trigger here
	INSERT INTO dbo.t_confBases_History([DBGuid],[DBServer],[DBName],[ExecServer],[ObmenCodeID],[ServiceLogFile],
		[Admin1CUN],[Admin1CPW],[Obmen1CUN],[Obmen1CPW],[WinLocalUN],[WinLocalPW],[WinRemoteUN],[WinRemotePW],
		[c_USNcreated],[c_USNchanged],[c_Action])
	SELECT 
		[DBGuid],[DBServer],[DBName],[ExecServer],[ObmenCodeID],[ServiceLogFile],
		[Admin1CUN],[Admin1CPW],[Obmen1CUN],[Obmen1CPW],[WinLocalUN],[WinLocalPW],[WinRemoteUN],[WinRemotePW],
		[c_USNcreated],[c_USNchanged],0
	FROM Deleted;

    INSERT INTO dbo.t_confUSN (c_TimeStamp) VALUES (GETDATE());
    UPDATE dbo.t_confBases
	SET c_USNchanged = scope_identity()
	FROM dbo.t_confBases T
	JOIN Deleted D ON T.DBGuid = D.DBGuid;

END

GO


