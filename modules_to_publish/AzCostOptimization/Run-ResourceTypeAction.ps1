###############################################################################

<#
.SYNOPSIS
    Run-ResourceScale

.DESCRIPTION
    Run-ResourceScale : Master runbook for all actions

.PARAMETER AzureRunAsConnection
    Name of a 'connection' item for the automation account OR
    JSON array of objects for connections
      - object syntax {'AzureRunAsConnection':'<connection>'}

.PARAMETER ResourceGroupName
    Resource Group Name filter - limits any resources to this resource group
    Note: '*' for all resource groups defined within resource variable

.PARAMETER Resource
    Name of a 'variable' item for the automation account that contains the list of resources (JSON array) OR
    JSON array of resources
      - object syntax {'SubscriptionId':'<subscription-id>','ResourceGroupName':'<resource-group-name>','ResourceType':'<resource-type>','ResourceName':'<name>','ScaleUp':'<scale-up>','ScaleOut':'<scale-out>','ScaleDown':'<scale-down>','ScaleIn':'<scale-in>','Action':'<action>[ <action>]'}

        <action> - combination of the following values:
          -Delete                              - deletes the resource
          -ScaleUp  | -ScaleDown               - set the resource tier to either the ScaleUp or ScaleDown value
          -ScaleOut | -ScaleIn    [-AutoScale] - set the app service plan instance count to either the ScaleOut or ScaleIn value and/or revert to custom autoscaling profile (if applicable)
          -Start    | -Stop                    - starts or stops an app service (primarily used when scaled down app servicve plan is too small to run the app service)
                                                 when used for an app service plan resource the syntax is -Start|-Stop[:<webapp>[:<webapp>]] and all/specific app services are started/stopped after/before the scaling operation

.NOTES
    If a parameter is empty or null then the script will try and retrieve the relevant value from a 'variable' item
    for the automation account using name '<script-name>-<parameter-name>' (e.g. Run-ResourceTypeAction-AzureRunAsConnection, Run-ResourceTypeAction-ResourceGroupName, Run-ResourceTypeAction-Resource)
    and then [optionally] 'Default<parameter-name>' (e.g. DefaultAzureRunAsConnection).

.EXAMPLE

#>
##############################################################################
function Run-ResourceTypeAction {
    param ([string] $ResourceGroupName, [string] $Resource, [string] $scheduleParamHardCoded)

    # Ensures you do not inherit an AzContext in your runbook
    Disable-AzContextAutosave -Scope Process | Out-Null

    # Connect using a Managed Service Identity
    try {
        $AzureContext = (Connect-AzAccount -Identity).context
    }
    catch {
        Write-Output 'There is no system-assigned user identity. Aborting. Setu the same or try using RunAs account automation method.';
    }

    if ([System.String]::IsNullOrEmpty($PSPrivateMetadata.JobId.Guid)) {
        Write-Error -Message ('Script must be run as an Azure Runbook') -ErrorAction Stop
    }

    $automation = @{ 'ResourceGroupName' = ''; 'AutomationAccountName' = ''; 'RunbookName' = ''; 'RunbookPrefix' = '' }
    $automation
    $automationResources = Get-AzResource -ResourceGroupName (Get-AutomationVariable -Name 'DefaultAzureResourceGroupName') -ResourceType 'Microsoft.Automation/AutomationAccounts'
    $automationResources
    foreach ($automationResource in $automationResources) {
        $job = Get-AzAutomationJob -ResourceGroupName $automationResource.ResourceGroupName -AutomationAccountName $automationResource.Name -Id $PSPrivateMetadata.JobId.Guid -ErrorAction SilentlyContinue
        Write-Output '------Job-----'
        $job
        if (-not [System.String]::IsNullOrEmpty($job)) {
            $automation.ResourceGroupName = $automationResource.ResourceGroupName
            $automation.AutomationAccountName = $automationResource.Name
            $automation.RunbookName = $job.RunbookName
            $automation.RunbookPrefix = $automationResource.Name -replace ('^aaa', 'arb')
            break;
        }
    }

    $schedule = Get-AzAutomationScheduledRunbook -RunbookName $job.RunbookName -AutomationAccountName $automationResource.Name -ResourceGroupName $automationResource.ResourceGroupName
    foreach ($scheduledFor in $schedule) {
    ('-' * 75)
        $scheduledForT = $scheduledFor.ScheduleName
        $scheduledForT = $scheduledForT.Substring($scheduledForT.Length - 4)
        "Schedule Name $($scheduledForT)"

        $TimeNow = Get-Date
        #get-date $TimeNow -f "HHmm"
        $TimeNow = $TimeNow.ToUniversalTime().ToString('HHmm')
        "UTC Time $($TimeNow)"
        $diffCalc = ($TimeNow - $scheduledForT)
        "Time differance $($diffCalc)"
        if (($diffCalc -le 10) -and ($diffCalc -gt -10)) {
            "Time differance condition matched for the schedule of UTC $($scheduledForT)"
            $scheduleParam = $scheduledForT
        }
        else {
            "Using parameterized scheduled time (value from 'Schedule_Param') $($scheduleParamHardCoded)"
            $scheduleParam = $scheduleParamHardCoded
        }
    }

    # My code logic#
    try {
        if (!$scheduleParam) { 'No schedule available in this time or Schedule parameter is empty within the automation schedule' }
        $dynamicVariable = Get-AutomationVariable -Name ($automation.RunbookName + '-' + $scheduleParam) -ErrorAction Stop
        # Get-AutomationVariable -Name "arbazwecostsavingsdev-run-scale-nightly-$($scheduleParam)"
        # ('-' * 75)
        #         "$dynamicVariable | $scheduleParam"
        # ('-' * 75)
        $resources = $dynamicVariable | ConvertFrom-Json
        foreach ($obj in $resources) {
            $ResourceGroupName = $obj.ResourceGroupName
            $Resource = $obj
        }
    }
    catch {
        Write-Error 'No variable to trigger the schedule exist with inline JSON arguments. Please check the variable list in automation account'
        Write-Warning 'Example format of the variable:'
        Write-Warning 'Variable name : Run-ResourceTypeAction-<scheduletime> | Run-ResourceTypeAction-0500'
        Write-Warning '{"SubscriptionId":"SubscriptionID","ResourceGroupName":"rg-mirzas-dev","ResourceType":"Microsoft.Web/serverfarms","ResourceName":"asp-mirzas-dev","ScaleUp":"S2","ScaleOut":"3","ScaleDown":"B1","ScaleIn":"1","Action":"-ScaleUp -ScaleOut -Start"},{"SubscriptionId":"SubscriptionID","ResourceGroupName":"rg-mirzas-dev","ResourceType":"Microsoft.Web/sites","ResourceName":"appmirzasdev","ScaleUp":"","ScaleOut":"","ScaleDown":"","ScaleIn":"","Action":""},{"SubscriptionId":"SubscriptionID","ResourceGroupName":"rg-mirzas-dev","ResourceType":"Microsoft.Sql/servers/databases","ResourceName":"terra-sql-061283/ProductsDB","ScaleUp":"S2","ScaleOut":"","ScaleDown":"S0","ScaleIn":"","Action":"-ScaleUp"}'
    }

    #My code logic#
    $resources = try { $resources } catch { $null }
    Write-Output '------All Schedules------'
    $resources
    if ($null -eq $resources) {
        Write-Error -Message ('Parameter "-Resource" is invalid (json object array as string required) [{0}]' -F $Resource) -ErrorAction Stop
    }

    $process = @()
    # $items = $resources #| Where-Object { ($ResourceGroupName -eq $_.ResourceGroupName) }

    foreach ($item in $resources) {
        # if ($item.ResourceType -ne 'Microsoft.Network/bastionHosts') {
        if (($null -eq ($r = Get-AzResource -ResourceGroupName $item.ResourceGroupName -Name $item.ResourceName) -and ($item.ResourceType -ne 'Microsoft.Network/bastionHosts'))) {
            Write-Error -Message ('Resource "{0}" not found [ResourceGroup: {1} ResourceType: {2} Subscription: {3}]' -F $item.ResourceName, $item.ResourceGroupName, $item.ResourceType, $itemsConnection.SubscriptionId) -ErrorAction Continue
            continue
        }
        #     continue
        # }
        $itemAction = ' ' + $item.Action + ' '
        $item | Add-Member -MemberType 'NoteProperty' -Name 'Actions' -Value @{ 'ScaleUp' = ($itemAction -match ' -ScaleUp '); 'ScaleDown' = ($itemAction -match ' -ScaleDown '); 'ScaleOut' = ($itemAction -match ' -ScaleOut '); 'ScaleIn' = ($itemAction -match ' -ScaleIn '); 'AutoScale' = ($itemAction -match ' -AutoScale '); 'Delete' = ($itemAction -match ' -Delete'); 'Deploy' = ($itemAction -match ' -Deploy'); 'Start' = ($itemAction -match ' -Start(:[^\s]+)? '); 'Stop' = ($itemAction -match ' -Stop(:[^\s]+)? ') }
        if (($item.Actions.Delete -and ($item.Actions.ScaleUp -or $item.Actions.ScaleDown -or $item.Actions.ScaleOut -or $item.Actions.ScaleIn -or $item.Actions.AutoScale -or $item.Actions.Start -or $item.Actions.Stop)) -or ($item.Actions.ScaleUp -and $item.Actions.ScaleDown) -or ($item.Actions.ScaleOut -and $item.Actions.ScaleIn) -or ($item.Actions.Start -and $item.Actions.Stop)) {
            Write-Error -Message ('Resource "{0}" has conflicting "Action" combinations defined [{0}]' -F $item.Action) -ErrorAction Continue
            continue
        }
        $item | Add-Member -MemberType 'NoteProperty' -Name 'Parameters' -Value @{ 'ResourceGroupName' = $item.ResourceGroupName; 'Name' = $item.ResourceName }
        switch ($item.ResourceType) {
            'Microsoft.Web/serverfarms' {
                $asp = Get-AzAppServicePlan -ResourceGroupName $item.ResourceGroupName -Name $item.ResourceName
                if ($item.Actions.ScaleUp -or $item.Actions.ScaleDown -or $item.Actions.ScaleOut -or $item.Actions.ScaleIn -or $item.Actions.AutoScale -or $item.Actions.Start -or $item.Actions.Stop) {
                    if ($asp.Status -eq 'Ready') {
                        if ($item.Actions.Start) {
                            $web = Get-AzWebApp -AppServicePlan $asp | Where-Object { $_.State -eq 'Stopped' }
                            if ($itemAction -match ' -Start:(?<AppService>[^\s]+) ') {
                                $itemWebApps = $matches['AppService']
                                foreach ($aspWebApp in ($itemWebApps.Split(':'))) {
                                    if ($null -ne ($web.Name | Where-Object { ($_ -eq $aspWebApp) -or (($aspWebApp -as [regex]) -and ($_ -match $aspWebApp)) })) {
                                        $item.Parameters.Add('Start', $itemWebApps)
                                        break
                                    }
                                }
                            }
                            elseif ($web.Count -gt 0) {
                                $item.Parameters.Add('Start', '*')
                            }
                        }
                        if ($item.Actions.Stop) {
                            $web = Get-AzWebApp -AppServicePlan $asp | Where-Object { $_.State -eq 'Running' }
                            if ($itemAction -match ' -Stop:(?<AppService>[^\s]+) ') {
                                $itemWebApps = $matches['AppService']
                                foreach ($aspWebApp in ($itemWebApps.Split(':'))) {
                                    if ($null -ne ($web.Name | Where-Object { ($_ -eq $aspWebApp) -or (($aspWebApp -as [regex]) -and ($_ -match $aspWebApp)) })) {
                                        $item.Parameters.Add('Stop', $itemWebApps)
                                        break
                                    }
                                }
                            }
                            elseif ($web.Count -gt 0) {
                                $item.Parameters.Add('Stop', '*')
                            }
                        }
                        if ($item.Actions.AutoScale) {
                            $item.Parameters.Add('AutoScale', $true)
                        }
                        $itemSku = $(if ($item.Actions.ScaleUp) { $item.ScaleUp } elseif ($item.Actions.ScaleDown) { $item.ScaleDown } else { '' })
                        if (($itemSku -ne '') -and ($itemSku -ne $asp.Sku.Name)) {
                            $item.Parameters.Add('Sku', $itemSku)
                        }
                        $itemSkuInstances = $(if ($item.Actions.ScaleOut) { $item.ScaleOut } elseif ($item.Actions.ScaleIn) { $item.ScaleIn } else { 0 })
                        if (($itemSkuInstances -ne 0) -and ($itemSkuInstances -ne $asp.Sku.Capacity) -and (($itemSkuInstances -ge 1) -and ($itemSkuInstances -le $asp.MaximumNumberOfWorkers))) {
                            $item.Parameters.Add('SkuInstances', $itemSkuInstances)
                        }
                        if ($item.Parameters.ContainsKey('Sku') -or $item.Parameters.ContainsKey('SkuInstances') -or $item.Parameters.ContainsKey('AutoScale') -or $item.Parameters.ContainsKey('Stop') -or $item.Parameters.ContainsKey('Start')) {
                            $process += @{ 'RunbookName' = 'Scale-AzAppServicePlan'; 'Parameters' = $item.Parameters }
                        }
                        else {
                            Write-Output ('Resource "{0}" does not need to be scaled [ResourceGroup: {1} ResourceType: {2} Subscription: {3}]' -F $item.ResourceName, $item.ResourceGroupName, $item.ResourceType, $itemsConnection.SubscriptionId)
                        }
                    }
                    else {
                        Write-Warning -Message ('Resource "{0}" not currently ready and will be skipped [ResourceGroup: {1} ResourceType: {2} Subscription: {3}]' -F $item.ResourceName, $item.ResourceGroupName, $item.ResourceType, $itemsConnection.SubscriptionId)
                    }
                }
                elseif ($item.Actions.Delete) {
                    $process += @{ 'RunbookName' = 'Remove-AzAppServicePlan'; 'Parameters' = $item.Parameters }
                }
            }
            'Microsoft.Web/sites' {
                $web = Get-AzWebApp -ResourceGroupName $item.ResourceGroupName -Name $item.ResourceName
                if ($item.Actions.Start) {
                    if ($web.State -eq 'Stopped') {
                        $process += @{ 'RunbookName' = 'Start-AzWebApp'; 'Parameters' = $item.Parameters }
                    }
                    else {
                        Write-Warning -Message ('Resource "{0}" not currently stopped and will be skipped [ResourceGroup: {1} ResourceType: {2} Subscription: {3}]' -F $item.ResourceName, $item.ResourceGroupName, $item.ResourceType, $itemsConnection.SubscriptionId)
                    }
                }
                elseif ($item.Actions.Stop) {
                    if ($web.State -eq 'Running') {
                        $process += @{ 'RunbookName' = 'Stop-AzWebApp'; 'Parameters' = $item.Parameters }
                    }
                    else {
                        Write-Warning -Message ('Resource "{0}" not currently running and will be skipped [ResourceGroup: {1} ResourceType: {2} Subscription: {3}]' -F $item.ResourceName, $item.ResourceGroupName, $item.ResourceType, $itemsConnection.SubscriptionId)
                    }
                }
            }
            'Microsoft.Sql/servers/databases' {
                $sqldb = Get-AzSqlDatabase -ResourceGroupName $item.ResourceGroupName -ServerName ($itemResourceName = $item.ResourceName.Split('/'))[0] -DatabaseName $itemResourceName[1]
                if ($item.Actions.ScaleUp -or $item.Actions.ScaleDown) {
                    if ($sqldb.Status -eq 'Online') {
                        $itemSku = $(if ($item.Actions.ScaleUp) { $item.ScaleUp } elseif ($item.Actions.ScaleDown) { $item.ScaleDown } else { '' })
                        if (($itemSku -ne '') -and ($itemSku -ne $sqldb.CurrentServiceObjectiveName)) {
                            $item.Parameters.Add('Sku', $itemSku)
                        }
                        if ($item.Parameters.ContainsKey('Sku')) {
                            $process += @{ 'RunbookName' = 'Scale-AzSqlDatabase'; 'Parameters' = $item.Parameters }
                        }
                        else {
                            Write-Output ('Resource "{0}" does not need to be scaled [ResourceGroup: {1} ResourceType: {2} Subscription: {3}]' -F $item.ResourceName, $item.ResourceGroupName, $item.ResourceType, $itemsConnection.SubscriptionId)
                        }
                    }
                    else {
                        Write-Warning -Message ('Resource "{0}" not currently online and will be skipped [ResourceGroup: {1} ResourceType: {2} Subscription: {3}]' -F $item.ResourceName, $item.ResourceGroupName, $item.ResourceType, $itemsConnection.SubscriptionId)
                    }
                }
                elseif ($item.Actions.Delete) {
                    $process += @{ 'RunbookName' = 'Remove-AzSqlDatabase'; 'Parameters' = $item.Parameters }
                }
            }
            'Microsoft.Network/bastionHosts' {
                $bastions = Get-AzBastion -ResourceGroupName $item.ResourceGroupName -Name $item.ResourceName -ErrorAction SilentlyContinue
                $itemVNET = $(if ($item.Actions.Deploy) { $item.ScaleUp } else { '' })
                $itemPIP = $(if ($item.Actions.Deploy) { $item.ScaleDown } else { '' })
                $itemSKU = $(if ($item.Actions.Deploy) { $item.ScaleIn } else { '' })
                $item.Parameters.Add('VNET', $itemVNET)
                $item.Parameters.Add('PIP', $itemPIP)
                $item.Parameters.Add('SKU', $itemSKU)
                if ($item.Actions.Deploy) {
                    if ($null -eq $bastions) {
                        $process += @{ 'RunbookName' = 'Deploy-Bastion'; 'Parameters' = $item.Parameters }
                    }
                    else {
                        Write-Warning -Message ('Resource "{0}" is already available and will be skipped [ResourceGroup: {1} ResourceType: {2} Subscription: {3}]' -F $item.ResourceName, $item.ResourceGroupName, $item.ResourceType, $itemsConnection.SubscriptionId)
                    }
                }
                elseif ($item.Actions.Delete) {
                    if ($null -ne $bastions) {
                        $process += @{ 'RunbookName' = 'Delete-Bastion'; 'Parameters' = $item.Parameters }
                    }
                    else {
                        Write-Warning -Message ('Resource "{0}" not available for action and will be skipped [ResourceGroup: {1} ResourceType: {2} Subscription: {3}]' -F $item.ResourceName, $item.ResourceGroupName, $item.ResourceType, $itemsConnection.SubscriptionId)
                    }
                }
            }
            default {
                Write-Warning -Message ('ResourceType "{0}" cannot be processed (no script logic) [{1}]' -F $item.ResourceType, $item.ResourceName)
            }
        }
    }

    if ($process.Count -gt 0) {
        # if ($azAccount.Context.Subscription.Id -ne $servicePrincipalConnection.SubscriptionId) {
        #     $azAccount = Add-AzAccount -ServicePrincipal -SubscriptionId $servicePrincipalConnection.SubscriptionId -TenantId $servicePrincipalConnection.TenantId -ApplicationId $servicePrincipalConnection.ApplicationId -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
        # }
        foreach ($item in $process) {
            Write-Output ('{0} -Parameters {1}' -F $item.RunbookName, (($item.Parameters | Format-List | Out-String) -replace ('Name  : ', '-') -replace ('Value : ', '') -replace ('\r', '') -replace ('\n', ' ') -replace ('\s+', ' ')))
            Start-AzAutomationRunbook -ResourceGroupName $automation.ResourceGroupName -AutomationAccountName $automation.AutomationAccountName -Name ($automation.RunbookPrefix + '-' + $item.RunbookName.ToLower()) -Parameters $item.Parameters | Out-Null
        }
    }
}