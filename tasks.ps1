[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet(
        'Test',
        'Analyze',
        'Build'
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

    'Build' {
        $build_path = Join-Path -Path $PSScriptRoot -ChildPath 'build'

        if (-not (Test-Path -Path $build_path)) {
            New-Item -ItemType Directory -Path $build_path
        }

        $name = Split-Path -Leaf -Path $PSScriptRoot

        @(
            "$name.psm1"
            "$name.psd1"
            "public/"
            "private/"
            "classes/"
        ) | ForEach-Object {
            Copy-Item -Recurse -Path (Join-Path -Path $PSScriptRoot -ChildPath $_) -Destination $build_path -Force -Confirm:$False
        }
    }
}