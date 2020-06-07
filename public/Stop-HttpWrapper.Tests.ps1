BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $sut = (Split-Path -Leaf $here) -replace '\.Tests\.', '.'
    . "$here\$sut"
}

Describe "Stop-HttpWrapper" {

}
