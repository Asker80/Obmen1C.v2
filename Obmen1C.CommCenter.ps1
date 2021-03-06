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
. (Join-Path (Get-ScriptPath) "SQLFuncs.ps1")
. (Join-Path (Get-ScriptPath) "MSMQFuncs.ps1")
. (Join-Path (Get-ScriptPath) "PSAsyncPipes.ps1")
## Read Settings
$g_settings = Read-Settings
## MSMQ Init
$g_MSMQueueName = "Obmen1C.CommCenter"
$g_MSMQueue = Init-MSMQ $g_MSMQueueName
## SQL Init
$g_SqlCredentialMaster = Get-SQLCredMaster $g_settings
$g_SqlCredentialLocal = Get-SQLCredLocal $g_settings
## PS Async Pipes Init
$g_PSAsyncPipeName = "com.samberi.Obmen1C"
$PSAsyncNamedPipeClient = Get-AsyncNamedPipeClient
$PSNamedPipeServer = Get-NamedPipeServer $g_PSAsyncPipeName
Start-NamedPipeServer $PSNamedPipeServer
## Init main loop switch
$doMainLoop = $true
#### Initialization section END ####

#### Main loop ####
while ($doMainLoop)
{
    # Receive message from MSMQ
    $rawMsg = Receive-MSMQMessage $g_MSMQueue
    # Check if there actually was a message, else sleep 1 second
    if ($rawMsg -ne $null)
    {
        # Deobfuscate message
        $xmlMsg = [xml]$rawMsg.body.FromBase64String
        # Determine if the sender is from this server or not
        $bLocalSender = $false
        if (($xmlmsg.message.sender.Split('@'))[1].ToLower() -eq "$($env:computername)".ToLower())
        {
            $bLocalSender = $true
        }
        # Send message to each recipient, send to foreign recipients only from local senders
        $xmlmsg.message.recipient | %{
            if ($_.Split('@')[0].ToLower() -eq "*")
            {
                Remove-Obmen1CMessageRecipient $xmlmsg $_
                Add-Obmen1CMessageRecipient $xmlmsg "Obmen1C@$($env:computername)"
                Add-Obmen1CMessageRecipient $xmlmsg "Obmen1C.Obmen1C{*}@$($env:computername)"
                Add-Obmen1CMessageRecipient $xmlmsg "Obmen1C.SqlConfReplicator@$($env:computername)"
                Add-Obmen1CMessageRecipient $xmlmsg "Obmen1C.CommCenter@$($env:computername)"
            }
            if ($_.Split('@')[0].ToLower() -eq "$g_MSMQueueName".ToLower())
            {
                #### we got a message for this module! hurray!!!
                if ($xmlmsg.message.body.command -eq "shutdown")
                {
                    $doMainLoop = $false
                }
            }
            else
            {
                if (($_.Split('@'))[1].ToLower() -eq "$($env:computername)".ToLower())
                {
                    # Delivery to MSMQ on this server
                    if (Test-MSMQueue ($_.Split('@'))[0])
                    {
                        $targetMSMQ = Get-MSMQueue ($_.Split('@'))[0]
                        Send-MSMQMessage $targetMSMQ $rawMsg.body
                    }
                }
                else
                {
                    # Delivery to PipeServer on remote server
                    if ($bLocalSender)
                    {
                        SendTo-NamedPipeServerAsync $PSAsyncNamedPipeClient ($_.Split('@'))[1].ToLower() $g_PSAsyncPipeName $rawMsg.body
                    }
                }
            }
        }
    }
    # Receive message from PipeServer
    if ($PSNamedPipeServer.SyncedQueue.Count -gt 0)
    {
        $rawMsg = $PSNamedPipeServer.SyncedQueue.Dequeue()
        # Drop it to this module's MSMQ so we dont duplicate message processing code and logic :)
        Send-MSMQMessage $g_MSMQueueName $rawMsg.body
    }
    Clean-AsyncNamedClientPipelinesFinished $PSAsyncNamedPipeClient
    if ($rawMsg -eq $null -and $PSNamedPipeServer.SyncedQueue.Count -eq 0)
    {
        Start-Sleep 1
    }
}
#### Main loop ####

#### Cleanup section BEGIN ####

## PS Async Pipes Init
Release-AsyncNamedPipeClient $PSAsyncNamedPipeClient
Stop-NamedPipeServer $PSNamedPipeServer
Release-NamedPipeServer $PSNamedPipeServer

#### Cleanup section END ####