function New-HttpWrapper {
    <#
        .SYNOPSIS
            Creates a new HttpWrapper object.
        .DESCRIPTION
            Creates a new HttpWrapper object.
        .PARAMETER Scriptblock
            The scriptblock to wrap. 
        .PARAMETER Port
            The port on which to listen.
        .PARAMETER MaxThread
            The maximum number of threads to use.
        .OUTPUTS
            [HttpWrapper]
        .EXAMPLE
            New-HttpWrapper -Scripblock {Get-Process} | Start-HttpWrapper
        
            Creates and starts a new HttpWrapper which will return teh processes on the machine.
    #>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$Scriptblock,
        [Parameter()]
        [int]$Port = 8080,
        [Parameter()]
        [int]$MaxThread = 100
    )

    begin {}

    process {
        New-Object -TypeName HttpWrapper -ArgumentList $Scriptblock, $Port, $MaxThread
    }

    end {}
}