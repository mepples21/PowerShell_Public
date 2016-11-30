::
:: CleanUpRMS
::     Script to clean-up RMS client configuration and artifacts in MSDRM (Office 2010) or MSIPC (Office 2013).
::     Please check http://go.microsoft.com/fwlink/?LinkID=524619 before using this script and adjust accordingly.
::
:: Version 1.0 (January 2014)
::

@echo off
whoami /priv | find "SeImpersonatePrivilege" | find /c "Enabled"
echo.

if ERRORLEVEL 1 ( 
echo This script must be run with elevated rights
pause
goto :eof ) 

echo "Running elevated"
echo.

reg delete HKCU\Software\Microsoft\MSDRM\TemplateManagement /v lastUpdatedTime /f

echo.
echo Deleting certs from MSDRM cert store
if exist "%localappdata%\Microsoft\DRM\*.drm" (
    echo   - Removing "%localappdata%\Microsoft\DRM\*.drm"
    del "%localappdata%\Microsoft\DRM\*.drm" /f /q
)

echo Deleting certs from MSIPC cert store
if exist "%localappdata%\Microsoft\MSIPC\*.drm" (
    echo   - Removing "%localappdata%\Microsoft\MSIPC\*.drm"
    rd /s /q %localappdata%\Microsoft\MSIPC
)


echo.
echo Clear Office service disco cache
reg delete HKCU\Software\Microsoft\Office\12.0\Common\DRM /v CachedCorpLicenseServer /f
reg delete HKCU\Software\Microsoft\Office\14.0\Common\DRM /v CachedCorpLicenseServer /f
reg delete HKCU\Software\Microsoft\Office\14.0\Common\DRM\ServiceLocations /f
reg delete HKCU\Software\Microsoft\Office\14.0\Common\DRM /v DefaultServer /f
reg delete HKCU\Software\Microsoft\Office\14.0\Common\DRM /v DefaultServerUrl /f
reg delete HKCU\Software\Microsoft\Office\15.0\Common\DRM /f
reg delete HKCU\Software\Microsoft\Office\16.0\Common\DRM /f

echo Clear MSIPC service disco cache and sharing app shell context menu cache
reg delete "HKCU\Software\Classes\Local Settings\Software\Microsoft\MSIPC" /f
reg delete HKCU\Software\Classes\Microsoft.IPViewerChildMenu\shell /f

echo.
echo Delete MSDRM service disco reg keys
reg delete HKLM\Software\Microsoft\MSDRM\ServiceLocation /f
reg delete HKLM\Software\Wow6432Node\Microsoft\MSDRM\ServiceLocation /f
echo Delete MSIPC service disco reg keys
reg delete HKLM\SOFTWARE\Microsoft\MSIPC\ServiceLocation /f
reg delete HKLM\Software\Wow6432Node\Microsoft\MSIPC\ServiceLocation /f

echo Success 
:eof