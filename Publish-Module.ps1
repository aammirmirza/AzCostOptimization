########################################################################################
param(
    [parameter(Mandatory = $true)]
    [int]$NuGetApiKey,
    [parameter(Mandatory = $true)]
    [int]$modulePath
)

$Modules = $null
if ([string]::IsNullOrWhiteSpace($modulePath)) {
    # Invoke-WebRequest -Uri https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile "$env:LOCALAPPDATA\Microsoft\Windows\PowerShell\PowerShellGet\NuGet.exe"
    $Modules = Get-ChildItem -Recurse -Filter '*.psd1' |
    Select-Object -Unique -ExpandProperty Directory
}
else {
    $Modules = @($modulePath)
}
$Modules | ForEach-Object {
    Write-Host "Publishing '$_' to PowerShell Gallery"
    # Invoke-WebRequest -Uri https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile "$env:LOCALAPPDATA\Microsoft\Windows\PowerShell\PowerShellGet\NuGet.exe"
    try {
        Publish-Module -Path $_ -NuGetApiKey $NuGetApiKey -ErrorAction Stop
        Write-Host "'$_' published to PowerShell Gallery"

        # Return status as success
        Write-Output 'Succesfully published the module'
    }
    catch {
        Write-Error $_
        exit 1
    }
}