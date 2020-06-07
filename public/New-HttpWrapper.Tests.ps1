BeforeAll {
    $module_path = Join-Path -Path (Split-Path -Parent -Path (Split-Path -Parent -Path $PSCommandPath)) -ChildPath 'http-wrapper.psd1'
    Import-Module -Name $module_path
}

Describe "New-HttpWrapper" {

        It "creates an http wrapper object" {
            $result = New-HttpWrapper -Scriptblock {"hello world"}

            #$result | Should -BeOfType HttpWrapper
            $result | Should -Not -BeNullOrEmpty
        }

}
