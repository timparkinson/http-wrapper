$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$module_path = Split-Path -Parent -Path $here
Import-Module "$module_path/http-wrapper.psd1"
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "New-HttpWrapper" {
    InModuleScope -ModuleName http-wrapper {
        It "creates an http wrapper object" {
            $result = New-HttpWrapper -Scriptblock {"hello world"}

            #$result | Should -BeOfType HttpWrapper
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
