::
:: Redirect_OnPrem
::     Script to redirect licensing URLs and SCP for existing clients that used MSDRM (Office 2010) 
::     or MSIPC (Office 2013) with on-premises AD RMS.
::     Please check http://go.microsoft.com/fwlink/?LinkID=524619 before using this script and 
::     update the script to use your configuration settings before deployment.
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

::
:: ACTION ITEM
::     Please replace addresses with your on-premises servers
::     or remove short name if you didn't use it in your ADRMS.
set OnPremRMS=pdho-arms1
set OnPremRMSFQDN=pdho-arms1.rlicorp.com

::
:: ACTION ITEM
::     Please replace the GUID with your Azure RMS tenant.
::     Use Get-AadrmConfiguration to find out your RightsManagementServiceId.
set CloudRMS=069afcc4-8591-4dfa-83cd-cd906193f67d.rms.na.aadrm.com

echo.
:: Please see http://technet.microsoft.com/en-us/library/dd772665(v=ws.10).aspx
echo Redirect SCP for Office 2010
reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\MSDRM\ServiceLocation\Activation" /t REG_SZ /ve /d "https://%CloudRMS%/_wmcs/certification" /F
reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\MSDRM\ServiceLocation\EnterprisePublishing" /t REG_SZ /ve /d "https://%CloudRMS%/_wmcs/licensing" /F
reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\MSDRM\ServiceLocation\EnterpriseCertification" /t REG_SZ /ve /d "https://%CloudRMS%/_wmcs/certification" /F

echo.
echo Redirect MSDRM for Office 2010
reg add "HKEY_CURRENT_USER\Software\Microsoft\Office\14.0\Common\DRM\LicenseServerRedirection" /t REG_SZ /v "http://%OnPremRMS%/_wmcs/licensing" /d "https://%CloudRMS%/_wmcs/licensing" /F
reg add "HKEY_CURRENT_USER\Software\Microsoft\Office\14.0\Common\DRM\LicenseServerRedirection" /t REG_SZ /v "http://%OnPremRMSFQDN%/_wmcs/licensing" /d "https://%CloudRMS%/_wmcs/licensing" /F

echo.
:: Please see http://technet.microsoft.com/en-us/library/jj159267(v=ws.10).aspx
echo Redirect SCP for Office 2013 and 2016
reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\MSIPC\ServiceLocation\EnterpriseCertification" /t REG_SZ /ve /d "https://%CloudRMS%/_wmcs/certification" /F
reg add "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\MSIPC\ServiceLocation\EnterpriseCertification" /t REG_SZ /ve /d "https://%CloudRMS%/_wmcs/certification" /F
reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\MSIPC\ServiceLocation\EnterprisePublishing" /t REG_SZ /ve /d "https://%CloudRMS%/_wmcs/licensing" /F
reg add "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\MSIPC\ServiceLocation\EnterprisePublishing" /t REG_SZ /ve /d "https://%CloudRMS%/_wmcs/licensing" /F

echo.
echo Redirect MSIPC for Office 2013 and 2016
reg add "HKEY_CURRENT_USER\Software\Microsoft\Office\15.0\Common\DRM" /t REG_SZ /v "DefaultServerUrl" /d "https://%CloudRMS%/_wmcs/licensing" /F 
reg add "HKEY_CURRENT_USER\Software\Microsoft\Office\15.0\Common\DRM" /t REG_SZ /v "DefaultServer" /d "%CloudRMS%" /F
reg add "HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Common\DRM" /t REG_SZ /v "DefaultServerUrl" /d "https://%CloudRMS%/_wmcs/licensing" /F
reg add "HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Common\DRM" /t REG_SZ /v "DefaultServer" /d "%CloudRMS%" /F
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MSIPC\ServiceLocation\LicensingRedirection" /t REG_SZ /v "http://%OnPremRMS%/_wmcs/licensing" /d "https://%CloudRMS%/_wmcs/licensing" /F
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MSIPC\ServiceLocation\LicensingRedirection" /t REG_SZ /v "http://%OnPremRMSFQDN%/_wmcs/licensing" /d "https://%CloudRMS%/_wmcs/licensing" /F
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\MSIPC\ServiceLocation\LicensingRedirection" /t REG_SZ /v "http://%OnPremRMS%/_wmcs/licensing" /d "https://%CloudRMS%/_wmcs/licensing" /F
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\MSIPC\ServiceLocation\LicensingRedirection" /t REG_SZ /v "http://%OnPremRMSFQDN%/_wmcs/licensing" /d "https://%CloudRMS%/_wmcs/licensing" /F

echo Success
:eof
