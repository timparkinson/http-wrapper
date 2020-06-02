class HttpWrapper {
    [scriptblock]$Scriptblock
    [int]$Port = 8080
    [int]$MinThread = 50
    [int]$MaxThread = 100
    [int]$NumListenThread = 10
    [hashtable]$SharedData
    hidden [System.Net.HttpListener]$Listener
    hidden [System.Management.Automation.Runspaces.RunspacePool]$RunspacePool
    hidden [string]$Prefix
    hidden [string[]]$Module

    HttpWrapper (
        [scriptblock]$Scriptblock,
        [string[]]$Module,
        [int]$Port,
        [int]$MinThread,
        [int]$MaxThread,
        [int]$NumListenThread
    ) {
        $this.Scriptblock = $Scriptblock
        $this.Module = $Module
        $this.Port = $Port
        $this.MinThread = $MinThread
        $this.MaxThread = $MaxThread
        $this.NumListenThread = $NumListenThread
        $this.SharedData = [hashtable]::Synchronized(@{})
    }

    HttpWrapper (
        [scriptblock]$Scriptblock,
        [string[]]$Module,
        [int]$Port
    ) {
        $this.Scriptblock = $Scriptblock
        $this.Module = $Module
        $this.Port = $Port
        $this.SharedData = [hashtable]::Synchronized(@{})
    }

    HttpWrapper (
        [scriptblock]$Scriptblock,
        [string[]]$Module
    ) {
        $this.Scriptblock = $Scriptblock
        $this.Module = $Module
        $this.SharedData = [hashtable]::Synchronized(@{})
    }

    [void] Start (
    ) {
        Write-Verbose -Message "Setting up listener $($this.Prefix)"
        $this.Prefix = "http://+:$($this.Port)/"
        $this.listener = New-Object -TypeName System.Net.HttpListener
        $this.Listener.Prefixes.Add($this.Prefix)

        Write-Verbose -Message "Setting up runspace pool with max $($this.MaxThread) threads"
        $initial_session_state = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        $initial_session_state.ImportPSModule($this.Module)
        $this.RunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool($initial_session_state)
        $this.RunspacePool.SetMaxRunspaces($this.MaxThread)
        $this.RunspacePool.Open()

        Write-Verbose -Message "Creating delegate for request handler"
        $method = [HttpWrapper].GetMethod('HandleRequest')
        $request_handler = [System.Delegate]::CreateDelegate([System.AsyncCallback], $null, $method)

        Write-Verbose -Message "Starting listener"
        $this.listener.Start()

        Write-Verbose "Setting state to pass to delegate"
        $state = @{
            Listener = $this.Listener
            RequestHandler = $request_handler
            RunspacePool = $this.RunspacePool
            Scriptblock = $this.Scriptblock
            SharedData = $this.SharedData
        }


        $listen_scriptblock = {
            param($state)

            $state.Listener.BeginGetContext($state.RequestHandler, $state) |
                Out-Null

        }

        Write-Verbose -Message "Starting $($this.NumListenThread) Listen threads"
        0..($this.NumListenThread-1) |
            ForEach-Object {
                $powershell = [System.Management.Automation.PowerShell]::Create()
                $powershell.RunspacePool = $state.RunspacePool

                $powershell.AddScript($listen_scriptblock).
                    AddParameter('state', $state)

                $powershell.BeginInvoke() |
                    Out-Null
            }
    }

    [void] Stop (
    ) {

        Write-Verbose -Message "Stopping listener"
        $this.Listener.Stop()
        $this.Listener.Prefixes.Remove($this.Prefix)

        Write-Verbose -Message "Pausing"
        Start-Sleep -Milliseconds 500 

        Write-Verbose -Message "Closing runspace pool"
        $this.RunspacePool.Close()
    }

    static [void] HandleRequest (
        [System.IASyncResult]$Result
    ) {
        try {
            # End Async context
            $state = $Result.AsyncState
            $context = $state.Listener.EndGetContext($Result)

            # Next connection
            $state.Listener.BeginGetContext($state.RequestHandler, $state) |
                Out-Null

            # Setup work in runspace
            $powershell = [System.Management.Automation.PowerShell]::Create()
            $powershell.RunspacePool = $state.RunspacePool

            $powershell.AddScript($state.Scriptblock).
                AddParameter('Request', $context.Request).
                AddParameter('Response', $context.Response).
                AddParameter('SharedData', $state.SharedData)

            # Execute the work
            $powershell.BeginInvoke() |
                Out-Null
        } catch {
            # A final context is triggered on stop. This is a blunt way of trapping it.
        }
    }
}