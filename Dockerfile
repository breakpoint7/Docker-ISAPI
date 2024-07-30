# Use the official Windows Server Core image
FROM mcr.microsoft.com/windows/servercore:ltsc2019

# Install IIS, ISAPI Extensions, and remote management service for debugging purposes
RUN powershell -Command \
    Install-WindowsFeature Web-Server; \
    Install-WindowsFeature Web-ISAPI-Ext; \
    Install-WindowsFeature Web-ISAPI-Filter; \
    Install-WindowsFeature Web-Mgmt-Service; \
    if (-not (Test-Path -Path HKLM:\software\microsoft\WebManagement\Server)) { \
        New-Item -Path HKLM:\software\microsoft\WebManagement\Server -ItemType Directory; \
    } \
    New-ItemProperty -Path HKLM:\software\microsoft\WebManagement\Server -Name EnableRemoteManagement -Value 1 -Force; \
    Set-Service -Name wmsvc -StartupType automatic

# Add user for Remote IIS Manager Login
RUN powershell -Command \
    net user iisadmin <your password here> /ADD; \
    net localgroup administrators iisadmin /add

# Install Visual C++ Redistributable if needed
ADD https://aka.ms/vs/17/release/vc_redist.x64.exe C:\\vc_redist.x64.exe
RUN C:\\vc_redist.x64.exe /quiet /install

# Copy the ISAPI extension to the appropriate directory
COPY isapi.dll C:/inetpub/wwwroot/isapi/isapi.dll
COPY index.html C:/inetpub/wwwroot

# Expose port 80 for HTTP access
EXPOSE 80

# Unlock the necessary configuration sections
RUN powershell -Command \
    "& $env:windir\\system32\\inetsrv\\appcmd.exe unlock config /section:isapiCgiRestriction; \
    & $env:windir\\system32\\inetsrv\\appcmd.exe unlock config /section:system.webServer/handlers; "
 
# Configure handler and allow the ISAPI extension
RUN powershell -Command \
    "& $env:windir\\system32\\inetsrv\\appcmd.exe set config \"Default Web Site/ISAPI\" /section:system.webServer/handlers /+\"[name='MyISAPI',path='*.dll',verb='*',modules='IsapiModule',scriptProcessor='C:\inetpub\wwwroot\isapi\isapi.dll',resourceType='File',requireAccess='Execute']\" /commit:apphost; \
    & $env:windir\\system32\\inetsrv\\appcmd.exe set config -section:isapiCgiRestriction /+\"[path='C:\inetpub\wwwroot\ISAPI\isapi.dll',allowed='true',description='My ISAPI Extension']\" /commit:apphost; "
 
# Configure access policy to allow the extension to be active
RUN powershell -Command \
    "& $env:windir\system32\inetsrv\appcmd.exe set config \"Default Web Site/ISAPI\" /section:system.webServer/handlers /accessPolicy:Read,Execute,Script /commit:apphost"

# Start the Web Management Service and keep the container running
CMD ["powershell", "-NoLogo", "-Command", "Start-Service wmsvc; Start-Service w3svc; while ($true) { Start-Sleep -Seconds 3600 }"]
