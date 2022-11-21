function Scale-AzAppServicePlan {
    param ([string] $AzureRunAsConnection, [string] $ResourceGroupName, [string] $Name, [string] $Sku, [int] $SkuInstances, [bool] $AutoScale, [string] $Start, [string] $Stop)
    # Connect using a Managed Service Identity
    try {
        $AzureContext = (Connect-AzAccount -Identity).context
    }
    catch {
        Write-Output 'There is no system-assigned user identity. Aborting. Setu the same or try using RunAs account automation method.';
    }
    Write-Output ('AzureRunAsConnection: {0} ResourceGroupName: {1} Name: {2} SKU: {3} Instances: {4} AutoScale: {5} Start: {6} Stop: {7}' -F $AzureRunAsConnection, $ResourceGroupName, $Name, $Sku, $SkuInstances, $AutoScale, $Start, $Stop)

    # $servicePrincipalConnection = Get-AutomationConnection -Name $AzureRunAsConnection
    # $azAccount = Add-AzAccount -ServicePrincipal -SubscriptionId $servicePrincipalConnection.SubscriptionId -TenantId $servicePrincipalConnection.TenantId -ApplicationId $servicePrincipalConnection.ApplicationId -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint

    $asp = Get-AzAppServicePlan -ResourceGroupName $ResourceGroupName -Name $Name -ErrorAction Stop
    $aspAutoScaleSettings = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'microsoft.insights/autoscalesettings' -ExpandProperties -ErrorAction SilentlyContinue
    $aspAutoScaleSettings = $aspAutoScaleSettings | Where-Object { $_.Properties.targetResourceUri -match ('/providers/Microsoft.Web/serverfarms/{0}$' -F [regex]::Escape($Name)) }

    $SetAzAppServicePlanParams = @{}
    if ((-not [System.String]::IsNullOrEmpty($Sku)) -and ($Sku -ne $asp.Sku.Name)) {
        $plans = @{'F1' = @{'Tier' = 'Free'; 'WorkerSize' = 'Small' }; 'D1' = @{'Tier' = 'Shared'; 'WorkerSize' = 'Small' };
            'B1' = @{'Tier' = 'Basic'; 'WorkerSize' = 'Small' }; 'B2' = @{'Tier' = 'Basic'; 'WorkerSize' = 'Medium' }; 'B3' = @{'Tier' = 'Basic'; 'WorkerSize' = 'Large' };
            'S1' = @{'Tier' = 'Standard'; 'WorkerSize' = 'Small' }; 'S2' = @{'Tier' = 'Standard'; 'WorkerSize' = 'Medium' }; 'S3' = @{'Tier' = 'Standard'; 'WorkerSize' = 'Large' };
            'P1v2' = @{'Tier' = 'PremiumV2'; 'WorkerSize' = 'Small' }; 'P2v2' = @{'Tier' = 'PremiumV2'; 'WorkerSize' = 'Medium' }; 'P3v2' = @{'Tier' = 'PremiumV2'; 'WorkerSize' = 'Large' };
            'P1v3' = @{'Tier' = 'PremiumV3'; 'WorkerSize' = 'Small' }; 'P2v3' = @{'Tier' = 'PremiumV3'; 'WorkerSize' = 'Medium' }; 'P3v3' = @{'Tier' = 'PremiumV3'; 'WorkerSize' = 'Large' };
            'I1' = @{'Tier' = 'Isolated'; 'WorkerSize' = 'Small' }; 'I2' = @{'Tier' = 'Isolated'; 'WorkerSize' = 'Medium' }; 'I3' = @{'Tier' = 'Isolated'; 'WorkerSize' = 'Large' };
            'I1v2' = @{'Tier' = 'IsolatedV2'; 'WorkerSize' = 'Small' }; 'I2v2' = @{'Tier' = 'IsolatedV2'; 'WorkerSize' = 'Medium' }; 'I3v2' = @{'Tier' = 'IsolatedV2'; 'WorkerSize' = 'Large' }
        }
        if ($plans.ContainsKey($Sku)) {
            $SetAzAppServicePlanParams.Add('Tier', $plans[$Sku].Tier)
            $SetAzAppServicePlanParams.Add('WorkerSize', $plans[$Sku].WorkerSize)
        }
        else {
            $Sku = $asp.Sku.Name
        }
    }
    else {
        $Sku = $asp.Sku.Name
    }
    if (($SkuInstances -gt 0) -and ($SkuInstances -ne $asp.Sku.Capacity)) {
        $SetAzAppServicePlanParams.Add('NumberofWorkers', $SkuInstances)
    }
    else {
        $SkuInstances = $asp.Sku.Capacity
    }

    if (-not [System.String]::IsNullOrEmpty($Stop)) {
        $web = Get-AzWebApp -AppServicePlan $asp -ErrorAction SilentlyContinue
        foreach ($webName in ($Stop.Split(':'))) {
            $webApps += ($web.Name | Where-Object { ($_ -eq $webName) -or (($webName -as [regex]) -and ($_ -match $webName)) })
        }
        foreach ($webApp in ($web | Where-Object { ($_.State -eq 'Running') -and (($Stop -eq '*') -or ($webApps -contains $_.Name)) })) {
            Write-Output ('*' * 75)
            Write-Output ('App Name : {1}' -F $webApp.Name)
            Write-Output ('*' * 75)
            Stop-AzWebApp -ResourceGroupName $webApp.ResourceGroup -Name $webApp.Name -ErrorAction Continue
        }
    }

    if ($SetAzAppServicePlanParams.Keys.Count -ne 0) {
        if (($null -ne $aspAutoScaleSettings) -and ($aspAutoScaleSettings.Properties.enabled -contains $true) -and (-not $AutoScale)) {
            $aspAutoScaleSettings.Properties.enabled = $false
            $aspAutoScaleSettings | Set-AzResource -Force -ErrorAction Stop
        }
        $web = Get-AzWebApp -AppServicePlan $asp -ErrorAction SilentlyContinue
        foreach ($webs in $web) {
            Write-Output ('-' * 75)
            Write-Output " App Name $($webs.Name)"
            $bPossibleOutboundIpAddresses = (($webs.PossibleOutboundIpAddresses).Split(','))
            Write-Output "OutboundIpAddresses (BEFORE) : $($webs.OutboundIpAddresses)"
            Write-Output "PossibleOutboundIpAddresses (BEFORE) : $($bPossibleOutboundIpAddresses)"
            Write-Output ('-' * 75)
        }
        Set-AzAppServicePlan -ResourceGroupName $ResourceGroupName -Name $Name @SetAzAppServicePlanParams -ErrorAction Stop
    }

    if (($null -ne $aspAutoScaleSettings) -and $AutoScale) {
        $aspAutoScaleSettings.Properties.enabled = $true
        $aspAutoScaleSettings | Set-AzResource -Force -ErrorAction Stop
    }

    if (-not [System.String]::IsNullOrEmpty($Start)) {
        $web = Get-AzWebApp -AppServicePlan $asp -ErrorAction SilentlyContinue
        foreach ($webName in ($Start.Split(':'))) {
            $webApps += ($web.Name | Where-Object { ($_ -eq $webName) -or (($webName -as [regex]) -and ($_ -match $webName)) })
        }
        foreach ($webApp in ($web | Where-Object { ($_.State -eq 'Stopped') -and (($Start -eq '*') -or ($webApps -contains $_.Name)) })) {
            Start-AzWebApp -ResourceGroupName $webApp.ResourceGroup -Name $webApp.Name -ErrorAction Continue
        }
    }
    $aweb = Get-AzWebApp -AppServicePlan $asp -ErrorAction SilentlyContinue
    foreach ($websx in $aweb) {
        Write-Output ('-' * 75)
        Write-Output " App Name $($websx.Name)"
        $aPossibleOutboundIpAddresses = (($websx.PossibleOutboundIpAddresses).Split(','))
        Write-Output "OutboundIpAddresses (AFTER) : $($websx.OutboundIpAddresses)"
        Write-Output "PossibleOutboundIpAddresses (AFTER) : $($aPossibleOutboundIpAddresses)"
        Write-Output ('-' * 75)
    }
    function Green {
        process { Write-Host $_ -ForegroundColor Green }
    }
    function Red {
        process { Write-Host $_ -ForegroundColor Red }
    }
    Write-Output ('Resource "{0}" successfully scaled from SKU "{1}" [{2}] to "{3}" [{4}]' -F $Name, $asp.Sku.Name, $asp.Sku.Capacity, $Sku, $SkuInstances) | Green

    # Comparision
    # OutboundIPAddress comparision
    $comparision = Compare-Object -ReferenceObject $aPossibleOutboundIpAddresses -DifferenceObject $bPossibleOutboundIpAddresses -IncludeEqual
    $comparision
    $comparision | ForEach-Object -Process { if ($_.SideIndicator -eq '==') {
            <# Action to perform if the condition is true #>
            Write-Output "$($_.InputObject)" | Green
        }
        else {
            <# Action when all if and elseif conditions are false #>
            Write-Output "$($_.InputObject)" | Red

        }
    }
}