class HttpWrapper {
    [scriptblock]$Scriptblock
    [scriptblock]$BootstrapScriptblock
    [int]$Port = 8080
    [int]$MinThread = 50
    [int]$MaxThread = 100
    [int]$NumListenThread = 10
    [string]$Hostname = '+'
    [string]$Scheme = 'http'
    [hashtable]$SharedData
    hidden [System.Net.HttpListener]$Listener
    hidden [System.Management.Automation.Runspaces.RunspacePool]$RunspacePool
    hidden [string]$Prefix
    hidden [string[]]$Module
    hidden [powershell[]]$ListenerRunspace
    hidden [System.Threading.ManualResetEvent]$StopListeners
    hidden [System.Net.AuthenticationSchemes]$AuthenticationSchemes = [System.Net.AuthenticationSchemes]::Anonymous

    HttpWrapper (
        [scriptblock]$Scriptblock,
        [string[]]$Module,
        [scriptblock]$BootstrapScriptblock,
        [int]$Port,
        [int]$MinThread,
        [int]$MaxThread,
        [int]$NumListenThread,
        [string]$Hostname,
        [string]$Scheme
    ) {
        $this.Scriptblock = $Scriptblock
        $this.Module = $Module
        $this.Port = $Port
        $this.BootstrapScriptblock = $BootstrapScriptblock
        $this.MinThread = $MinThread
        $this.MaxThread = $MaxThread
        $this.NumListenThread = $NumListenThread
        $this.Hostname = $Hostname
        $this.Scheme = $Scheme
        $this.SharedData = [hashtable]::Synchronized(@{})
    }

    HttpWrapper (
        [scriptblock]$Scriptblock,
        [string[]]$Module,
        [scriptblock]$BootstrapScriptblock,
        [int]$Port,
        [int]$MinThread,
        [int]$MaxThread,
        [int]$NumListenThread,
        [string]$Hostname
    ) {
        $this.Scriptblock = $Scriptblock
        $this.Module = $Module
        $this.Port = $Port
        $this.BootstrapScriptblock = $BootstrapScriptblock
        $this.MinThread = $MinThread
        $this.MaxThread = $MaxThread
        $this.NumListenThread = $NumListenThread
        $this.Hostname = $Hostname
        $this.SharedData = [hashtable]::Synchronized(@{})
    }

    HttpWrapper (
        [scriptblock]$Scriptblock,
        [string[]]$Module,
        [scriptblock]$BootstrapScriptblock,
        [int]$Port,
        [int]$MinThread,
        [int]$MaxThread,
        [int]$NumListenThread
    ) {
        $this.Scriptblock = $Scriptblock
        $this.Module = $Module
        $this.Port = $Port
        $this.BootstrapScriptblock = $BootstrapScriptblock
        $this.MinThread = $MinThread
        $this.MaxThread = $MaxThread
        $this.NumListenThread = $NumListenThread
        $this.SharedData = [hashtable]::Synchronized(@{})
    }

    HttpWrapper (
        [scriptblock]$Scriptblock,
        [string[]]$Module,
        [scriptblock]$BootstrapScriptblock,
        [int]$Port
    ) {
        $this.Scriptblock = $Scriptblock
        $this.Module = $Module
        $this.BootstrapScriptblock = $BootstrapScriptblock
        $this.Port = $Port
        $this.SharedData = [hashtable]::Synchronized(@{})
    }

    HttpWrapper (
        [scriptblock]$Scriptblock,
        [string[]]$Module,
        [scriptblock]$BootstrapScriptblock
    ) {
        $this.Scriptblock = $Scriptblock
        $this.Module = $Module
        $this.BootstrapScriptblock = $BootstrapScriptblock
        $this.SharedData = [hashtable]::Synchronized(@{})
    }

    [void] Start (
    ) {
        
        $this.Prefix = "$($this.Scheme)://$($this.Hostname):$($this.Port)/"
        Write-Verbose -Message "Setting up listener $($this.Prefix)"
        $this.listener = New-Object -TypeName System.Net.HttpListener
        $this.Listener.Prefixes.Add($this.Prefix)

        Write-Verbose "Setting listener authentication to $($this.AuthenticationSchemes.ToString())"
        $this.Listener.AuthenticationSchemes = $this.AuthenticationSchemes

        Write-Verbose -Message "Setting up runspace pool with max $($this.MaxThread) threads"
        $initial_session_state = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        $initial_session_state.ImportPSModule($this.Module)
        $this.RunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool($initial_session_state)
        $this.RunspacePool.SetMinRunspaces($this.MinThread)
        $this.RunspacePool.SetMaxRunspaces($this.MaxThread)
        $this.RunspacePool.Open()

        Write-Verbose -Message "Creating delegate for request handler"
        $method = [HttpWrapper].GetMethod('HandleRequest')
        $request_handler = [System.Delegate]::CreateDelegate([System.AsyncCallback], $null, $method)

        Write-Verbose -Message "Running bootstrapper"
        Invoke-Command -ScriptBlock $this.BootstrapScriptblock -ArgumentList $this.SharedData

        Write-Verbose -Message "Starting listener"
        $this.listener.Start()
        $this.StopListeners = New-Object -TypeName System.Threading.ManualResetEvent -ArgumentList $false

        Write-Verbose "Setting state to pass to delegate"
        $state = @{
            Listener = $this.Listener
            RequestHandler = $request_handler
            RunspacePool = $this.RunspacePool
            Scriptblock = $this.Scriptblock
            SharedData = $this.SharedData
            StopListeners = $this.StopListeners
        }

        $listen_scriptblock = {
            param($state)
            
            while ($state.Listener.IsListening) {
                $result = $state.Listener.BeginGetContext($state.RequestHandler, $state)
                $handle = $result.AsyncWaitHandle
                [System.Threading.WaitHandle]::WaitAny(@($state.StopListeners, $handle))
                $handle.Close()
                #$result.Dispose()
            }

        }

        Write-Verbose -Message "Starting $($this.NumListenThread) Listen threads"
        0..($this.NumListenThread-1) |
            ForEach-Object {
                $powershell = [System.Management.Automation.PowerShell]::Create()
                $powershell.Runspace = [RunspaceFactory]::CreateRunspace($initial_session_state).Open()
                $this.ListenerRunspace += $powershell

                $powershell.AddScript($listen_scriptblock).
                    AddParameter('state', $state)

                $powershell.BeginInvoke() 
            }
    }

    [void] Stop (
    ) {

        Write-Verbose -Message "Stopping listener"
        try {
            $this.Listener.Stop()
            $this.Listener.Close()
            if (-not ($this.StopListeners.Set())) {
                Write-Error -Message "Error signalling listener thread stop"
            }
        } catch {
            # Sometimes get an InvalidOperationException: Stack Empty
            Write-Warning "Exception stopping listener: $_"
        }
        
        Write-Verbose -Message "Pausing"
        Start-Sleep -Milliseconds 600 

        Write-Verbose -Message "Stopping Listener runspaces"
        $this.ListenerRunspace |
            ForEach-Object {
                try {
                    $_.Stop()
                    $_.Runspace.Dispose()
                    $_.Dispose()
                } catch {
                    # Just swallow any stop errors
                }
            }

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