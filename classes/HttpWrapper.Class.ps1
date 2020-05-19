class HttpWrapper {
    [scriptblock]$Scriptblock
    [int]$Port = 8080
    [int]$MaxThread = 100
    [int]$NumListenThread = 10
    hidden [System.Net.HttpListener]$Listener
    hidden [System.Management.Automation.Runspaces.RunspacePool]$RunspacePool
    hidden [string]$Prefix

    HttpWrapper (
        [scriptblock]$Scriptblock,
        [int]$Port,
        [int]$MaxThread,
        [int]$NumListenThread
    ) {
        $this.Scriptblock = $Scriptblock
        $this.Port = $Port
        $this.MaxThread = $MaxThread
        $this.NumListenThread = $NumListenThread
    }

    HttpWrapper (
        [scriptblock]$Scriptblock,
        [int]$Port
    ) {
        $this.Scriptblock = $Scriptblock
        $this.Port = $Port
    }

    HttpWrapper (
        [scriptblock]$Scriptblock
    ) {
        $this.Scriptblock = $Scriptblock
    }

    [void] Start (
    ) {
        Write-Verbose -Message "Setting up listener $($this.Prefix)"
        $this.Prefix = "http://+:$($this.Port)/"
        $this.listener = New-Object -TypeName System.Net.HttpListener
        $this.Listener.Prefixes.Add($this.Prefix)

        Write-Verbose -Message "Setting up runspace pool with max $($this.MaxThread) threads"
        $initial_session_state = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
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
        }


        $listen_scriptblock = {
            param($state)

            $state.Listener.BeginGetContext($state.RequestHandler, $state) |
                Out-Null

            while ($state.Listener.Listening) {
                Start-Sleep -Milliseconds 500
            }
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
            AddParameter('Response', $context.Response)

        # Execute the work
        $powershell.BeginInvoke() |
            Out-Null
    }
}