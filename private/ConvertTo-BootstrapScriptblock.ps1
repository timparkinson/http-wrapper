function ConvertTo-BootstrapScriptblock {
    <#
        .SYNOPSIS
            Converts a scriptblock to a bootstrap scriptblock.
        .DESCRIPTION
            Converts a scriptblock to a bootstrap scriptblock.
        .PARAMETER Scriptblock
            The scriptblock to convert.
    #>   
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$Scriptblock
    )

    begin {
        $wrapper_scriptblock = {
            param(
                [hashtable]$SharedData
            )

            REPLACEWITHSCRIPTBLOCK
        }
    }

    process {
        [scriptblock]::Create($wrapper_scriptblock.ToString().Replace('REPLACEWITHSCRIPTBLOCK',$Scriptblock.ToString()))
    }

    end {}
}