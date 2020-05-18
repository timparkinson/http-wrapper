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

    foreach ($dependency in $dependencies) {
        if (-not (Get-Module -Name $dependency.Name)) {
            Install-Module -Force -Name $dependency.Name -Repository $dependency.Repository -Scope $dependency.Scope
        }
    }
}

switch ($Task) {
    'Test' {
        Import-Module Pester
        Invoke-Pester
    }

    'Analyze' {
        Import-Module PSScriptAnalyzer
        $analysis = Invoke-ScriptAnalyzer -Path * -Verbose:$false

        $errors = $analysis |
            Where-Object {$_.Severity -eq 'Error'}

        $warnings = $analysis |
            Where-Object {$_.Severity -eq 'Warning'}

        if (($errors.Count -eq 0) -and ($warnings.Count -eq 0)) {
            '   PSScriptAnalyzer completed with no errors or warnings'
        }

        if (@($errors).Count -gt 0) {
            $errors | 
                Format-Table -AutoSize
                Write-Error -Message "$($errors.Count) PSScriptAnalyzer errors found."
        }

        if (@($warnings).Count -gt 0) {
            $warnings |
                Format-Table -AutoSize
                Write-Warning -Message "$($warnings.Count) PSScriptAnalyzer warnings found."
        }
    }
}