function ConvertTo-HTTPScriptblock {
    <#
        .SYNOPSIS
            Adds required HTTP functionality to an existing scriptblock.
        .DESCRIPTION
            Tops and tails a scriptblock with the required basic functionality to make it function over HTTP.
        .PARAMETER ScriptBlock
            The scriptblock to convert for HTTPS usage
        .EXAMPLE
            $new_scriptblock = ConvertTo-HTTPCScriptblock -ScriptBlock {Get-Process}
        .OUTPUTS
            System.Management.Automation.ScriptBlock
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
    [OutputType([System.Management.Automation.ScriptBlock])]

    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock
    )

    begin {
        $wrapper_scriptblock = {
            param(
                [System.Net.HttpListenerRequest]
                $Request,
                [System.Net.HttpListenerResponse]
                $Response,
                [hashtable]
                $SharedData
            )

            # Generate a call ID
            $call_id = (New-Guid).Guid       

            try {
                $output = Invoke-Command -ScriptBlock {
                    REPLACEWITHSCRIPTBLOCK
                } 
            } catch {
                $status_code = [System.Net.HttpStatusCode]::InternalServerError
                $content = $_.ToString()
                $content_type = ''
            }

            if (-not $status_code) {
                $status_code = [System.Net.HttpStatusCode]::OK
            }

            if ($output) {
                $json_output = $output |
                    ConvertTo-Json -Depth 100
                $content_type = 'text/json'
            }

            $buffer = [Text.Encoding]::UTF8.GetBytes($json_output)

            # Add headers
            $Response.Headers.Add('X-Call-Id', $call_id)

            $Response.StatusCode = $status_code
            $Response.ContentType = $content_type
            $Response.ContentLength64 = $buffer.Length
            $Response.OutputStream.Write($buffer, 0, $buffer.Length)

            $Response.Close()
        }
    }

    process {
        [scriptblock]::Create($wrapper_scriptblock.ToString().Replace('REPLACEWITHSCRIPTBLOCK',$Scriptblock.ToString()))
    }

}
