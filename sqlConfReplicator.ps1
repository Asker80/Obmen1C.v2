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

. (Join-Path (Get-ScriptPath) "SQLFuncs.ps1")

$g_settings = ([xml](gc "settings.xml")).settings # В продакшене файл будет лежать в \ProgramData\Obmen1C

if ($g_settings.Local.SqlLogin -ne $null -and $g_settings.Local.SqlLogin -ne "" -and $g_settings.Local.SqlPass -ne $null -and $g_settings.Local.SqlPass -ne "")
{
    $g_SqlCredentialLocal = New-Object -Typename System.Management.Automation.PSCredential -ArgumentList $g_settings.Local.SqlLogin,(ConvertTo-SecureString $g_settings.Local.SqlPass -AsPlainText -Force)
}
else
{
    $g_SqlCredentialLocal = $null
}
if ($g_settings.Master.SqlLogin -ne $null -and $g_settings.Master.SqlLogin -ne "" -and $g_settings.Master.SqlPass -ne $null -and $g_settings.Master.SqlPass -ne "")
{
    $g_SqlCredentialMaster = New-Object -Typename System.Management.Automation.PSCredential -ArgumentList $g_settings.Master.SqlLogin,(ConvertTo-SecureString $g_settings.Master.SqlPass -AsPlainText -Force)
}
else
{
    $g_SqlCredentialMaster = $null
}

# Set initial last sync time to Now minus 11 minutes, so first sync will start right away
$g_LastSyncTime = (Get-Date) - (New-TimeSpan -Minutes 11)
# Main loop
while ($True)
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
                        $null = Execute-SqlCommandNonQueryTransaction -sqlCommand $sqlCommandLocal -connection $ConnTrans[0] -transaction $ConnTrans[1] 
                    }
                }
                
                ### TEST - auto-get table columns
                $sqlCommandLocal = "SELECT c.name,c.column_id,c.is_nullable FROM sys.all_objects o join sys.all_columns c on c.object_id = o.object_id WHERE o.name = 't_confBases' ORDER BY column_id ASC"
                ### END TEST - auto-get table columns

                # Copy t_confBases table missing rows; first - created rows
                $sqlCommandMaster = [String]::Format("SELECT * FROM t_confBases WHERE c_USNcreated BETWEEN '{0}' AND '{1}'",$USNlocal,$USNmaster)
                $sqlResMaster = Invoke-SqlCommand -dataSource $g_settings.Master.SqlDataSource -database $g_settings.Master.SqlDatabase -sqlCommand $sqlCommandMaster -credential $g_SqlCredentialMaster
                if ($sqlResMaster -ne $null)
                {
                    $sqlResMaster | %{
                        $sqlColumns = "DBGuid"
                        $sqlValues = "'$($_.DBGuid.ToString())'"
                        $sqlColumns += ",DBServer"
                        $sqlValues += ",'$($_.DBServer)'"
                        $sqlColumns += ",DBName"
                        $sqlValues += ",'$($_.DBName)'"
                        $sqlColumns += ",ExecServer"
                        $sqlValues += ",'$($_.ExecServer)'"
                        $sqlColumns += ",ObmenCodeID"
                        $sqlValues += ",'$($_.ObmenCodeID)'"
                        $sqlColumns += ",c_USNcreated"
                        $sqlValues += ",'$($_.c_USNcreated)'"
                        $sqlColumns += ",c_USNchanged"
                        $sqlValues += ",'$($_.c_USNchanged)'"
                        if ($_.ServiceLogFile -isnot [System.DBNull])
                        {
                            $sqlColumns += ",ServiceLogFile"
                            $sqlValues += ",'$($_.ServiceLogFile)'"
                        }
                        if ($_.Admin1CUN -isnot [System.DBNull])
                        {
                            $sqlColumns += ",Admin1CUN"
                            $sqlValues += ",'$($_.Admin1CUN)'"
                        }
                        if ($_.Admin1CPW -isnot [System.DBNull])
                        {
                            $sqlColumns += ",Admin1CPW"
                            $sqlValues += ",'$($_.Admin1CPW)'"
                        }
                        if ($_.Obmen1CUN -isnot [System.DBNull])
                        {
                            $sqlColumns += ",Obmen1CUN"
                            $sqlValues += ",'$($_.Obmen1CUN)'"
                        }
                        if ($_.Obmen1CPW -isnot [System.DBNull])
                        {
                            $sqlColumns += ",Obmen1CPW"
                            $sqlValues += ",'$($_.Obmen1CPW)'"
                        }
                        if ($_.WinLocalUN -isnot [System.DBNull])
                        {
                            $sqlColumns += ",WinLocalUN"
                            $sqlValues += ",'$($_.WinLocalUN)'"
                        }
                        if ($_.WinLocalPW -isnot [System.DBNull])
                        {
                            $sqlColumns += ",WinLocalPW"
                            $sqlValues += ",'$($_.WinLocalPW)'"
                        }
                        if ($_.WinRemoteUN -isnot [System.DBNull])
                        {
                            $sqlColumns += ",WinRemoteUN"
                            $sqlValues += ",'$($_.WinRemoteUN)'"
                        }
                        if ($_.WinRemotePW -isnot [System.DBNull])
                        {
                            $sqlColumns += ",WinRemotePW"
                            $sqlValues += ",'$($_.WinRemotePW)'"
                        }
                        $sqlCommandLocal = "INSERT INTO t_confBases ($sqlColumns) VALUES ($sqlValues)"
                        $null = Execute-SqlCommandNonQueryTransaction -sqlCommand $sqlCommandLocal -connection $ConnTrans[0] -transaction $ConnTrans[1] 
                    }
                }

                # Copy t_confBases table missing rows; second - changed rows
                $sqlCommandMaster = [String]::Format("SELECT * FROM t_confBases WHERE c_USNchanged BETWEEN '{0}' AND '{1}'",$USNlocal,$USNmaster)
                $sqlResMaster = Invoke-SqlCommand -dataSource $g_settings.Master.SqlDataSource -database $g_settings.Master.SqlDatabase -sqlCommand $sqlCommandMaster -credential $g_SqlCredentialMaster
                if ($sqlResMaster -ne $null)
                {
                    $sqlResMaster | %{
                        $sqlColVals = "DBServer='$($_.DBServer)'"
                        $sqlColVals += ",DBName='$($_.DBName)'"
                        $sqlColVals += ",ExecServer='$($_.ExecServer)'"
                        $sqlColVals += ",ObmenCodeID='$($_.ObmenCodeID)'"
                        $sqlColVals += ",c_USNcreated='$($_.c_USNcreated)'"
                        $sqlColVals += ",c_USNchanged='$($_.c_USNchanged)'"
                        if ($_.ServiceLogFile -isnot [System.DBNull])
                        {
                            $sqlColVals += ",ServiceLogFile='$($_.ServiceLogFile)'"
                        }
                        if ($_.Admin1CUN -isnot [System.DBNull])
                        {
                            $sqlColVals += ",Admin1CUN='$($_.Admin1CUN)'"
                        }
                        if ($_.Admin1CPW -isnot [System.DBNull])
                        {
                            $sqlColVals += ",Admin1CPW='$($_.Admin1CPW)'"
                        }
                        if ($_.Obmen1CUN -isnot [System.DBNull])
                        {
                            $sqlColVals += ",Obmen1CUN='$($_.Obmen1CUN)'"
                        }
                        if ($_.Obmen1CPW -isnot [System.DBNull])
                        {
                            $sqlColVals += ",Obmen1CPW='$($_.Obmen1CPW)'"
                        }
                        if ($_.WinLocalUN -isnot [System.DBNull])
                        {
                            $sqlColVals += ",WinLocalUN='$($_.WinLocalUN)'"
                        }
                        if ($_.WinLocalPW -isnot [System.DBNull])
                        {
                            $sqlColVals += ",WinLocalPW='$($_.WinLocalPW)'"
                        }
                        if ($_.WinRemoteUN -isnot [System.DBNull])
                        {
                            $sqlColVals += ",WinRemoteUN='$($_.WinRemoteUN)'"
                        }
                        if ($_.WinRemotePW -isnot [System.DBNull])
                        {
                            $sqlColVals += ",WinRemotePW='$($_.WinRemotePW)'"
                        }
                        $sqlCommandLocal = "UPDATE t_confBases SET $sqlColVals WHERE DBGuid='$($_.DBGuid.ToString())'"
                        $null = Execute-SqlCommandNonQueryTransaction -sqlCommand $sqlCommandLocal -connection $ConnTrans[0] -transaction $ConnTrans[1] 
                    }
                }

                # Copy t_confBases table missing rows; third - deleted rows
                $sqlCommandMaster = [String]::Format("SELECT DBGuid,c_USNdeleted FROM t_confBases_History WHERE c_Action=1 AND c_USNdeleted BETWEEN '{0}' AND '{1}'",$USNlocal,$USNmaster)
                $sqlResMaster = Invoke-SqlCommand -dataSource $g_settings.Master.SqlDataSource -database $g_settings.Master.SqlDatabase -sqlCommand $sqlCommandMaster -credential $g_SqlCredentialMaster
                if ($sqlResMaster -ne $null)
                {
                    $sqlResMaster | %{
                        $sqlCommandLocal = "DELETE FROM t_confBases WHERE DBGuid='$($_.DBGuid.ToString())'"
                        $null = Execute-SqlCommandNonQueryTransaction -sqlCommand $sqlCommandLocal -connection $ConnTrans[0] -transaction $ConnTrans[1] 
                    }
                }

                # Commit transaction
                Commit-SqlTransaction -connection $ConnTrans[0] -transaction $ConnTrans[1]
            }
            catch
            {
                $_
                # Rollback transaction
                Rollback-SqlTransaction -connection $ConnTrans[0] -transaction $ConnTrans[1]
            }
        }
        # Update last sync time
        $g_LastSyncTime = (Get-Date)
    }
    
    Start-Sleep -Seconds 1
}
