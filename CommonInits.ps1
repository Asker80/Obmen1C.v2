function Read-Settings
{
    ([xml](gc ".\settings.xml")).settings # В продакшене файл будет лежать в \ProgramData\Obmen1C
}

function Init-MSMQ ($MSMQueueName)
{
    if (Test-MSMQueue $MSMQueueName)
    {
        $MSMQueue = Get-MSMQueue $MSMQueueName
        Purge-MSMQueue $MSMQueue
    }
    else
    {
        Create-MSMQueue $MSMQueueName
        $MSMQueue = Get-MSMQueue $MSMQueueName
    }
    Set-MSMQReadProperties $MSMQueue
    Add-MSMQTargetTypes $MSMQueue "System.String"
    $MSMQueue
}

function Get-SQLCredLocal ($settings)
{
    if ($settings.Local.SqlLogin -ne $null -and $settings.Local.SqlLogin -ne "" -and $settings.Local.SqlPass -ne $null -and $settings.Local.SqlPass -ne "")
    {
        New-Object -Typename System.Management.Automation.PSCredential -ArgumentList $settings.Local.SqlLogin,(ConvertTo-SecureString $settings.Local.SqlPass -AsPlainText -Force)
    }
}
function Get-SQLCredMaster ($settings)
{
    if ($settings.Master.SqlLogin -ne $null -and $settings.Master.SqlLogin -ne "" -and $settings.Master.SqlPass -ne $null -and $settings.Master.SqlPass -ne "")
    {
        New-Object -Typename System.Management.Automation.PSCredential -ArgumentList $settings.Master.SqlLogin,(ConvertTo-SecureString $settings.Master.SqlPass -AsPlainText -Force)
    }
}