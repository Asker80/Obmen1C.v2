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
## Read Settings
$g_settings = ([xml](gc "settings.xml")).settings # В продакшене файл будет лежать в \ProgramData\Obmen1C
## MSMQ Init
{
	$g_MSMQueueName = "Obmen1C.CommCenter"
	if (Test-MSMQueue $g_MSMQueueName)
	{
	    $g_MSMQueue = Get-MSMQueue $g_MSMQueueName
	#    Purge-MSMQueue $g_MSMQueue
	}
	else
	{
	    Create-MSMQueue $g_MSMQueueName
	    $g_MSMQueue = Get-MSMQueue $g_MSMQueueName
	}
	Set-MSMQReadProperties $g_MSMQueue
    Add-MSMQTargetTypes $g_MSMQueue "System.String"
}
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
            if ($_.ToLower() -eq "$g_MSMQueueName@$($env:computername)".ToLower())
            {
                #### we got a message for this module! hurray!!!
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
                    if ($bLocalSender)
                    {
                        #### foreign delivery
                    }
                }
            }
        }
    }
    else
    {
        Start-Sleep 1
    }
}
