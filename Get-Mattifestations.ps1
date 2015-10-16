function Get-Mattifestations {
    <#
    .SYNOPSIS
    Powershell script that will calculate your total mattifestations
    .DESCRIPTION
    This script will fetch @mattifestations twitter followers and then fetch the followers of the passed twitter handle. It will then use those
    numbers to calculate the total mattifestions.

    Function: Get-Mattifestations
    Author: @enigma0x3, @harmj0y
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None

    .EXAMPLE
    Get-Mattifestations -Handle enigma0x3
    
    .EXAMPLE
    "enigma0x3","harmj0y","sixdub" | Get-Mattifestations

    .LINK
    https://twitter.com/lee_holmes/status/289810790821789696
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$True,ValueFromPipeline=$True)]
        [string]$Handle
    )

    begin {
        $wc = New-Object Net.Webclient
        if(($wc.DownloadString("http://twitter.com/mattifestation") -match '([,\d]+).*Followers')) {
            [int]$mattifestation = $matches[1]
        }
    }
    process {
        
        if(($WC.DownloadString("http://twitter.com/$Handle") -match '([,\d]+).*Followers')) {
            [int]$user = $matches[1] 
        }
     
        $Totalmattifestations = $user/ $mattifestation
        "$Handle is $Totalmattifestations total mattifestations!!!!"
     }

 }
