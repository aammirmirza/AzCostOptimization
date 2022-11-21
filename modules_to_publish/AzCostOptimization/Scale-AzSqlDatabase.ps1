function Scale-AzSqlDatabase {
    param ([string] $AzureRunAsConnection, [string] $ResourceGroupName, [string] $Name, [string] $Sku)
    # Connect using a Managed Service Identity
    try {
        $AzureContext = (Connect-AzAccount -Identity).context
    }
    catch {
        Write-Output 'There is no system-assigned user identity. Aborting. Setu the same or try using RunAs account automation method.';
    }

    Write-Output ('AzureRunAsConnection: {0} ResourceGroupName: {1} Name: {2} SKU: {3}' -F $AzureRunAsConnection, $ResourceGroupName, $Name, $Sku)

    $ServerName, $DatabaseName = $Name.Split('/')[0], $Name.Split('/')[1]

    # $servicePrincipalConnection = Get-AutomationConnection -Name $AzureRunAsConnection
    # $azAccount = Add-AzAccount -ServicePrincipal -SubscriptionId $servicePrincipalConnection.SubscriptionId -TenantId $servicePrincipalConnection.TenantId -ApplicationId $servicePrincipalConnection.ApplicationId -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint

    $sqldb = Get-AzSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $DatabaseName -ErrorAction Stop

    if ((-not [System.String]::IsNullOrEmpty($Sku)) -and ($Sku -ne $sqldb.CurrentServiceObjectiveName)) {
        Set-AzSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $DatabaseName -Edition $sqldb.Edition -RequestedServiceObjectiveName $Sku -ErrorAction Stop
    }

    Write-Output ('Resource "{0}" successfully scaled from SKU "{1}" to "{2}"' -F $Name, $sqldb.CurrentServiceObjectiveName, $Sku)
}