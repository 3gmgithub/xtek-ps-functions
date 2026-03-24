Function getXfunc {
    # Download helper functions
    $xtekpsfuncURL = "https://raw.githubusercontent.com/3gmgithub/xtek-ps-functions/main/xtekpsfunc.ps1"

    If (Test-Path -Path "${ENV:temp}\xtekpsfunc.ps1" -PathType Leaf) {
        Write-Host "${ENV:temp}\xtekpsfunc.ps1 already downloaded, skipping..."
    } else {
        Write-Host "${ENV:temp}\xtekpsfunc.ps1 missing, downloading..."
        Invoke-WebRequest -Uri $xtekpsfuncURL -OutFile "${ENV:temp}\xtekpsfunc.ps1"
    }
}

getXfunc
# Import helper functions
. ${ENV:temp}\xtekpsfunc.ps1

enableBitlocker