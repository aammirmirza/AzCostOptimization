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
        $AzureContext = (Connect-AzAccount -Identity).context
    }
    catch {
        Write-Output 'There is no system-assigned user identity. Aborting. Setup the same or try using RunAs account automation method.';
    }
    Try {
        # $subscriptionId = 'e925f9e8-74d0-48a2-a05d-428ac3696c49'
        # Set-AzContext $subscriptionId
        # $appServiceRG = 'weu-sc93-preprd-rg' #Resource Group Name"
        # $aspName = 'weu-sc93-preprd-rg-365400-xc-basic-hp' #Name of App Service Plan
        $asp = Get-AzAppServicePlan -ResourceGroupName $appServiceRG -Name $aspName -ErrorAction Stop
        $web = Get-AzWebApp -AppServicePlan $asp -ErrorAction SilentlyContinue
        foreach ($webApp in ($web | Where-Object { ($_.State -eq 'Running') })) {
            Write-Output ('*' * 75)
            Write-Output ('App Name : {0}' -F $webApp.Name)
            Write-Output ('*' * 75)
            # to handle production (not slots)
            if ($Slot -ne $true) {
                $config = Get-AzResource -ResourceGroupName $appServiceRG `
                    -ResourceType 'Microsoft.Web/sites/config' `
                    -ResourceName "$($webApp.Name)/web" `
                    -ApiVersion 2016-08-01
            }
            # to handle the slots
            if ($Slot -eq $true) {
                # for app slots
                $appServiceName = "$($webApp.Name)/staging"
                $config = Get-AzResource -ResourceGroupName $appServiceRG `
                    -ResourceType 'Microsoft.Web/sites/slots' `
                    -ResourceName "$($appServiceName)" `
                    -ApiVersion 2016-08-01 -ErrorAction SilentlyContinue
            }
            Write-Host "       Current FILECHANGEAUDIT Status for the $($webApp.Name) : $($config.Properties.fileChangeAuditEnabled)"
            $config.Properties.fileChangeAuditEnabled = 'false'
            $config.Properties.PSObject.Properties.Remove('ReservedInstanceCount')

            $newCategories = @()

            ForEach ($entry in $config.Properties.azureMonitorLogCategories) {
                If ($entry -ne 'AppServiceFileAuditLogs') {
                    $newCategories += $entry
                }
            }
            $config.Properties.azureMonitorLogCategories = $newCategories
            $config | Set-AzResource -Force
        }
    }
    catch {
        Write-Output "Error: $($_.Exception.Message)"
    }
}