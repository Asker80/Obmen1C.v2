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
}
