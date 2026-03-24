Function getXfunc {
    # Download helper functions
    $xtekpsfuncURL = "https://raw.githubusercontent.com/3gmgithub/xtek-ps-functions/main/xtekpsfunc.ps1"

    If (Test-Path -Path "${scriptdir}\xtekpsfunc.ps1" -PathType Leaf) {
        Write-Host "${scriptdir}\xtekpsfunc.ps1 already downloaded, skipping..."
    } else {
        Write-Host "${scriptdir}\xtekpsfunc.ps1 missing, downloading..."
        Invoke-WebRequest -Uri $xtekpsfuncURL -OutFile "${scriptdir}\xtekpsfunc.ps1"
    }
}

$scriptdir = Get-ScriptPath

getXfunc
# Import helper functions
. ${scriptdir}\xtekpsfunc.ps1

enableBitlocker