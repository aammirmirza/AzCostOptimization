function Deploy-Bastion {
    param ([string] $AzureRunAsConnection, [string] $ResourceGroupName, [string] $Name, [string] $pip, [string] $vnet, [string]$sku)
    Connect-AzAccount -Identity
    Write-Output ('AzureRunAsConnection: {0} ResourceGroupName: {1} Name: {2} PIP: {3} VNET: {4} SKU: {5}' -F $AzureRunAsConnection, $ResourceGroupName, $Name, $pip, $vnet, $SKU)

    # $servicePrincipalConnection = Get-AutomationConnection -Name $AzureRunAsConnection
    # $azAccount = Add-AzAccount -ServicePrincipal -SubscriptionId $servicePrincipalConnection.SubscriptionId -TenantId $servicePrincipalConnection.TenantId -ApplicationId $servicePrincipalConnection.ApplicationId -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint

    # preReqs checking
    # Fetch the VNET configuration

    try {
    $rgLocation = (Get-AzResourceGroup -Name $ResourceGroupName).location
    if (!$rgLocation) {
        throw ( $_.Exception)
    }
    $publicip = Get-AzPublicIpAddress -Name $pip -ResourceGroupName $ResourceGroupName
    if (!$publicip) {
        throw ( $_.Exception)
        Write-Output ('PublicIP: {0} in ResourceGroupName: {1} dosenot exist, Creating new for mapping' -F $PIP, $ResourceGroupName)
        $publicip = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PIP -Location $rgLocation -AllocationMethod Static -Sku Standard Zone = {}
    }
    $VNetDetails = Get-AzVirtualNetwork -Name $vnet -ResourceGroupName $ResourceGroupName
    #Fetch the SubnetConfig from the VNETConfig

    $VnetSubnetConfig = Get-AzVirtualNetworkSubnetConfig -Name 'AzureBastionSubnet' -VirtualNetwork $VNetDetails -ErrorAction SilentlyContinue
    if (!$VNetDetails) {
        Write-Output ("Missing [AzureBastionSubnet], Check if it exist in VNET : {0}" -F $VNET)
        throw ( $_.Exception)
    }
    if (!$VnetSubnetConfig) {
        throw ( $_.Exception)
        # $addressPrefix = ((Get-AzVirtualNetwork -Name $VNET -ResourceGroupName $ResourceGroupName | Select-Object -First 1
        #     ).subnets.Addressprefix).split('/')[0]

        # $octets = $addressPrefix.Split('.')             # or $octets = $addressPrefix -split "\."
        # $octets[2] = [string]([int]$octets[2] + 1)      # or other manipulation of the third octet
        # $newAddressPrefix = $octets -join '.'
        # $newAddressPrefix

        # Write-Output ('Missing [AzureBastionSubnet] Subnet for RG: {0}. Creating one for Bastion {1} using address prefix {2}/29 ' -F $ResourceGroupName, $Name, $addressPrefix)
        # ('Creating AzureBastionSubnet subnet...')
        # $AzureBastionSubnet = Add-AzVirtualNetworkSubnetConfig -Name 'AzureBastionSubnet' -VirtualNetwork $VNetDetails -AddressPrefix "$($newAddressPrefix)/29"
        # $AzureBastionSubnet = $VNetDetails | Set-AzVirtualNetwork
        # $AzureBastionSubnet
    }
    #Fetch the IPUsage from the SubnetID.
    $PrivateIPUsage = Get-AzVirtualNetworkUsageList -ResourceGroupName $ResourceGroupName -Name $vnet | Where-Object ID -EQ $VnetSubnetConfig.id

    [int] $TotalIPLimit = $PrivateIPUsage.Limit
    [int] $TotalIPUsed = $PrivateIPUsage.CurrentValue

    if ($TotalIPUsed -lt $TotalIPLimit) {
        Write-Output ("Private IP's are available in this Subnet [AzureBastionSubnet] for Usage.")
    }
    else {
        throw "Private IP's are not available in [AzureBastionSubnet] Subnet for Usage."
    }
    }
    catch {
        Write-Output 'Resource not found ' $_
    }

    # Considering VNET and PIP in the same RG
    Write-Output ("Creating bastion {0} in ResourceGroupName: {1} with PIP: {2} and VNET: {3} pricing tier {4}" -F $Name, $ResourceGroupName, $pip, $vnet, $SKU)
    New-AzBastion -ResourceGroupName $ResourceGroupName -Name $Name -PublicIpAddressRgName $ResourceGroupName -PublicIpAddressName $pip -VirtualNetworkRgName $ResourceGroupName -VirtualNetworkName $vnet -Sku $SKU -ErrorAction Stop

    Write-Output ('Resource "{0}" successfully deployed' -F $Name)
}