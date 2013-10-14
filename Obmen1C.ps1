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
Update-TypeData (Join-Path (Get-ScriptPath) "GenericTypesExtension.ps1xml")
. (Join-Path (Get-ScriptPath) "MSMQFuncs.ps1")
. (Join-Path (Get-ScriptPath) "SQLFuncs.ps1")
. (Join-Path (Get-ScriptPath) "Obmen1C.CommCenter.API.ps1")
## Read Settings
$g_settings = ([xml](gc "settings.xml")).settings # В продакшене файл будет лежать в \ProgramData\Obmen1C
## MSMQ Init
$g_MSMQueueName = "Obmen1C"
if (Test-MSMQueue $g_MSMQueueName)
{
    $g_MSMQueue = Get-MSMQueue $g_MSMQueueName
    Purge-MSMQueue $g_MSMQueue
}
else
{
    Create-MSMQueue $g_MSMQueueName
    $g_MSMQueue = Get-MSMQueue $g_MSMQueueName
}
Set-MSMQReadProperties $g_MSMQueue
Add-MSMQTargetTypes $g_MSMQueue "System.String"
## SQL Init
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
## Init processes variables
$pObmen1CInstances = @{}
$pCommCenter = $null
$pSqlConfReplicator = $null
## Init conf update status
# 0 - NoUpdate, 1 - UpdatePending, 2 - UpdateSuccess_ReadConfFromSql, 3 - UpdatedConfRead_ApplyConf
$iConfStatus = 2
## Init main loop switch
$doMainLoop = $true
#### Initialization section END ####

#### Main loop ####
while ($doMainLoop)
{
    #### change every master sql reference to local!!!!!!!!!!!! (when local replica is ready)
    # Read conf from SQL
    if ($iConfStatus -eq 2)
    {
            #$sqlCommandMaster = "SELECT DISTINCT t_confObmenCycleHierarchy.c_GuidId from t_confBases,t_confObmenSMK,t_confObmenCycleHierarchy WHERE t_confBases.ExecServer='$($env:computername)' AND t_confBases.c_GuidId=t_confObmenSMK.DBGuid AND t_confObmenSMK.ObmenCycleGuid=t_confObmenCycleHierarchy.c_GuidId"
            $sqlCommandMaster = "SELECT DISTINCT t_confObmenCycleHierarchy.c_GuidId from t_confBases,t_confObmenSMK,t_confObmenCycleHierarchy WHERE t_confBases.ExecServer='account' AND t_confBases.c_GuidId=t_confObmenSMK.DBGuid AND t_confObmenSMK.ObmenCycleGuid=t_confObmenCycleHierarchy.c_GuidId"
            $sqlResMaster = Invoke-SqlCommand -dataSource $g_settings.Master.SqlDataSource -database $g_settings.Master.SqlDatabase -sqlCommand $sqlCommandMaster -credential $g_SqlCredentialMaster
            $confObmen1CInstanceGuids = @()
            $sqlResMaster | %{$confObmen1CInstanceGuids += $_.c_GuidId.ToString()}
            $iConfStatus = 3
    }
    # Stop processes that shouldnt run (only after conf update)
    if ($iConfStatus -eq 3)
    {
        if ($pObmen1CInstances.Count -gt 0)
        {
            $pObmen1CInstances | %{
                if ($confObmen1CInstanceGuids -notcontains $_.Name)
                {
                    $o1cm = New-Obmen1CMessage
                    Add-Obmen1CMessageSender $o1cm "obmen1c@$($env:computername)"
                    Add-Obmen1CMessageRecipient $o1cm "obmen1c.obmen1c{$($_.Name)}@$($env:computername)"
                    Add-Obmen1CMessageBodyContent $o1cm "command" "shutdown"
                    Send-Obmen1CMessage $o1cm
                    $pObmen1CInstances.Remove($_.Name)
                }
            }
        }
    }
    # Start processes that should run (if no conf update or after conf update)
    if ($iConfStatus -eq 0 -or $iConfStatus -eq 3)
    {
        # Obmen1C.Instances
        if ($confObmen1CInstanceGuids.Count -gt 0)
        {
            $confObmen1CInstanceGuids | %{
                $pRunArgs = "-command `". Obmen1C.Obmen1CInstance.ps1 -InstanceId $_`""
                if ($pObmen1CInstances[$_] -eq $null)
                {
                    $pwmiObmen1CInstance = Get-WmiObject Win32_Process -Filter ("Name LIKE '%powershell%' AND CommandLine LIKE '%"+$pRunArgs.Replace('\','\\').Replace("'","\'")+"%'")
                    if ($pwmiObmen1CInstance -ne $null) { $pObmen1CInstances[$_] = Get-Process -Id $pwmiObmen1CInstance.ProcessID }
                    else { $pObmen1CInstances[$_] = Start-Process "powershell.exe" $pRunArgs -PassThru }
                }
                if ($pObmen1CInstances[$_].HasExited -eq $true)
                {
                    $pObmen1CInstances[$_] = Start-Process "powershell.exe" $pRunArgs -PassThru
                }
            }
        }
        # CommCenter
        $pRunArgs = "-command `". Obmen1C.CommCenter.ps1`""
        if ($pCommCenter -eq $null)
        {
            $pwmiCommCenter = Get-WmiObject Win32_Process -Filter ("Name LIKE '%powershell%' AND CommandLine LIKE '%"+$pRunArgs.Replace('\','\\').Replace("'","\'")+"%'")
            if ($pwmiCommCenter -ne $null) { $pCommCenter = Get-Process -Id $pwmiCommCenter.ProcessID }
            else { $pCommCenter = Start-Process "powershell.exe" $pRunArgs -PassThru }
        }
        if ($pCommCenter.HasExited -eq $true)
        {
            $pCommCenter = Start-Process "powershell.exe" $pRunArgs -PassThru
        }
        # SqlConfReplicator
        $pRunArgs = "-command `". Obmen1C.SqlConfReplicator.ps1`""
        if ($pSqlConfReplicator -eq $null)
        {
            $pwmiSqlConfReplicator = Get-WmiObject Win32_Process -Filter ("Name LIKE '%powershell%' AND CommandLine LIKE '%"+$pRunArgs.Replace('\','\\').Replace("'","\'")+"%'")
            if ($pwmiSqlConfReplicator -ne $null) { $pSqlConfReplicator = Get-Process -Id $pwmiSqlConfReplicator.ProcessID }
            else { $pSqlConfReplicator = Start-Process "powershell.exe" $pRunArgs -PassThru }
        }
        if ($pSqlConfReplicator.HasExited -eq $true)
        {
            $pSqlConfReplicator = Start-Process "powershell.exe" $pRunArgs -PassThru
        }
        # Last actions for iConfStatus == 3 done, set iConfStatus = 0
        $iConfStatus = 0
    }
    # Receive message from MSMQ
    $rawMsg = Receive-MSMQMessage $g_MSMQueue
    # Check if there actually was a message, else sleep 1 second
    if ($rawMsg -ne $null)
    {
        # Deobfuscate message
        $xmlMsg = [xml]$rawMsg.body.FromBase64String
        if ($xmlmsg.message.sender.ToLower() -eq "Obmen1C.SqlConfReplicator@$($env:computername)".ToLower())
        {
            switch ($xmlmsg.message.body.ConfUpdate)
            {
                "UpdatePending" { $iConfStatus = 1; break }
                "UpdateFailure" { $iConfStatus = 0; break }
                "UpdateSuccess" { $iConfStatus = 2; break }
            }
        }
        if (($xmlmsg.message.sender.Split('@'))[0].ToLower() -eq "Obmen1C.Obmen1C{*}".ToLower())
        {
            ## Send to Obmen1CInstances
        }
    }
    
    Start-Sleep 1
}
