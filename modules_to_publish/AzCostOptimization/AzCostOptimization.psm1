# Export all PowerShell script files in this directory and its subdirectories
$files = Get-ChildItem -Path $PSScriptRoot\*-*.ps1 -Recurse
foreach ($file in $files) {
    . $file.FullName
}

# Export all aliases and verb-noun functions
Export-ModuleMember -Alias * -Function *-*