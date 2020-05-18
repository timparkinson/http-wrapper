$public = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'public') | 
    Where-Object {$_.Name -notmatch '\.Tests\.ps1'}

$private = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'private') | 
    Where-Object {$_.Name -match '\.Tests\.ps1'}

$class_path = Join-Path -Path $PSScriptRoot -ChildPath 'classes'

$classes = @(
    'HttpWrapper.Class.ps1'
) |
    ForEach-Object {
        Get-Item -Path (Join-Path -Path $class_path -ChildPath $_)
    }

$public, $private, $classes |
    ForEach-Object {
        . $_.FullName
    }

Export-ModuleMember -Function $public.BaseName




