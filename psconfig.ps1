# Sample PowerShell file to setup a virtual directory and add an ISAPI extension

# Check for administrative privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator."
    exit
}

# Define the virtual site name
$virtualSiteName = "poc"

# Unlock necessary sections
& "$env:windir\system32\inetsrv\appcmd.exe" unlock config /section:isapiCgiRestriction /commit:apphost
& "$env:windir\system32\inetsrv\appcmd.exe" unlock config /section:handlers /commit:apphost

Write-Host "Setting up the directory and copying Dlls..."
# Ensure the virtual site directory exists under 'wwwroot'
$virtualSitePath = "C:\inetpub\wwwroot\$virtualSiteName"
if (-not (Test-Path -Path $virtualSitePath)) {
    New-Item -Path $virtualSitePath -ItemType Directory
}

# Copy isapi.dll and index.html from c:\temp\docker\test2 to the virtual site directory
$sourcePath = "C:\temp\docker"
Copy-Item -Path "$sourcePath\isapi.dll" -Destination $virtualSitePath -Force
Copy-Item -Path "$sourcePath\index.html" -Destination $virtualSitePath -Force

Write-Host "`n`nConfiguring the website..."
Write-Host "Checking if the virtual directory '$virtualSiteName' exists..."
$vdirExists = & $env:windir\system32\inetsrv\appcmd.exe list vdir /app.name:"Default Web Site/" /path:/$virtualSiteName
if ($vdirExists -eq $null) {
    Write-Host "Virtual directory '$virtualSiteName' does not exist. Creating it..."
    & $env:windir\system32\inetsrv\appcmd.exe add vdir /app.name:"Default Web Site/" /path:/$virtualSiteName /physicalPath:$virtualSitePath
} else {
    Write-Host "Virtual directory '$virtualSiteName' already exists."
}

Write-Host "Configuring ISAPI Extension..."
& $env:windir\system32\inetsrv\appcmd.exe set config "Default Web Site/$virtualSiteName" /section:system.webServer/handlers /+"[name='MyISAPI',path='*.dll',verb='*',modules='IsapiModule',scriptProcessor='$virtualSitePath\isapi.dll',resourceType='File',requireAccess='Execute']" /commit:apphost

Write-Host "Allowing ISAPI extension..."
# Allow the ISAPI extension
& $env:windir\system32\inetsrv\appcmd.exe set config -section:isapiCgiRestriction /+"[path='$virtualSitePath\isapi.dll',allowed='true',groupId='ContosoGroup',description='My ISAPI Extension']" /commit:apphost

# Set the accessPolicy attribute to include Read, Execute, Script
Write-Host "Setting accessPolicy to Read, Execute, Script..."
& $env:windir\system32\inetsrv\appcmd.exe set config "Default Web Site/$virtualSiteName" /section:system.webServer/handlers /accessPolicy:Read,Execute,Script /commit:apphost
