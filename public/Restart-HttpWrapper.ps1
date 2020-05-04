function Restart-HttpWrapper {
    <#
        .SYNOPSIS
            Restarts an HttpWrapper.
        .DESCRIPTION
            Restarts an HttpWrapper.
        .PARAMETER HttpWrapper
            The HttpWrapper to restart.
    #>
    [CmdletBinding()]

    param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true
        )]
        [HttpWrapper]$HttpWrapper
    )

    begin {}

    process {
        Write-Verbose -Message "Restarting HttpWrapper $($HttpWrapper.Prefix)"
        Stop-HttpWrapper -HttpWrapper $HttpWrapper
        Start-HttpWrapper -HttpWrapper $HttpWrapper
    }

    end {}
}