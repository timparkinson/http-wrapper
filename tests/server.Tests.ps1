
BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $module_path = Split-Path -Parent -Path $here
    Import-Module "$module_path/http-wrapper.psd1"
    
    $port = 8080
    $hostname = 'localhost'

    $scriptblock = {
        if ($Request.Url.AbsolutePath -match '\/(?<route>\w+)') {
            $route = $matches.route
        } else {
            Write-Error -Message "No route found" -ErrorAction Stop
        }
        
        switch ($route) {
            'basic' {
                @{'hello'='world'}
            }

            'sleep' {
                Start-Sleep -Seconds 10 
                @{'hello'='world'}
            }

            'module' {
                (Get-Module).Name
            }

            'shared' {
                @{'hello'=$SharedData.hello}
            }

            'error' {
                Write-Error -Message 'oh noes' -ErrorAction Stop
            }

            'requestresponse' {
                @{'request' = $Request; 'response' = $Response}
            }
        }
       
    }
    
    $server = New-HttpWrapper -Scriptblock $scriptblock -Port $port -NumListenThread 10 -Module 'Microsoft.Powershell.Archive' -BootstrapScriptblock {$SharedData.bootstrap = 'banana'} -Hostname $hostname
    
    Start-HttpWrapper -HttpWrapper $server
}
Describe "Server" {
    
    It "creates a server" {
        $server | Should -Not -BeNullOrEmpty
    }

    It "should start" {
        $server.Listener.IsListening | Should -Be $true
    }

    It "gets a result" {
        $result = Invoke-RestMethod -Uri "http://localhost:$port/basic"

        $result.hello | Should -Be 'world'
    }

    It "gets a second result" {
        $result = Invoke-RestMethod -Uri "http://localhost:$port/basic"

        $result.hello | Should -Be 'world'
    }

    It "handles multiple concurrent connections" {
        $timer = [System.Diagnostics.Stopwatch]::new()

        $timer.Start()
        
        $results = 1..6 | ForEach-Object  {
            Start-Job -ScriptBlock {Invoke-RestMethod -Uri "http://localhost:8080/sleep"}
           #Invoke-RestMethod -Uri "http://localhost:$($using:port_sleep)/"
        }
        $results = Get-Job | Receive-Job -Wait
        $timer.Stop()
        $timer.Elapsed.TotalSeconds | Should -BeLessThan 50
        $results | ForEach-Object {
            $_.hello | Should -Be 'world'
        }
    }

    It "loads modules" {
        $result = Invoke-RestMethod -Uri "http://localhost:$port/module"

        $result | Should -Contain 'Microsoft.Powershell.Archive'
    }

    It "allows SharedData to be passed" {
        $server.SharedData.hello = 'worldshared'

        $result = Invoke-RestMethod -Uri "http://localhost:$port/shared"

        $result.hello | Should -Be 'worldshared'
        
    }

    It "runs a setup script block" {
        $server.SharedData.bootstrap | Should -Be 'banana'
    }

    It "accesses request/response" {
        $result = Invoke-RestMethod -Uri "http://localhost:$port/requestresponse"

        $result.request | Should -Not -BeNullOrEmpty
        $result.response | Should -Not -BeNullOrEmpty
    }

    It "handles errors" {
        {Invoke-RestMethod -Uri "http://localhost:$port/error"} | 
            Should -Throw
    }

    It "stops" {
        Stop-HttpWrapper -HttpWrapper $server
    
        $server.Listener.IsListening | Should -Be $false
    }

}