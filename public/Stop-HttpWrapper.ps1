function Stop-HttpWrapper {
    <#
        .SYNOPSIS
            Stops an HttpWrapper.
        .DESCRIPTION
            Stops an HttpWrapper.
        .PARAMETER HttpWrapper
            The HttpWrapper to stop.
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
        Write-Verbose -Message "Stopping HttpWrapper $($HttpWrapper.Prefix)"
        $HttpWrapper.Stop()
    }

    end {}
}