# List of functions

# Converts Powershell style variables to Batch Style Variables
function ConvertPSVarToBatchVar {
    param($value)
    # Find stuff between two () have to escape the () with \
    $tempvalue = $value | Select-String -Pattern '\(.*\)'

    # Get match value
    $tempvalue = $tempvalue.Matches.value

    # Save this for later
    $psvalue = '{0}' -f $tempvalue
    $psvalue = '$' + $psvalue

    # Get stuff after : before )
    $tempvalue = $tempvalue.Substring(6,$tempvalue.Length-7)

    # Convert PS Var to Batch Var
    $batchvalue = '%{0}%' -f $tempvalue

    # Put replace the value with the batch variable
    $value = $value.replace($psvalue,$batchvalue)

    Return $value
}

# Install Chocolatey
function installchocolatey {
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Adds a Debug pause to the script
function debugpause {
    # If running in the console, wait for input before closing.
    if ($Host.Name -eq "ConsoleHost")
    {
        Write-Host "Press any key to continue..."
        $Host.UI.RawUI.FlushInputBuffer()   # Make sure buffered input doesn't "press a key" and skip the ReadKey().
        $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") > $null
    }

}

# Downloads files with some error checking
function downloadinstaller {
    param (
        $downloadfile,
        $output,
        $useragent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.3',
        $notest = 'n'
    )

    $outpath = Get-ScriptPath
    $link = $downloadfile.split('/')
    $outfile = '{0}\{1}' -f $outpath,$output

    if ($notest -eq 'y') {
        try {
            Invoke-WebRequest -Uri $downloadfile -UserAgent $useragent -OutFile "$outfile"
            If (Test-Path -Path $outfile -PathType Leaf) {
                Write-Host "$outfile exists continuing..." 
            }
        } catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Error -Message "$ErrorMessage $FailedItem"
        }
    } else {
        $connectresult = NetTest $link[2]
        if ($connectresult -eq $true){
            try {
                Invoke-WebRequest -Uri $downloadfile -UserAgent $useragent -OutFile "$outfile"
                If (Test-Path -Path $outfile -PathType Leaf) {
                    Write-Host "$outfile exists continuing..." 
                }
            } catch {
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Write-Error -Message "$ErrorMessage $FailedItem"
            }
        } else {
            Write-Output "Unable to connect to server"
        }
    }
}


# Download latest or pre-release files from a public Git Repository
function downloadGit {
    param ($repo, $filenamePattern, $preRelease, $output, $getver)
    $outpath = Get-ScriptPath
    $outfile = '{0}\{1}' -f $outpath,$output

    if ($preRelease) {
        $releasesUri = "https://api.github.com/repos/$repo/releases"
        if ($getver) {
            $ver = (Invoke-RestMethod -Method GET -Uri $releasesUri).tag_name
            return $ver
        } else {
            $downloadUri = ((Invoke-RestMethod -Method GET -Uri $releasesUri)[0].assets | Where-Object name -like $filenamePattern ).browser_download_url
        }
    }
    else {
        $releasesUri = "https://api.github.com/repos/$repo/releases/latest"
        if ($getver) {
            $ver = (Invoke-RestMethod -Method GET -Uri $releasesUri).tag_name
            return $ver
        } else {
            $downloadUri = ((Invoke-RestMethod -Method GET -Uri $releasesUri).assets | Where-Object name -like $filenamePattern ).browser_download_url
        }
    }

    $link = $downloadUri.split('/')
    $connectresult = NetTest $link[2]
    
    if ($connectresult -eq $True){
        Try
        {  
            Invoke-WebRequest -Uri $downloadUri -OutFile "$outfile"
            If (Test-Path -Path $outfile -PathType Leaf) {
                Write-Host "$outfile exists continuing..." 
            }
        }
        Catch
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Error -Message "$ErrorMessage $FailedItem"
        }
    } else {
        Write-Output "Unable to connect to server"
    }


}

# Download latest file from private repository
function downloadPrivateGitRepo {
    param(
        $downDir,
        $gitToken,
        $gitRepo,
        $gitOwner,
        $gitUrl,
        $gitScriptTXT,
        $gitFile
    )

    function Get-AssetID {
        $gitAssetID = 'none'
        
        $gitAssetHeader = @{
            'Authorization' = "token $gitToken"
        }
    
        $gitAsset = Invoke-RestMethod -Uri "$gitUrl/latest" -Headers $gitAssetHeader
    
        $gitAsset.assets | ForEach-Object {
       
            if ($_.name -eq "$gitFile") {
                $gitAssetID = $_.id
            }    
        }
    
       return $gitAssetID
    }

    function Get-LatestScript {

        $gitDownloadHeader = @{
            'Authorization' = "token $gitToken"
            'Accept' = 'application/octet-stream'
        }
    
        $output = "$downDir\$gitFile"
        $assetID = Get-AssetID
    
        
        if ($gitScriptTXT -eq 'y') {
            Invoke-RestMethod -Uri "$gitUrl/assets/$assetID" -Headers $gitDownloadHeader -ContentType 'text/plain; charset=utf-8'
        } else {
            Write-Host "Downloading latest script..."
            Invoke-RestMethod -Uri "$gitUrl/assets/$assetID" -Headers $gitDownloadHeader -OutFile $output
        }
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    if ($null -eq $downDir) {
        $downDir = Get-ScriptPath
    }

    Get-LatestScript
}

# Returns current scriptpath weather v2.0 or greater powershell
function Get-ScriptPath {
    # If using PowerShell ISE
    if ($psISE)
    {
        $ScriptPath = Split-Path -Parent -Path $psISE.CurrentFile.FullPath
    }
    # If using PowerShell 3.0 or greater
    elseif($PSVersionTable.PSVersion.Major -gt 3)
    {
        $ScriptPath = $PSScriptRoot
    }
    # If using PowerShell 2.0 or lower
    else
    {
        $ScriptPath = split-path -parent $MyInvocation.MyCommand.Path
    }

    # If still not found
    # I found this can happen if running an exe created using PS2EXE module
    if(-not $ScriptPath) {
        $ScriptPath = [System.AppDomain]::CurrentDomain.BaseDirectory.TrimEnd('\')
    }

    # Return result
    return $ScriptPath
}

# Installs MSI files
function installmsi {
    param ($filename, $customargs)
    $scriptdir = Get-ScriptPath
    $fullfilename = '{0}\{1}' -f $scriptdir,$filename 
    $logFile = '{0}-{1}.log' -f $filename,$timestamp
    if ($customargs.count -eq 0) {
        $MSIArguments = @("/i", ('"{0}"' -f $fullfilename), "/qn", "/norestart", "/L*v", ('"{0}"' -f $logFile))
    } else {
        $MSIArguments = @("/i", ('"{0}"' -f $fullfilename), "/qn", "/norestart", "/L*v", ('"{0}"' -f $logFile))
        $MSIArguments += $customargs
    }
    Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
}

# Completes a simple network test
function NetTest {
    param ($link)

    $X = 0
        do {
        Write-Output "Waiting for network"
        Start-Sleep -s 5
        $X += 1      
        } until(($connectresult = Test-Connection $link -Count 3 -Quiet) -eq $True -or $X -eq 3)
    return $connectresult
}

# Simplifies changing of the registry
Function RegChange {

    param ($regkey, $regparam, $regvalue, $regtype)
    
    If (-NOT (Test-Path $regkey)) {
        New-Item -Path $regkey -Force | Out-Null
    }

    New-ItemProperty -Path $regkey -Name $regparam -Type $regtype -Value $regvalue -Force
}

