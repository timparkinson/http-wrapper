$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$module_path = Split-Path -Parent -Path $here
Import-Module "$module_path/http-wrapper.psd1"

Describe "Server" {
    $port_basic = 8080
    $port_sleep = 8081
    $port_module = 8082

    $server_basic = New-HttpWrapper -Scriptblock {@{'hello'='world'}} -Port $port_basic
    $server_sleep = New-HttpWrapper -Scriptblock {Start-Sleep -Seconds 10; @{'hello'='world'}} -Port $port_sleep
    $server_module = New-HttpWrapper -Scriptblock {(Get-Module).Name} -Port $port_module -Module 'Microsoft.Powershell.Archive'

    Start-HttpWrapper -HttpWrapper $server_basic
    Start-HttpWrapper -HttpWrapper $server_sleep
    Start-HttpWrapper -HttpWrapper $server_module
    
    It "creates a server" {
        $server_basic | Should -Not -BeNullOrEmpty
    }

    It "should start" {
        $server_basic.Listener.IsListening | Should -Be $true
        $server_sleep.Listener.IsListening | Should -Be $true
        $server_module.Listener.IsListening | Should -Be $true
    }

    It "gets a result" {
        $result = Invoke-RestMethod -Uri "http://localhost:$port_basic/"

        $result.hello | Should -Be 'world'
    }

    It "gets a second result" {
        $result = Invoke-RestMethod -Uri "http://localhost:$port_basic/"

        $result.hello | Should -Be 'world'
    }

    It "handles multiple concurrent connections" {
        $timer = [System.Diagnostics.Stopwatch]::new()

        $timer.Start()
        1..5 | ForEach-Object  {
            Start-Job -ScriptBlock {Invoke-RestMethod -Uri "http://localhost:$($using:port_sleep)/"}
        }
        $results = Get-Job | Receive-Job -Wait
        $timer.Stop()
        $timer.Elapsed.TotalSeconds | Should -BeLessThan 50
        $results | ForEach-Object {
            $_.hello | Should -Be 'world'
        }
    }

    It "loads modules" {
        $result = Invoke-RestMethod -Uri "http://localhost:$port_module/"

        $result | Should -Contain 'Microsoft.Powershell.Archive'
    }

    It "stops" {
        Stop-HttpWrapper -HttpWrapper $server_basic
        Stop-HttpWrapper -HttpWrapper $server_sleep
        Stop-HttpWrapper -HttpWrapper $server_module

        $server_basic.Listener.IsListening | Should -Be $false
        $server_sleep.Listener.IsListening | Should -Be $false
        $server_module.Listener.IsListening | Should -Be $false
    }

}