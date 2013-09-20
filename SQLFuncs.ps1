function Invoke-SqlCommand
{
    param(
    [string] $dataSource = ".\SQLEXPRESS",
    [string] $database = "Northwind",
    [string] $sqlCommand = $(throw "Please specify a query."),
    [System.Management.Automation.PsCredential] $credential
    )

    ## Prepare the authentication information. By default, we pick
    ## Windows authentication
    $authentication = "Integrated Security=SSPI;"

    ## If the user supplies a credential, then they want SQL
    ## authentication
    if($credential)
    {
    $plainCred = $credential.GetNetworkCredential()
    $authentication =
    ("uid={0};pwd={1};" -f $plainCred.Username,$plainCred.Password)
    }

    ## Prepare the connection string out of the information they
    ## provide
    $connectionString = "Provider=sqloledb; " +
    "Data Source=$dataSource; " +
    "Initial Catalog=$database; " +
    "$authentication; "

    ## If they specify an Access database or Excel file as the connection
    ## source, modify the connection string to connect to that data source
    if($dataSource -match '\.xls$|\.mdb$')
    {
    $connectionString = "Provider=Microsoft.Jet.OLEDB.4.0; Data Source=$dataSource; "

    if($dataSource -match '\.xls$')
    {
    $connectionString += 'Extended Properties="Excel 8.0;"; '

    ## Generate an error if they didn't specify the sheet name properly
    if($sqlCommand -notmatch '\[.+\$\]')
    {
    $error = 'Sheet names should be surrounded by square brackets, and ' +
    'have a dollar sign at the end: [Sheet1$]'
    Write-Error $error
    return
    }
    }
    }

    ## Connect to the data source and open it
    $connection = New-Object System.Data.OleDb.OleDbConnection $connectionString
    $command = New-Object System.Data.OleDb.OleDbCommand $sqlCommand,$connection
    $connection.Open()

    ## Fetch the results, and close the connection
    $adapter = New-Object System.Data.OleDb.OleDbDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    [void] $adapter.Fill($dataSet)
    $connection.Close()

    ## Return all of the rows from their query
    $dataSet.Tables | Select-Object -Expand Rows
}
function Execute-SqlCommandNonQuery
{
    param(
    [string] $dataSource = ".\SQLEXPRESS",
    [string] $database = "Northwind",
    [string] $sqlCommand = $(throw "Please specify a query."),
    [System.Management.Automation.PsCredential] $credential
    )

    ## Prepare the authentication information. By default, we pick
    ## Windows authentication
    $authentication = "Integrated Security=SSPI;"

    ## If the user supplies a credential, then they want SQL
    ## authentication
    if($credential)
    {
    $plainCred = $credential.GetNetworkCredential()
    $authentication =
    ("uid={0};pwd={1};" -f $plainCred.Username,$plainCred.Password)
    }

    ## Prepare the connection string out of the information they
    ## provide
    $connectionString = "Provider=sqloledb; " +
    "Data Source=$dataSource; " +
    "Initial Catalog=$database; " +
    "$authentication; "

    ## Connect to the data source and open it
    $connection = New-Object System.Data.OleDb.OleDbConnection $connectionString
    $command = New-Object System.Data.OleDb.OleDbCommand $sqlCommand,$connection
    $connection.Open()

    ## Execute the command, and close the connection
    $command.ExecuteNonQuery()
    $connection.Close()
}

function Begin-SqlTransaction
{
    param(
    [string] $dataSource = ".\SQLEXPRESS",
    [string] $database = "Northwind",
    [System.Management.Automation.PsCredential] $credential
    )

    ## Prepare the authentication information. By default, we pick
    ## Windows authentication
    $authentication = "Integrated Security=SSPI;"

    ## If the user supplies a credential, then they want SQL
    ## authentication
    if($credential)
    {
    $plainCred = $credential.GetNetworkCredential()
    $authentication =
    ("uid={0};pwd={1};" -f $plainCred.Username,$plainCred.Password)
    }

    ## Prepare the connection string out of the information they
    ## provide
    $connectionString = "Provider=sqloledb; " +
    "Data Source=$dataSource; " +
    "Initial Catalog=$database; " +
    "$authentication; "

    ## Connect to the data source and open it
    $connection = New-Object System.Data.OleDb.OleDbConnection $connectionString
    $connection.Open()
    $transaction = $connection.BeginTransaction()

    ## Return connection and transaction
    $connection
    $transaction
}

function Execute-SqlCommandNonQueryTransaction
{
    param(
        $sqlCommand,
        $connection,
        $transaction
    )

    $command = New-Object System.Data.OleDb.OleDbCommand $sqlCommand,$connection,$transaction
    $command.ExecuteNonQuery()
}

function Commit-SqlTransaction
{
    param(
        $connection,
        $transaction
    )
    
    $transaction.Commit()
    $connection.Close()
}

function Rollback-SqlTransaction
{
    param(
        $connection,
        $transaction
    )
    
    $transaction.Rollback()
    $connection.Close()
}