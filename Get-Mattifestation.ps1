function Get-Mattifestation {
    <#
    .SYNOPSIS
    Function to calculate a user's mattifestations, the international
    standard unit of internet-famousness.

    TODO: -ATD flag to calculate the mattifestations of all ATD users.

    Function: Get-Mattifestations
    Author: @enigma0x3, @harmj0y
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None
    
    .EXAMPLE
    Get-Mattifestations -Handle enigma0x3
    
    .EXAMPLE
    "enigma0x3","harmj0y","sixdub" | Get-Mattifestation | Sort-Object Mattifestations -Descending | ft -AutoSize

    .LINK
    https://twitter.com/lee_holmes/status/289810790821789696
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$True,ValueFromPipeline=$True)]
        [string]$Handle
    )

    begin {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $WC = New-Object Net.WebClient
            if(($WC.DownloadString("http://twitter.com/mattifestation") -match '([,\d]+).*Followers')) {
                [int]$Mattifestation = $Matches[1]
            }
        }
        catch {
            throw "Error contacting twitter.com"
        }
    }
    process {
        
        if(($WC.DownloadString("http://twitter.com/$Handle") -match '([,\d]+).*Followers')) {
            [int]$User = $Matches[1] 
        }
     
        $Properties = @{
            Handle = $Handle
            Mattifestations = [double]("{0:N3}" -f ($User / $Mattifestation))
        }

        New-Object PSObject -Property $Properties
     }
 }
