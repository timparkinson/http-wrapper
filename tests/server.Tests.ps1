$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$module_path = Split-Path -Parent -Path $here
Import-Module "$module_path/http-wrapper.psd1"

Describe "Server" {
    $server = New-HttpWrapper -Scriptblock {@{'hello'='world'}}
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

    It "stops" {
        Stop-HttpWrapper -HttpWrapper $server

        $server.Listener.IsListening | Should -Be $false
    }
}