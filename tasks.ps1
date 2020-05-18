[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet(
        'Test',
        'Analyze'
    )]
    [string]$Task = 'Test',
    [Parameter()]
    [switch]$Bootstrap
)

if ($Bootstrap) {
    Get-PackageProvider -Name Nuget -ForceBootstrap |
        Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

    $dependencies = Get-Content -Path "$PSScriptRoot/dependencies.json" -Raw |
        ConvertFrom-Json

    foreach ($depedency in $dependencies) {
        if (-not (Get-Module -Name $dependency.Name)) {
            Install-Module -Force @depedency
        }
    }
}

switch ($Task) {
    'Test' {
        Import-Module Pester
        Invoke-Pester
    }

    'Analyze' {

    }
}