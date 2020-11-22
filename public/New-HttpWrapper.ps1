function New-HttpWrapper {
    <#
        .SYNOPSIS
            Creates a new HttpWrapper object.
        .DESCRIPTION
            Creates a new HttpWrapper object.
        .PARAMETER Scriptblock
            The scriptblock to wrap.
        .PARAMETER Module
            An array of modules to load into the servicing runspace.
        .PARAMETER Port
            The port on which to listen.
        .PARAMETER MaxThread
            The maximum number of threads to use.
        .PARAMETER NumListenThread
            The number of dispatcher threads to use.
        .PARAMETER Hostname
            The hostname to use when adding the listener prefix.
        .PARAMETER Scheme
            Use http/https.
        .PARAMETER AuthenticationScheme
            Set an authentication scheme.
        .OUTPUTS
            [HttpWrapper]
        .EXAMPLE
            New-HttpWrapper -Scripblock {Get-Process} | Start-HttpWrapper

            Creates and starts a new HttpWrapper which will return the processes on the machine.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$Scriptblock,
        [Parameter()]
        [string[]]$Module = @(
            'http-wrapper'
        ),
        [Parameter()]
        [scriptblock]$BootstrapScriptblock = {},
        [Parameter()]
        [scriptblock]$HealthScriptblock = {
            'OK'
        },
        [Parameter()]
        [string]$HealthPath = '^/healthz(\/)?$',
        [Parameter()]
        [int]$Port = 8080,
        [Parameter()]
        [int]$MinThread = 50,
        [Parameter()]
        [int]$MaxThread = 100,
        [Parameter()]
        [int]$NumListenThread = 10,
        [Parameter()]
        [string]$Hostname = '+',
        [Parameter()]
        [ValidateSet(
            'http',
            'https'
        )]
        [string]$Scheme = 'http',
        [Parameter()]
        [System.Net.AuthenticationSchemes]$AuthenticationScheme = [System.Net.AuthenticationSchemes]::Anonymous
    )

    begin {}

    process {
        if ($Module -notcontains 'http-wrapper') {
            $Module += 'http-wrapper'
        }
        
        $bootstrap_scriptblock = ConvertTo-BootstrapScriptblock -ScriptBlock $BootstrapScriptblock
        $health_scriptblock = ConvertTo-HealthScriptblock -Scriptblock $HealthScriptblock
        $http_scriptblock = ConvertTo-HttpScriptblock -ScriptBlock $Scriptblock 
        $wrapper = New-Object -TypeName HttpWrapper -ArgumentList $http_scriptblock, $Module, $bootstrap_scriptblock, $Port, $MinThread, $MaxThread, $NumListenThread, $Hostname, $Scheme
        
        if ($Scheme -eq 'https') {
            Write-Warning -Message "HTTPS scheme requires certificate binding."
        }

        $wrapper.SharedData.HealthPath = $HealthPath
        $wrapper.SharedData.HealthScriptblock = $health_scriptblock

        $wrapper.AuthenticationSchemes = $AuthenticationScheme

        $wrapper
    }

    end {}
}