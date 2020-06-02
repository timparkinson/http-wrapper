function Start-HttpWrapper {
    <#
        .SYNOPSIS
            Starts an HttpWrapper.
        .DESCRIPTION
            Starts an HttpWrapper.
        .PARAMETER HttpWrapper
            The HttpWrapper to start.
        .PARAMETER Wait
            When specified the cmdlet will wait until the HttpWrapper is no longer listening.
        .PARAMETER WaitCheckDelay
            The number of seconds to wait between checks when waiting.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true
        )]
        [HttpWrapper]$HttpWrapper,
        [Parameter(ParameterSetName)]
        [Switch]$Wait,
        [Parameter()]
        [int]$WaitCheckDelay = 1
    )

    begin {}

    process {
        Write-Verbose -Message "Starting HttpWrapper $($HttpWrapper.Prefix)"
        $HttpWrapper.Start()

        If ($Wait) {
            Write-Verbose -Message "HttpWrapper.Listener.IsListening: $($HttpWrapper.Listener.IsListening)"
            Write-Verbose -Message "Waiting for HttpWrapper $($HttpWrapper.Prefix) to finish listening"
            $stop_on_issue = $false
            while ($HttpWrapper.Listener.IsListening -and -not $stop_on_issue) {
                try {
                    Start-Sleep -Seconds $WaitCheckDelay
                } catch {
                    $stop_on_issue = $true
                }
            }
            Write-Verbose -Message "HttpWrapper $($HttpWrapper.Prefix) has finished listening"
        }
    }

    end {}
}