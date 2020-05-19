$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$module_path = Split-Path -Parent -Path $here
Import-Module "$module_path/http-wrapper.psd1"

Describe "Server" {
    $server = New-HttpWrapper -Scriptblock {Start-Sleep -Seconds 1; @{'hello'='world'}}
    It "creates a server" {
        $server | Should -Not -BeNullOrEmpty
    }

    It "should start" {
        Start-HttpWrapper -HttpWrapper $server

        $server.Listener.IsListening | Should -Be $true
    }

    It "gets a result" {
        $result = Invoke-RestMethod -Uri http://localhost:8080/

        $result.hello | Should -Be 'world'
    }

    It "gets a second result" {
        $result = Invoke-RestMethod -Uri http://localhost:8080/

        $result.hello | Should -Be 'world'
    }

    It "handles multiple concurrent connections" {
        $timer = [System.Diagnostics.Stopwatch]::new()

        $timer.Start()
        1..5 | ForEach-Object -Parallel {
            $result = Invoke-RestMethod -uri http://localhost:8080/
        }
        $timer.Stop()

        $timer.Elapsed.TotalSeconds | Should -BeLessThan 5
    }

    It "stops" {
        Stop-HttpWrapper -HttpWrapper $server

        $server.Listener.IsListening | Should -Be $false
    }

}