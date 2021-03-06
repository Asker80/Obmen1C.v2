function Get-NamedPipeServer ($PipeName)
{
    New-Object PSObject -Property @{
        RunspacePool = Get-RunspacePool 10
        ThreadsNum = 10
        PipeName = $PipeName
        AsyncPipelines = @()
        SyncedHashtable = [Hashtable]::Synchronized(@{runNamedPipeServer = $false})
        SyncedQueue = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
    }
}
function Release-NamedPipeServer ($PSNamedPipeServer)
{
    $PSNamedPipeServer.RunspacePool.Close()
    $PSNamedPipeServer.RunspacePool.Dispose()
    $PSNamedPipeServer = $null
}

function Start-NamedPipeServer ($PSNamedPipeServer)
{
    $ScriptBlock = {
        Param ($ThreadsNum, $PipeName, $SyncedHashtable, $SyncedQueue)
        while ($SyncedHashtable.runNamedPipeServer -eq $true)
        {
            $pipe = New-Object System.IO.Pipes.NamedPipeServerStream($PipeName, [System.IO.Pipes.PipeDirection]::InOut, $ThreadsNum);
            $pipe.WaitForConnection();
            $sr = New-Object System.IO.StreamReader($pipe);
            $SyncedQueue.Enqueue($sr.ReadLine());
            $sr.Dispose();
            $pipe.Dispose();
        }
    }

    $PSNamedPipeServer.SyncedHashtable.runNamedPipeServer = $true
    for ($i = 0; $i -lt $PSNamedPipeServer.ThreadsNum; $i++)
    {
        $PSNamedPipeServer.AsyncPipelines += Invoke-Async -RunspacePool $PSNamedPipeServer.RunspacePool -ScriptBlock $ScriptBlock -Parameters $PSNamedPipeServer.ThreadsNum,$PSNamedPipeServer.PipeName,$PSNamedPipeServer.SyncedHashtable,$PSNamedPipeServer.SyncedQueue
    }
}
function Stop-NamedPipeServer ($PSNamedPipeServer)
{
    $PSNamedPipeServer.SyncedHashtable.runNamedPipeServer = $false
    for ($i = 0; $i -lt $PSNamedPipeServer.AsyncPipelines.Count; $i++)
    {
        $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(".",$PSNamedPipeServer.PipeName);
        try{$pipe.Connect(500)} catch{}
        $pipe.Dispose()
    }
    Receive-AsyncResults -Pipelines $PSNamedPipeServer.AsyncPipelines
}

function Get-AsyncNamedPipeClient
{
    New-Object PSObject -Property @{
        RunspacePool = Get-RunspacePool 3
        AsyncPipelines = New-Object System.Collections.ArrayList
    }
}

function Release-AsyncNamedPipeClient ($PSAsyncNamedPipeClient)
{
    Clean-AsyncNamedClientPipelinesFinished $PSAsyncNamedPipeClient
    $PSAsyncNamedPipeClient.RunspacePool.Close()
    $PSAsyncNamedPipeClient.RunspacePool.Dispose()
    $PSAsyncNamedPipeClient = $null
}

function SendTo-NamedPipeServerAsync
{
    param ($PSAsyncNamedPipeClient, $ServerName, $PipeName, $Message)

    $ScriptBlock = {
        param ($ServerName, $PipeName, $Message)
        $pipe = new-object System.IO.Pipes.NamedPipeClientStream($ServerName, $PipeName);
        try {
            $pipe.Connect(3000)
            $isNPServerUnreachable = $false
        } catch {
        #    $_
            $isNPServerUnreachable = $true
        }
        if ($isNPServerUnreachable -eq $false)
        {
            $sw = new-object System.IO.StreamWriter($pipe);
            $sw.WriteLine($Message);
            $sw.Dispose();
        }
        $pipe.Dispose()
        ($isNPServerUnreachable -eq $false)
    }
    
    $null = $PSAsyncNamedPipeClient.AsyncPipelines.Add((Invoke-Async -RunspacePool $PSAsyncNamedPipeClient.RunspacePool -ScriptBlock $ScriptBlock -Parameters $ServerName,$PipeName,$Message))
}

function Clean-AsyncNamedClientPipelinesFinished ($PSAsyncNamedPipeClient)
{
    if ($PSAsyncNamedPipeClient.AsyncPipelines.Count -gt 0)
    {
        $finishedPipelines = @()
        $PSAsyncNamedPipeClient.AsyncPipelines | %{
            if ((Receive-AsyncStatus -Pipelines $_).Completed)
            {
                $null = Receive-AsyncResults -Pipelines $_
                $finishedPipelines += $_
            }
        }
        $finishedPipelines | %{ $PSAsyncNamedPipeClient.AsyncPipelines.Remove($_) }
    }
}

<#
	Module file for psasync.
#>
Add-Type @'
public class AsyncPipeline
{
    public System.Management.Automation.PowerShell Pipeline ;
    public System.IAsyncResult AsyncResult ;
}
'@

Function Invoke-Async
{
<#
.SYNOPSIS 
Create a PowerShell pipeline and executes a script block asynchronously.

.DESCRIPTION


.PARAMETER RunspacePool
A pool of one or more runspaces, typically created using Get-RunspacePool in the psasync module.

.PARAMETER ScriptBlock
The scriptblock to be executed.

.PARAMETER Parameters
Arguments to be passed, in order, to the ScriptBlock.
    
.NOTES
Author: Jon Boulineau
Created: 19 April 2012
Modified: 

.EXAMPLE
Invoke-Async -RunspacePool $(Get-RunspacePool 3) `
    -ScriptBlock { Param($ServiceName,$ComputerName) Get-Service -Name $ServiceName -ComputerName $ComputerName } `
    -Parameters  'PolicyAgent','localhost'
#>
    [Cmdletbinding()]
    Param
    (
        [Parameter(Position=0,Mandatory=$True)]$RunspacePool,
        [Parameter(Position=1,Mandatory=$True)][ScriptBlock]$ScriptBlock,
        [Parameter(Position=2,Mandatory=$False)][Object[]]$Parameters
    )
    
    $Pipeline = [System.Management.Automation.PowerShell]::Create() 

	$Pipeline.RunspacePool = $RunspacePool
	    
    $Pipeline.AddScript($ScriptBlock) | Out-Null
    
    Foreach($Arg in $Parameters)
    {
        $Pipeline.AddArgument($Arg) | Out-Null
    }
    
	$AsyncResult = $Pipeline.BeginInvoke() 
	
	$Output = New-Object AsyncPipeline 
	
	$Output.Pipeline = $Pipeline
	$Output.AsyncResult = $AsyncResult
	
	$Output
}

Function Get-RunspacePool
{
<#
.SYNOPSIS 
Create a runspace pool.

.DESCRIPTION
This function returns a runspace pool, a collection of runspaces upon which PowerShell
pipelines can be executed.  The number of available pools determined the maximum
number of processes that can be running concurrently.  This enables multithreaded
execution of PowerShell code.

.PARAMETER PoolSize
Defines the maximum number of pipelines that can be concurrently (asynchronously)
executed on the pool.

.PARAMETER MTA
Create runspaces in a Mult-Threaded Apartment.  It is not recommended to use this 
option unless absolutely necessary.
    
.NOTES
Author: Jon Boulineau
Created: 19 April 2012
Modified: 

.EXAMPLE
$pool = Get-RunspacePool 3

Creates a pool of 3 runspaces
#>
    [Cmdletbinding()]
    Param
    (
        [Parameter(Position=0,Mandatory=$true)][int]$PoolSize,
        [Parameter(Position=1,Mandatory=$False)][Switch]$MTA
    )
    
    $pool = [RunspaceFactory]::CreateRunspacePool(1, $PoolSize)	
    
    If(!$MTA) { $pool.ApartmentState = "STA" }
    
    $pool.Open()
    
    return $pool
}

Function Receive-AsyncResults
{
<#
.SYNOPSIS 
Receives the results of one or more asynchronous pipelines.

.DESCRIPTION
This function receives the results of a pipeline running in a separate runspace.  
Since it is unknown what exists in the results stream of the pipeline, this function
will not have a standard return type.  

.PARAMETER AsyncResults
An array of AsyncPipleine objects, typically returned by Invoke-Async.

.PARAMETER ShowProgress
An optional switch to display a progress indicator
  
.NOTES
Author: Jon Boulineau
Created: 19 April 2012
Modified: 
#>

    [Cmdletbinding()]
    Param
    (
        [Parameter(Position=0,Mandatory=$True)][AsyncPipeline[]]$Pipelines,
		[Parameter(Position=1,Mandatory=$false)][Switch]$ShowProgress
    )
	
    $i = 1 # incrementing for Write-Progress
	
    foreach($Pipeline in $Pipelines)
    {
		
		try
		{
        	$Pipeline.Pipeline.EndInvoke($Pipeline.AsyncResult)
			
			If($Pipeline.Pipeline.Streams.Error)
			{
				Throw $Pipeline.Pipeline.Streams.Error
			}
        } catch {
			$_
		}
        $Pipeline.Pipeline.Dispose()
		
		If($ShowProgress)
		{
			Write-Progress -Activity 'Receiving Results' -PercentComplete $(($i/$Pipelines.Length) * 100) `
				-Status "Percent Complete"
		}
		$i++
    }
}

Function Receive-AsyncStatus
{
<#
.SYNOPSIS 
Receives the status of one or more asynchronous pipelines.

.DESCRIPTION

.PARAMETER AsyncResults
An array of AsyncPipleine objects, typically returned by Invoke-Async.
  
.NOTES
Author: Jon Boulineau
Created: 19 April 2012
Modified: 
#>

    [Cmdletbinding()]
    Param
    (
        [Parameter(Position=0,Mandatory=$True)][AsyncPipeline[]]$Pipelines
    )
    
    foreach($Pipeline in $Pipelines)
    {

	   New-Object PSObject -Property @{
	   		InstanceID = $Pipeline.Pipeline.InstanceId
	   		Status = $Pipeline.Pipeline.InvocationStateInfo.State
			Reason = $Pipeline.Pipeline.InvocationStateInfo.Reason
			Completed = $Pipeline.AsyncResult.IsCompleted
			AsyncState = $Pipeline.AsyncResult.AsyncState			
			Error = if ($Pipeline.AsyncResult.IsCompleted -eq $true){$Pipeline.Pipeline.Streams.Error}
       }
	} 
}
