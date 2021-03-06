#### Initialization section BEGIN ####
function Get-ScriptPath
{
    try
    {
        Split-Path $myInvocation.ScriptName
    }
    catch
    {
        "."
    }
}
## Imports
. (Join-Path (Get-ScriptPath) "CommonInits.ps1")
Update-TypeData (Join-Path (Get-ScriptPath) "GenericTypesExtension.ps1xml")
. (Join-Path (Get-ScriptPath) "MSMQFuncs.ps1")
. (Join-Path (Get-ScriptPath) "SQLFuncs.ps1")
. (Join-Path (Get-ScriptPath) "Obmen1C.CommCenter.API.ps1")
## Read Settings
$g_settings = Read-Settings
## SQL Init
$g_SqlCredentialMaster = Get-SQLCredMaster $g_settings
$g_SqlCredentialLocal = Get-SQLCredLocal $g_settings
## Init main loop switch
$doMainLoop = $true
## Set initial last sync time to Now minus 11 minutes, so first sync will start right away
$g_LastSyncTime = (Get-Date) - (New-TimeSpan -Minutes 11)
#### Initialization section END ####

#### Main loop ####
while ($doMainLoop)
{
    # Sync configuration every 10 minutes
    if (((Get-Date) - $g_LastSyncTime) -ge (New-TimeSpan -Minutes 10))
    {
        $sqlCommandLocal = "SELECT TOP 1 c_USN FROM t_confUSN ORDER BY c_USN DESC"
        $sqlResLocal = Invoke-SqlCommand -dataSource $g_settings.Local.SqlDataSource -database $g_settings.Local.SqlDatabase -sqlCommand $sqlCommandLocal -credential $g_SqlCredentialLocal
        $sqlCommandMaster = "SELECT TOP 1 c_USN FROM t_confUSN ORDER BY c_USN DESC"
        $sqlResMaster = Invoke-SqlCommand -dataSource $g_settings.Master.SqlDataSource -database $g_settings.Master.SqlDatabase -sqlCommand $sqlCommandMaster -credential $g_SqlCredentialMaster
        if (($sqlResMaster.c_USN - $sqlResLocal.c_USN) -gt 0)
        {
            # Send ConfUpdateBegin message
            $o1cm = New-Obmen1CMessage
            Add-Obmen1CMessageSender $o1cm "obmen1c.SqlConfReplicator@$($env:computername)"
            Add-Obmen1CMessageRecipient $o1cm "*@$($env:computername)"
            Add-Obmen1CMessageBodyContent $o1cm "ConfUpdate" "UpdatePending"
            Send-Obmen1CMessage $o1cm
            try
            {
                # Begin transaction
                $ConnTrans = Begin-SqlTransaction -dataSource $g_settings.Local.SqlDataSource -database $g_settings.Local.SqlDatabase -credential $g_SqlCredentialLocal
                
                # Copy t_confUSN table missing rows
                $USNlocal = if ($sqlResLocal.c_USN -eq $null) {0} else {$sqlResLocal.c_USN}
                $USNmaster = if ($sqlResMaster.c_USN -eq $null) {0} else {$sqlResMaster.c_USN}
                $sqlCommandMaster = [String]::Format("SELECT * FROM t_confUSN WHERE c_USN BETWEEN '{0}' AND '{1}'",$USNlocal,$USNmaster)
                $sqlResMaster = Invoke-SqlCommand -dataSource $g_settings.Master.SqlDataSource -database $g_settings.Master.SqlDatabase -sqlCommand $sqlCommandMaster -credential $g_SqlCredentialMaster
                if ($sqlResMaster -ne $null)
                {
                    $sqlResMaster | %{
                        $sqlCommandLocal = [String]::Format("INSERT INTO t_confUSN (c_USN, c_TimeStamp) VALUES ('{0}','{1}')",$_.c_USN,$_.c_TimeStamp.ToString("yyyy-MM-dd HH:mm:ss.fff"))
                        $null = Execute-SqlCommandNonQueryTransaction -sqlCommand $sqlCommandLocal -connection $ConnTrans.Connection -transaction $ConnTrans.Transaction
                    }
                }

                # Get current table columns' names                
                $sqlCommandMaster = "SELECT c.name,c.column_id,c.is_nullable FROM sys.all_objects o join sys.all_columns c on c.object_id = o.object_id WHERE o.name = 't_confObmen1CDB' ORDER BY column_id ASC"
                $sqlColumns = Invoke-SqlCommand -dataSource $g_settings.Master.SqlDataSource -database $g_settings.Master.SqlDatabase -sqlCommand $sqlCommandMaster -credential $g_SqlCredentialMaster
                # Copy t_confBases table missing rows; first - created rows
                $sqlCommandMaster = [String]::Format("SELECT * FROM t_confObmen1CDB WHERE c_USNcreated BETWEEN '{0}' AND '{1}'",$USNlocal,$USNmaster)
                $sqlResMaster = Invoke-SqlCommand -dataSource $g_settings.Master.SqlDataSource -database $g_settings.Master.SqlDatabase -sqlCommand $sqlCommandMaster -credential $g_SqlCredentialMaster
                if ($sqlResMaster -ne $null)
                {
                    $sqlResMaster | %{
                        $strSqlColumns=""
                        $strSqlValues=""
                        foreach ($sqlColumn in $sqlColumns)
                        {
                            if ($_.Item($sqlColumn.Name) -isnot [System.DBNull])
                            {
                                if ($strSqlColumns -ne "") {$strSqlColumns += ","}
                                if ($strSqlValues -ne "") {$strSqlValues += ","}
                                $strSqlColumns += "$($sqlColumn.Name)"
                                $strSqlValues += "'$($_.Item($sqlColumn.Name).ToString())'"
                            }
                        }
                        $sqlCommandLocal = "INSERT INTO t_confObmen1CDB ($strSqlColumns) VALUES ($strSqlValues)"
                        $null = Execute-SqlCommandNonQueryTransaction -sqlCommand $sqlCommandLocal -connection $ConnTrans.Connection -transaction $ConnTrans.Transaction
                    }
                }
                # Copy t_confBases table missing rows; second - changed rows
                $sqlCommandMaster = [String]::Format("SELECT * FROM t_confObmen1CDB WHERE c_USNchanged BETWEEN '{0}' AND '{1}'",$USNlocal,$USNmaster)
                $sqlResMaster = Invoke-SqlCommand -dataSource $g_settings.Master.SqlDataSource -database $g_settings.Master.SqlDatabase -sqlCommand $sqlCommandMaster -credential $g_SqlCredentialMaster
                if ($sqlResMaster -ne $null)
                {
                    $sqlResMaster | %{
                        $strSqlColVals=""
                        foreach ($sqlColumn in $sqlColumns)
                        {
                            if ($strSqlColVals -ne "") {$strSqlColVals += ","}
                            if ($_.Item($sqlColumn.Name) -isnot [System.DBNull])
                            {
                                $strSqlColVals += "$($sqlColumn.Name)='$($_.Item($sqlColumn.Name).ToString())'"
                            }
                            else
                            {
                                $strSqlColVals += "$($sqlColumn.Name)=NULL"
                            }
                        }
                        $sqlCommandLocal = "UPDATE t_confObmen1CDB SET $sqlColVals WHERE c_GuidId='$($_.c_GuidId.ToString())'"
                        $null = Execute-SqlCommandNonQueryTransaction -sqlCommand $sqlCommandLocal -connection $ConnTrans.Connection -transaction $ConnTrans.Transaction
                    }
                }
                # Copy t_confBases table missing rows; third - deleted rows
                $sqlCommandMaster = [String]::Format("SELECT c_GuidId,c_USNdeleted FROM t_confObmen1CDB_History WHERE c_Action=1 AND c_USNdeleted BETWEEN '{0}' AND '{1}'",$USNlocal,$USNmaster)
                $sqlResMaster = Invoke-SqlCommand -dataSource $g_settings.Master.SqlDataSource -database $g_settings.Master.SqlDatabase -sqlCommand $sqlCommandMaster -credential $g_SqlCredentialMaster
                if ($sqlResMaster -ne $null)
                {
                    $sqlResMaster | %{
                        $sqlCommandLocal = "DELETE FROM t_confObmen1CDB WHERE c_GuidId='$($_.c_GuidId.ToString())'"
                        $null = Execute-SqlCommandNonQueryTransaction -sqlCommand $sqlCommandLocal -connection $ConnTrans.Connection -transaction $ConnTrans.Transaction
                    }
                }

                # Commit transaction
                Commit-SqlTransaction -connection $ConnTrans.Connection -transaction $ConnTrans.Transaction
                
                # Send ConfUpdateSuccess message
                $o1cm = New-Obmen1CMessage
                Add-Obmen1CMessageSender $o1cm "obmen1c.SqlConfReplicator@$($env:computername)"
                Add-Obmen1CMessageRecipient $o1cm "*@$($env:computername)"
                Add-Obmen1CMessageBodyContent $o1cm "ConfUpdate" "UpdateSuccess"
                Send-Obmen1CMessage $o1cm
            }
            catch
            {
            #    $_
                # Rollback transaction
                Rollback-SqlTransaction -connection $ConnTrans.Connection -transaction $ConnTrans.Transaction
                
                # Send ConfUpdateFailure message
                $o1cm = New-Obmen1CMessage
                Add-Obmen1CMessageSender $o1cm "obmen1c.SqlConfReplicator@$($env:computername)"
                Add-Obmen1CMessageRecipient $o1cm "*@$($env:computername)"
                Add-Obmen1CMessageBodyContent $o1cm "ConfUpdate" "UpdateFailure"
                Send-Obmen1CMessage $o1cm
            }
        }
        # Update last sync time
        $g_LastSyncTime = (Get-Date)
    }
    
    Start-Sleep -Seconds 1
}
