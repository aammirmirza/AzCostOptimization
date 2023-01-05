$WarningPreference = 'SilentlyContinue'

# Set-AzDiagnosticSetting -ResourceId "Resource01" -Enabled $False -Category AppServiceAuditLogs,AppServiceFileAuditLogs
Function Remove-FileChangeAudit {
    Param(
        [Parameter(Mandatory = $false)]
        [Switch] $Slot,
        [string] $subscriptionId,
        [string] $appServiceRG,
        [string] $aspName
    )
    # Connect using a Managed Service Identity
    try {
        $AzureContext = (Connect-AzAccount -Identity -ErrorAction SilentlyContinue).context # Connect using a Managed Service Identity
    }
    catch {
        Write-Output 'There is no system-assigned user identity. Aborting. Setup the same or try using RunAs account automation method.';
    }
    Try {
        # $subscriptionId = 'e925f9e8-74d0-48a2-a05d-428ac3696c49'
        Set-AzContext $subscriptionId
        # $appServiceRG = 'weu-sc93-preprd-rg' #Resource Group Name"
        # $aspName = 'weu-sc93-preprd-rg-365400-xc-basic-hp' #Name of App Service Plan
        $asp = Get-AzAppServicePlan -ResourceGroupName $appServiceRG -Name $aspName -ErrorAction Stop
        $web = Get-AzWebApp -AppServicePlan $asp -ErrorAction SilentlyContinue
        Write-Output ('*' * 75)
        Write-Host "Total Apps identified $($web.Count)"
        # foreach ($webApp in ($web | Where-Object { ($_.State -eq 'Running') })) {
        foreach ($webApp in $web) {
            Write-Output ('*' * 75)
            Write-Output ('App Name : {0}' -F $webApp.Name)
            Write-Output ('*' * 75)
            try {
                # Removal of FileChangeAudit
                # to handle production (NOT Slots)
                Write-Host "Running for Web App $($webApp.Name)"
                $config = Get-AzResource -ResourceId "$($webApp.Id)"
                Write-Host "[BEFORE]FILECHANGEAUDIT Status $($webApp.Name) : $($config.Properties.siteConfig.fileChangeAuditEnabled)"
                $config.Properties.siteConfig.fileChangeAuditEnabled = 'false'
                $config.Properties.PSObject.Properties.Remove('ReservedInstanceCount')
                $newCategories = @()
                ForEach ($entry in $config.Properties.azureMonitorLogCategories) {
                    If ($entry -ne 'AppServiceFileAuditLogs') {
                        $newCategories += $entry
                    }
                }
                $config.Properties.siteConfig.azureMonitorLogCategories = $newCategories
                $config | Set-AzResource -Force
                Write-Host "[BEFORE]FILECHANGEAUDIT Status $($webApp.Name) : $($config.Properties.siteConfig.fileChangeAuditEnabled)"
                # to handle the slots
                $websiteSlots = Get-AzWebAppSlot -ResourceGroupName $appServiceRG -Name "$($webApp.Name)" -ErrorAction SilentlyContinue
                if ($websiteSlots.Count -gt 0) {
                    # for app slots
                    foreach ($slotName in $websiteSlots) {
                        Write-Host "Running for the slot $($slotName.Name)"
                        $config = Get-AzResource -ResourceId "$($slotName.Id)"
                        Write-Host "[BEFORE]FILECHANGEAUDIT Status $($slotName.Name) : $($config.Properties.siteConfig.fileChangeAuditEnabled)"
                        $config.Properties.siteConfig.fileChangeAuditEnabled = 'false'
                        $config.Properties.PSObject.Properties.Remove('ReservedInstanceCount')
                        $newCategories = @()
                        ForEach ($entry in $config.Properties.azureMonitorLogCategories) {
                            If ($entry -ne 'AppServiceFileAuditLogs') {
                                $newCategories += $entry
                            }
                        }
                        $config.Properties.siteConfig.azureMonitorLogCategories = $newCategories
                        $config | Set-AzResource -Force
                        Write-Host "[AFTER]FILECHANGEAUDIT Status $($slotName.Name) : $($config.Properties.siteConfig.fileChangeAuditEnabled)"
                        ('-' * 75)
                    }
                }
            }
            catch {
                Write-Output "Error: $($_.Exception.Message)"
            }
            ('-' * 75)
        }
    }
    catch {
        Write-Output "Error: $($_.Exception.Message)"
    }
}