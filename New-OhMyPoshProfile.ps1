<#
.SYNOPSIS
This script performs system validation and installs necessary dependencies for Oh My Posh.

.DESCRIPTION
The script checks the installation locations of Visual Studio Code and PowerShell 7. It also checks the version of WinGet and installs the latest version if necessary. Additionally, it installs a Nerd Font and PowerShell modules required by Oh My Posh.

.PARAMETER nerdFontFileName
The name of the Nerd Font file to be installed.

.EXAMPLE
.\New-OhMyPoshProfile.ps1 -nerdFontFileName 'CascadiaCode.zip'
This example runs the script and installs the Nerd Font with the specified file name.

.NOTES
Author: Simon Lee - @smoonlee
Date: July 2024
Version: Oh My Posh - Setup Script v3
#>

#Requires -RunAsAdministrator

# Script Variables
$scriptVersion = 'v3'
$nerdFontFileName = 'CascadiaCode.zip'

function getSystemRequirements {

    Write-Output "[OhMyPoshProfile $scriptVersion] :: Oh My Posh - System Validation"
    Write-Output "[OhMyPoshProfile $scriptVersion] :: Checking VSCode Installation Location"
    $vscodeSystemPath = "C:\Program Files\Microsoft VS Code\Code.exe"
    $vscodeUserPath = "C:\Users\$env:USERNAME\AppData\Local\Programs\Microsoft VS Code\Code.exe"
    if (Test-Path $vscodeSystemPath) {
        Write-Output "[OhMyPoshProfile $scriptVersion] :: VSCode System Path: $vscodeSystemPath"
    }
    elseif (Test-Path $vscodeUserPath) {
        Write-Output "[OhMyPoshProfile $scriptVersion] :: VSCode User Path: $vscodeUserPath"
    }
    else {
        Write-Warning "[OhMyPoshProfile $scriptVersion] :: Visual Studio Code not found"
    }

    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Checking PowerShell 7 Installation Location"
    $pwsh7SystemPath = "C:\Program Files\PowerShell\7\pwsh.exe"
    $pwsh7UserPath = "C:\Users\$env:USERNAME\AppData\Local\Microsoft\WindowsApps\pwsh.exe"
    if (Test-Path $pwsh7SystemPath) {
        Write-Output "[OhMyPoshProfile $scriptVersion] :: PowerShell 7 System Path: $pwsh7SystemPath"
        & $pwsh7SystemPath -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
        Write-Output "[OhMyPoshProfile $scriptVersion] :: Updated Execution Policy for PowerShell 7 'RemoteSigned'"
    }
    elseif (Test-Path $pwsh7UserPath) {
        Write-Output "[OhMyPoshProfile $scriptVersion] :: PowerShell 7 User Path: $pwsh7UserPath"
        & $pwsh7UserPath -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
        Write-Output "[OhMyPoshProfile $scriptVersion] :: Updated Execution Policy for PowerShell 7 'RemoteSigned'"
    }
    else {
        Write-Warning "[OhMyPoshProfile $scriptVersion] :: PowerShell 7 not found"
        Exit 1
    }

    $pwsh5SystemPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    & $pwsh5SystemPath -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
    Write-Output "[OhMyPoshProfile $scriptVersion] :: Updated Execution Policy for PowerShell 5 'RemoteSigned'"
}

function updateWinGetVersion {
    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Checking WinGet Version"

    #
    $wingetLocalVersion = winget --version
    $wingetGitHubUrl = 'https://api.github.com/repos/microsoft/winget-cli/releases/latest'
    $wingetLatestVersion = $(Invoke-RestMethod -Uri $wingetGitHubUrl).tag_name

    if ($wingetLocalVersion -match $wingetLatestVersion) {
        Write-Output "[OhMyPoshProfile $scriptVersion] :: WinGet Fine [$wingetLocalVersion], Skipping Update"
    }

    if ($wingetLocalVersion -notmatch $wingetLatestVersion) {
        Write-Warning "WinGetCLI Requires Update!! - Latest [$wingetLatestVersion]"

        $msftVCLibsx64 = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
        $msftVCLibsx86 = 'https://aka.ms/Microsoft.VCLibs.x86.14.00.Desktop.appx'
        $msftDesktopAppInstaller = $((Invoke-RestMethod -Uri $wingetGitHubUrl).assets).browser_download_url[2]
        $msftDesktopAppLic = $((Invoke-RestMethod -Uri $wingetGitHubUrl).assets).browser_download_url[0]
        $downloadFileArray = @($msftVCLibsx64, $msftVCLibsx86, $msftDesktopAppLic, $msftDesktopAppInstaller)

        # Download Files
        Write-Output `r "[Device Setup] -> Downloading WinGet Setup Files"
        forEach ($file in $downloadFileArray) {
            $fileName = $(Split-Path -Leaf $file)
            $outFile = "$Env:Temp\$fileName"

            Write-Output "[Device Setup] -> Downloading [$fileName]"

            $wc = New-Object net.webclient
            $wc.downloadFile($file, $outFile)

            # Install files
            if ($fileName -like '*appx') {

                $filePath = $outFile
                $fileVersion = (Get-ItemProperty -Path $filePath).VersionInfo.ProductVersion
                $highestInstalledVersion = Get-AppxPackage -Name Microsoft.VCLibs* |
                Sort-Object -Property Version | Select-Object -ExpandProperty Version -Last 1

                if ($highestInstalledVersion -lt $fileVersion ) {
                    Write-Output "[Device Setup] -> Installing [$fileName]"
                    Add-AppxPackage $filePath
                }

                if ($highestInstalledVersion -ge $fileVersion) {
                    Write-Warning "[Device Setup] -> Skipping [$fileName], Newer Version Installed [$highestInstalledVersion]"
                }

                #
                Remove-Item -Path $filePath -Force
            }

            if ($fileName -like '*msixbundle') {
                Write-Output "[Device Setup] -> Installing [$fileName]"
                $appFile = $(Get-ChildItem -Path $Env:Temp | Where-Object 'Name' -like '*msixbundle').Name
                $appLicXml = $(Get-ChildItem -Path $Env:Temp | Where-Object 'Name' -like '*xml').Name

                Add-AppProvisionedPackage -Online -PackagePath $Env:Temp\$appFile -LicensePath $Env:Temp\$appLicXml | Out-Null
                Remove-Item -Path $Env:Temp\$appFile -Force ; Remove-Item -Path $Env:Temp\$appLicXml -Force
            }
        }
    }

    # WinGet CLI Update
    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Updating Windows Package Manager Cache (WinGet)"
    $wingetPath = "$Env:LOCALAPPDATA\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\winget.exe"
    Start-Process -Wait -FilePath $wingetPath -ArgumentList 'source reset --force' -NoNewWindow
    Start-Process -Wait -FilePath $wingetPath -ArgumentList 'source update' -NoNewWindow
}

function installNerdFont {
    param (
        $nerdFontFileName
    )

    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Checking for Nerd Font [$nerdFontFileName]"

    # Get the latest release of Nerd Fonts
    $nerdFontGitHubUrl = 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases'
    $response = Invoke-WebRequest -Uri $nerdFontGitHubUrl
    $releases = $response.Content | ConvertFrom-Json
    $latestRelease = $releases[0]
    $nerdFont = $latestRelease.assets | Where-Object { $_.name -like $nerdFontFileName }

    $windowsFontPath = 'C:\Windows\Fonts'
    if (Get-ChildItem -Path C:\Windows\Fonts | Where-Object 'Name' -like "*NerdFont-Regular.ttf") {
        Write-Output "[OhMyPoshProfile $scriptVersion] :: Nerd Font [$nerdFontFileName] is already installed"
    }

    if (!(Get-ChildItem -Path C:\Windows\Fonts | Where-Object 'Name' -like "*NerdFont-Regular.ttf")) {
        # Download Nerd Font
        Write-Output "[OhMyPoshProfile $scriptVersion] :: Downloading Nerd Font [$nerdFontFileName]"
        $nerdFontZipName = $nerdFont.name
        $folderName = $nerdFontFileName.Replace('.zip', '')

        $downloadUrl = $nerdFont.browser_download_url
        $outFile = "$Env:Temp\$nerdFontZipName"
        $wc = New-Object net.webclient
        $wc.downloadFile($downloadUrl, $outFile)

        Expand-Archive -Path $outFile -DestinationPath $Env:Temp\$folderName

        # Install Nerd Font
        Write-Output "[OhMyPoshProfile $scriptVersion] :: Installing Nerd Font [$nerdFontFileName]"
        $fontFile = Get-ChildItem -Path $Env:Temp\$folderName | Where-Object 'Name' -like "*NerdFont-Regular.ttf"
        Copy-Item -Path "$Env:Temp\$folderName\$($fontFile.Name)" -Destination $windowsFontPath

        $fontRegistryPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
        $fontEntry = $fontFile.Name # Modify this if the font is not TrueType
        $dataValue = "C:\Windows\Fonts\$($fontFile.Name)"
        New-ItemProperty -Path $fontRegistryPath -Name $fontEntry -PropertyType String -Value $dataValue -Force | Out-Null

        $wshShell = New-Object -ComObject WScript.Shell
        $fontCachePath = "$env:SystemRoot\System32\FNTCACHE.DAT"
        $wshShell.AppActivate('Font Viewer') | Out-Null
        Start-Sleep -Milliseconds 500
        $wshShell.SendKeys('{F5}')
        Start-Sleep -Milliseconds 500
        $wshShell.SendKeys('{TAB}{ENTER}')
        Start-Sleep -Milliseconds 500

        if (Test-Path $fontCachePath) {
            Remove-Item $fontCachePath -Force
        }

        # Remove Zip Font Folder
        Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Cleaning Up Nerd Font [$nerdFontFileName]"
        Remove-Item -Path $outFile -Force
        Remove-Item -Path "$Env:Temp\$folderName" -Recurse -Force
    }
}

function installPowerShellModules {
    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: PowerShell Module Installation"

    if ($host.version.Major -eq '5') {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    }

    $coreModules = @('PackageManagement', 'PowerShellGet')
    forEach ($module in $coreModules) {
        $onlineModule = Find-Module -Repository 'PSGallery' -Name $module
        $moduleCheck = Get-Module -ListAvailable -Name $module
        if ($moduleCheck) {
            $localModuleVersion = $(Get-Module -ListAvailable -Name $module | Select-Object 'Version' -First 1).Version.ToString()
        }

        if ($onlineModule.version -eq $localModuleVersion) {
            Write-Output "[OhMyPoshProfile $scriptVersion] :: Core PowerShell Module [$module] is up to date"
        }

        if ($onlineModule.version -ne $localModuleVersion) {
            Write-Output "[OhMyPoshProfile $scriptVersion] :: Installing Core PowerShell Module [$module]"
            Install-Module -Repository 'PSGallery' -Scope 'AllUsers' -Name $module -Force
        }
    }

    # Set PSGallery as a trusted repository
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'

    $pwshModule = @(
        'Az'
        'Posh-Git',
        'Terminal-Icons',
        'PSReadLine',
        'Pester'
    )

    forEach ($module in $pwshModule) {
        Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Checking PowerShell Module [$module]"
        $onlineModule = Find-Module -Repository 'PSGallery' -Name $module
        $moduleCheck = Get-Module -ListAvailable -Name $module
        if ($moduleCheck) {
            $localModuleVersion = $(Get-Module -ListAvailable -Name $module | Select-Object 'Version' -First 1).Version.ToString()
        }

        if ($onlineModule.version -eq $localModuleVersion) {
            Write-Output "[OhMyPoshProfile $scriptVersion] :: PowerShell Module [$module] is up to date"
        }

        if ($onlineModule.version -ne $localModuleVersion) {
            Write-Output "[OhMyPoshProfile $scriptVersion] :: Installing PowerShell Module [$module]"
            Install-Module -Repository 'PSGallery' -Scope 'CurrentUser' -Name $module -SkipPublisherCheck -Force
        }

        if ($module -eq 'PSReadLine') {
            Write-Output "[OhMyPoshProfile $scriptVersion] :: Updating PSReadLine for PowerShell 5"
            Save-Module -Name $module -Path 'C:\Program Files\WindowsPowerShell\Modules'
        }
    }
}

function installWinGetApplications {

    # Configure WinGet
    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Checking Winget Modules"
    $winGetApps = @(
        'JanDeDobbeleer.OhMyPosh',
        'Git.Git',
        'GitHub.cli',
        'Microsoft.AzureCLI',
        'Microsoft.Azure.Kubelogin',
        'Kubernetes.kubectl',
        'Helm.Helm',
        'Ookla.Speedtest.CLI'
    )

    ForEach ($app in $winGetApps) {
        $appCheck = winget.exe list --exact --query $app --accept-source-agreements
        If ($appCheck[-1] -notmatch $app) {
            Write-Output "[OhMyPoshProfile $scriptVersion] :: Installing [$app]"
            $wingetPath = "$Env:LOCALAPPDATA\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\winget.exe"
            Start-Process -Wait -NoNewWindow -FilePath $wingetPath -ArgumentList "install" , "--silent", "--exact", "--query $app", "--accept-source-agreements"
            Write-Output "" # Required for script spacing
        }
        else {
            Write-Output "[OhMyPoshProfile $scriptVersion] :: [$app] is already installed"
        }
    }
}

function setPwshProfile {
    $poshTheme = "$PSScriptRoot\quick-term-smoon.omp.json"
    $poshThemeName = Split-Path -Path $poshTheme -Leaf

    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Downloading Oh-My-Posh Profile: [$poshThemeName]"

    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Creating PowerShell Profile"

    if ($host.version.Major -eq '7') {
        $pwshProfilePath = "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1"
        if (!(Test-Path $pwshProfilePath)) {
            New-Item -ItemType 'Directory' -Path $($pwshProfilePath | Split-Path -Parent) -Force | Out-Null
        }
    }

    if ($host.version.major -eq '5') {
        $pwshProfilePath = "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        if (!(Test-Path $pwshProfilePath)) {
            New-Item -ItemType 'Directory' -Path $($pwshProfilePath | Split-Path -Parent) -Force | Out-Null
        }
    }

    $pwshProfile = Get-Content -Path "$PSScriptRoot\Microsoft.PowerShell_profile.ps1"
    $pwshProfile = $pwshProfile.Replace('themeNameHere', $poshThemeName)
    $pwshProfile | Set-Content -Path $pwshProfilePath -Force

}

function setWindowsTerminal {
    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Updating Windows Terminal Configuration"

    $settingJson = "$PSScriptRoot\windows-terminal-settings.json"
    $localSettingsPath = "$Env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    Copy-Item -Path $settingJson -Destination $localSettingsPath -Force

    $startDirectory = 'C:\Code'
    if (!(Test-Path -Path $startDirectory)) {
        New-Item -ItemType 'Directory' -Path $startDirectory -Force | Out-Null
    }

    Write-Warning "Please restart Windows Terminal to apply the new settings"
}

function setCrossPlatformModuleSupport {
    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: PowerShell Module Cross Version Support"

    if ($host.Version.Major -eq '5') {
        if (Test-Path -Path "$Env:UserProfile\Documents\PowerShell\Modules") {
            Remove-Item -Path "$Env:UserProfile\Documents\PowerShell\Modules" -Recurse -Force
        }

        # Target - Source Folder # Path - Link Folder
        # PowerShell Module Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Modules" -Path "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Modules" -Force | Out-Null
        Write-Output "[OhMyPoshProfile $scriptVersion] :: Symbolic Link Created from 'WindowsPowerShell' to 'PowerShell' Modules"

        # PowerShell Profile Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Path "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1" -Force | Out-Null
        Write-Output "[OhMyPoshProfile $scriptVersion] :: Symbolic Link Created from 'WindowsPowerShell' to 'PowerShell' Profile"

        # VSCode Profile Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Path "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.VSCode_profile.ps1" -Force | Out-Null
        Write-Output "[OhMyPoshProfile $scriptVersion] :: Symbolic Link Created from 'WindowsPowerShell' to 'VSCode' Profile"

    }

    if ($host.Version.Major -eq '7') {
        if (Test-Path -Path "$Env:UserProfile\Documents\WindowsPowerShell\Modules" ) {
            Remove-Item -Path "$Env:UserProfile\Documents\WindowsPowerShell\Modules" -Recurse -Force
        }

        # Target - Source Folder # Path - Link Folder
        # PowerShell Module Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Modules" -Path "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Modules" -Force | Out-Null
        Write-Output "[OhMyPoshProfile $scriptVersion] :: Symbolic Link Created from 'PowerShell' to 'WindowsPowerShell' Modules"

        # PowerShell 5 Profile Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1" -Path "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Force | Out-Null
        Write-Output "[OhMyPoshProfile $scriptVersion] :: Symbolic Link Created from 'PowerShell' to 'WindowsPowerShell' Profile"

        # VSCode Profile Link
        New-Item -ItemType 'SymbolicLink' -Target "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1" -Path "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.VSCode_profile.ps1" -Force | Out-Null
        Write-Output "[OhMyPoshProfile $scriptVersion] :: Symbolic Link Created from 'PowerShell' to 'VSCode' Profile"
    }
    Write-Output "" # Required for script spacing
}

function patchVSCodePwshModule {
    Write-Output `r "[OhMyPoshProfile $scriptVersion] :: Patching VSCode PowerShell Module"
    $vsCodeModulePath = "$Env:UserProfile\.vscode\extensions\$folderName"
    $psReadLineVersion = $(Find-Module -Name 'PSReadLine' | Select-Object Version).version.ToString()
    $folderName = $(Get-ChildItem -Path "$Env:UserProfile\.vscode\extensions" -ErrorAction SilentlyContinue | Where-Object 'Name' -like 'ms-vscode.powershell*').name | Select-Object -Last 1
    if ([string]::IsNullOrEmpty($folderName)) {
        Write-Output "[OhMyPoshProfile $scriptVersion] :: VSCode PowerShell Module not found, Skipping patch!"
        return
    }

    Write-Output "[OhMyPoshProfile $scriptVersion] :: Checking if VSCode is running..."
    $vsCodeProcess = Get-Process -Name Code -ErrorAction SilentlyContinue
    if ($vsCodeProcess) {
        Write-Warning "Please close Visual Studio Code before continuing, Skipping VSCode PowerShell Module patch!!"
        return
    }

    Write-Output "[OhMyPoshProfile $scriptVersion] :: VSCode not running, Patching PowerShell Module [$folderName]" `r
    Write-Output "The PowerShell Module Extension [$folderName], Uses PSReadline 2.4.0 Beta."
    Write-Output "Using 2.4.0 Beta you get this error: 'Assembly with same name is already loaded'"
    Write-Output "The OhMyPoshProfile setup scripts installs the latest stable version of PSReadline [$psReadLineVersion]"

    if (Test-Path -Path "$vsCodeModulePath\modules\PSReadLine" ) {
        Remove-Item -Path "$vsCodeModulePath\modules\PSReadLine\2.4.0" -Recurse -Force
        Save-Module -Name 'PSReadLine' -Path "$vsCodeModulePath\modules" -Force
    }
}

# Clear Terminal
Clear-Host

# Check System Requirements
getSystemRequirements

# Update WinGet CLI
updateWinGetVersion

# Install Nerd Font
installNerdFont -nerdFontFileName $nerdFontFileName

# Install PowerShell Modules
installPowerShellModules

# Install WinGet Applications
installWinGetApplications

# Set PowerShell Profile
setPwshProfile

# Patch VSCode PowerShell Module
patchVSCodePwshModule

# Set Windows Terminal Configuration
setWindowsTerminal

# Set Cross Platform Module Support
setCrossPlatformModuleSupport
