function Stop-AzWebAppOwn {
    param ([string] $AzureRunAsConnection, [string] $ResourceGroupName, [string] $Name)

    Write-Output ('AzureRunAsConnection: {0} ResourceGroupName: {1} Name: {2}' -F $AzureRunAsConnection, $ResourceGroupName, $Name)

    # $servicePrincipalConnection = Get-AutomationConnection -Name $AzureRunAsConnection
    # $azAccount = Add-AzAccount -ServicePrincipal -SubscriptionId $servicePrincipalConnection.SubscriptionId -TenantId $servicePrincipalConnection.TenantId -ApplicationId $servicePrincipalConnection.ApplicationId -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint

    Stop-AzWebApp -ResourceGroupName $ResourceGroupName -Name $Name -ErrorAction Stop
    Write-Output ('Resource "{0}" successfully stopped' -F $Name)
}