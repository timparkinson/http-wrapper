# http-wrapper

## What is it?

A small opinionated module to allow powershell code to be served over HTTP. 

## Why re-invent the wheel?

I've had various approaches to doing this in the past, for a few years I've been using a home grown DSL and code generator for the [Nancy Framework](https://nancyfx.org/). This was OK, if a little fragile, but something recently broke and because Nancy is not being maintained anymore I decided to look at options.

## Usage

```powershell
New-HttpWrapper -Verbose -ScriptBlock {@{'RunningOn'=$env:computername}} |
    Start-HttpWrapper -Verbose
```
