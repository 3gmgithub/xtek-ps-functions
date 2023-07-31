# List of functions
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

function debugpause {
    # If running in the console, wait for input before closing.
    if ($Host.Name -eq "ConsoleHost")
    {
        Write-Host "Press any key to continue..."
        $Host.UI.RawUI.FlushInputBuffer()   # Make sure buffered input doesn't "press a key" and skip the ReadKey().
        $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") > $null
    }

}

Function RegChange {

    param ($regkey, $regparam, $regvalue, $regtype)
    
    If (-NOT (Test-Path $regkey)) {
        New-Item -Path $regkey -Force | Out-Null
    }

    New-ItemProperty -Path $regkey -Name $regparam -Type $regtype -Value $regvalue -Force
}

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

function downloadinstaller {
    param ($downloadfile, $output)
    $outpath = Get-ScriptPath
    $link = $downloadfile.split('/')
    $connectresult = NetTest $link[2]
    $outfile = '{0}\{1}' -f $outpath,$output

    if ($connectresult -eq $true){
        Try
        {  
            Invoke-WebRequest -Uri $downloadfile -OutFile "$outfile"
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