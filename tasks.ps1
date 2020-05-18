[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Test')]
    [string]$Task = 'Test'
)

switch ($Task) {
    'Test' {
        if (-not (Get-Module -Name 'Pester')) {
            Get-PackageProvider -Name Nuget -ForceBootstrap |
                Out-Null
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
            Install-Module -Name Pester -Repository PSGAllery -Scope CurrentUser -Force
        }

        Import-Module Pester
        Invoke-Pester
    }
}