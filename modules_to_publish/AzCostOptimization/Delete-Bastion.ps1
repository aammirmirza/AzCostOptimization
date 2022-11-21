function Delete-Bastion {
    param ([string] $AzureRunAsConnection, [string] $ResourceGroupName, [string] $Name)
    try {
        Connect-AzAccount -Identity
    }
    catch {
        Write-Warning "Not enough autherization to 'Managed Identity' for performing operations."
    }
    Write-Output ('AzureRunAsConnection: {0} ResourceGroupName: {1} Name: {2} PIP: {3} VNET: {4}' -F $AzureRunAsConnection, $ResourceGroupName, $Name, $pip, $vnet)

    # $servicePrincipalConnection = Get-AutomationConnection -Name $AzureRunAsConnection
    # $azAccount = Add-AzAccount -ServicePrincipal -SubscriptionId $servicePrincipalConnection.SubscriptionId -TenantId $servicePrincipalConnection.TenantId -ApplicationId $servicePrincipalConnection.ApplicationId -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint

    # preReqs checking
    # Fetch the VNET configuration
    try {
        $rgLocation = (Get-AzResourceGroup -Name $ResourceGroupName).location
        if (!$rgLocation) {
            throw ( $_.Exception)
        }
        $avalableBastion = Get-AzBastion -ResourceGroupName $ResourceGroupName -Name $Name -ErrorAction Stop
        if ($avalableBastion) {
            Write-Output ('Deleting bastion: {0} from ResourceGroupName: {1}' -F $Name, $ResourceGroupName)
            Remove-AzBastion -ResourceGroupName $ResourceGroupName -Name $Name -Force -ErrorAction Stop
        }
        else {
            throw (New-Object System.Exception -Message 'Cannot find the bastion : {0} in ResourceGroupName: {1}' -F $Name, $ResourceGroupName)
        }
        Write-Output ('Resource "{0}" successfully deleted' -F $Name)

    }
    catch {
        Write-Output 'Resource Not Found ' $_
    }
}