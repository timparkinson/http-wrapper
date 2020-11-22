
BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $module_path = Split-Path -Parent -Path $here
    Import-Module "$module_path/http-wrapper.psd1"
    
    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        # Generate certificate and import it
        try {
            $cert = New-SelfSignedCertificate -DnsName http-wrapper-test -CertStoreLocation cert:\LocalMachine\My -NotAfter (Get-Date).AddYears(10)
            & netsh http add sslcert ipport=0.0.0.0:8443 certhash=$($cert.ThumbPrint) "appid={00112233-4455-6677-8899-AABBCCDDEEFF}"
            $cert_enroll = $true
        } catch {
            Write-Warning -Message "Certificate enrollment failed - HTTPS will not be tested: $_"
            $cert_enroll = $false
        }
    }

}

Describe "Server" {
    
    BeforeAll {
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

        if ($cert_enroll) {
            $https_server = New-HttpWrapper -Scheme 'https' -Port '8443' -Scriptblock {
                'https_test'
            }

            Start-HttpWrapper -HttpWrapper $https_server
        }

    }


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
        
        if ($PSVersionTable.PSEdition -eq 'Core') {
            $results = 1..6 | ForEach-Object -Parallel {
                Invoke-RestMethod -Uri "http://localhost:8080/sleep"
            }
        } else {
            $results = 1..6 | ForEach-Object  {
                Start-Job -ScriptBlock {Invoke-RestMethod -Uri "http://localhost:8080/sleep"}
            }
        }
        #start-sleep -Milliseconds 600
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

    It "sends an X-Call-Id header" {
        $result = Invoke-WebRequest -Uri "http://localhost:$port/basic"

        $result.Headers['X-Call-Id'] | 
            Should -Not -BeNullOrEmpty
    }

    It "returns the same X-Call-Id header when present" {
        $result = Invoke-WebRequest -Uri "http://localhost:$port/basic" -Headers @{'X-Call-Id' = 'TESTCALLID'}

        $result.Headers['X-Call-Id'] |
            Should -Be 'TESTCALLID'
    }

    It "handles errors" {
        {Invoke-RestMethod -Uri "http://localhost:$port/error"} | 
            Should -Throw
    }

    It "doesn't error on the next call" {
        $result = Invoke-RestMethod -Uri "http://localhost:$port/basic"

        $result.hello | Should -Be 'world'
    }

    It "handles health requests" {
        $result = Invoke-RestMethod -Uri "http://localhost:$port/healthz"

        $result |
            Should -Be 'OK'
    }

    It "stops" {
        Stop-HttpWrapper -HttpWrapper $server
    
        $server.Listener.IsListening | Should -Be $false
    }

    It "starts again" {
        Start-HttpWrapper -HttpWrapper $server 

        $server.Listener.IsListening | Should -Be $true
    }

    It "gets a result after stop/start" {
        $result = Invoke-RestMethod -Uri "http://localhost:$port/basic"

        $result.hello | Should -Be 'world'
    }

    It "stops again" {
        Stop-HttpWrapper -HttpWrapper $server
    
        $server.Listener.IsListening | Should -Be $false
    }

    
    It "has an HTTPS endpoint" {
        if ($cert_enroll) {
            if (-not("dummy" -as [type])) {
                add-type -TypeDefinition @"
            using System;
            using System.Net;
            using System.Net.Security;
            using System.Security.Cryptography.X509Certificates;
            
            public static class Dummy {
                public static bool ReturnTrue(object sender,
                    X509Certificate certificate,
                    X509Chain chain,
                    SslPolicyErrors sslPolicyErrors) { return true; }
            
                public static RemoteCertificateValidationCallback GetDelegate() {
                    return new RemoteCertificateValidationCallback(Dummy.ReturnTrue);
                }
            }
"@
            }
            
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [dummy]::GetDelegate()
            $result = Invoke-RestMethod -Uri "https://localhost:8443/" 

            $result | Should -Be "https_test"
        }
    }

    AfterAll {
        Remove-Variable -Name server -Force

        if ($cert_enroll) {
            Stop-HttpWrapper -HttpWrapper $https_server
            Remove-Variable -Name https_server -Force
        }
    }

}