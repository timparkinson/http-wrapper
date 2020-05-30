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
        [int]$Port = 8080,
        [Parameter()]
        [int]$MaxThread = 100,
        [Parameter()]
        [int]$NumListenThread = 10
    )

    begin {}

    process {
        if ($Module -notcontains 'http-wrapper') {
            $Module += 'http-wrapper'
        }
        
        $http_scriptblock = ConvertTo-HttpScriptBlock -ScriptBlock $Scriptblock
        New-Object -TypeName HttpWrapper -ArgumentList $http_scriptblock, $Module, $Port, $MaxThread, $NumListenThread
    }

    end {}
}