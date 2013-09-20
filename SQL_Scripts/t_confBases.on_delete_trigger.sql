
/****** Object:  Trigger [dbo].[on_delete_trigger]    Script Date: 09/19/2013 16:49:54 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Asker
-- Create date: 19.09.2013
-- Description:	
-- =============================================
CREATE TRIGGER [dbo].[on_delete_trigger] 
   ON  [dbo].[t_confBases] 
   AFTER DELETE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for trigger here
	INSERT INTO dbo.t_confBases_History([DBGuid],[DBServer],[DBName],[ExecServer],[ObmenCodeID],[ServiceLogFile],
		[Admin1CUN],[Admin1CPW],[Obmen1CUN],[Obmen1CPW],[WinLocalUN],[WinLocalPW],[WinRemoteUN],[WinRemotePW],
		[c_USNcreated],[c_USNchanged],[c_USNdeleted],[c_Action])
	SELECT 
		[DBGuid],[DBServer],[DBName],[ExecServer],[ObmenCodeID],[ServiceLogFile],
		[Admin1CUN],[Admin1CPW],[Obmen1CUN],[Obmen1CPW],[WinLocalUN],[WinLocalPW],[WinRemoteUN],[WinRemotePW],
		[c_USNcreated],[c_USNchanged],(SELECT TOP 1 [c_USN]	FROM [dbo].[t_confUSN] ORDER BY [c_USN] DESC),1
	FROM Deleted;
END

GO


