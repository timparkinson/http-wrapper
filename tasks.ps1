[CmdletBinding()]
param(
    [Paraneter()]
    [ValidateSet('Test')]
    [string]$Task = 'Test'
)

switch ($Task) {
    'Test' {
        Import-Module Pester
        Invoke-Pester
    }
}