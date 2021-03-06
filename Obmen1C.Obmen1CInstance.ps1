param ($InstanceId)
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
## MSMQ Init
$g_MSMQueueName = "Obmen1C.Obmen1C{$InstanceId}"
$g_MSMQueue = Init-MSMQ $g_MSMQueueName
## SQL Init
$g_SqlCredentialMaster = Get-SQLCredMaster $g_settings
$g_SqlCredentialLocal = Get-SQLCredLocal $g_settings
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
        $iConfStatus = 3
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
    }
    
    Start-Sleep 1
}
