<#
.SYNOPSIS
    This script can configure the ADFS and ADFS Proxy server roles.
    
.DESCRIPTION
	Version 2.0: Changing the way options work in the script instead of using parameter sets.

.NOTES
    Version      	   	    	: 2.1
    Wish list		        	: Better error handling
                                  Export ADFS certificate to PFX
                                  Standardize write-host colors
                                  Test SQL backend options
                                  Fix certificate installation check function
                                  Add functionality to update SNI settings if 'netsh http' binding already exists for 0.0.0.0 using an old certificate
    Author(s)    				: Michael Epping (mepping@concurrency.com)
    Disclaimer   				: You running this script means you won't blame me if this breaks your stuff. This script is provided AS IS
								  without warranty of any kind. I disclaim all implied warranties including, without limitation, any implied
								  warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use
								  or performance of the sample scripts and documentation remains with you. In no event shall I be liable for
								  any damages whatsoever (including, without limitation, damages for loss of business profits, business
								  interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability
								  to use the script or documentation.
	Assumptions					: ExecutionPolicy of AllSigned (recommended), RemoteSigned or Unrestricted (not recommended)
    Limitations					:
    Known issues				: None yet, but I'm sure you'll find some!

.INPUTS
	None. You cannot pipe objects to this script.

#>

# Define Parameters

<#
    [CmdletBinding(SupportsShouldProcess = $True, DefaultParameterSetName = "ADFSLocal")]
    param(
        
        # Allows the script to be run on a remote machine
            [parameter(Position = 0, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
            [string]$RemoteServer
        
    )
/#>


# Define Functions

    ## Present Script Options
        function Show-Menu {
            param (
            [string]$Title = 'ADFS Installation Options'
            )
            cls
            Write-Host "================ $Title ================"

            Write-Host "1: Press '1' to install a server as the first server in a new ADFS Farm."
            Write-Host "2: Press '2' to join a server to an existing ADFS Farm."
            Write-Host "3: Press '3' to configure a server as a Web Application Proxy (ADFS Proxy)."
            Write-Host "4: Press '4' to import a certificate."
            Write-Host "5: Press '5' to join a domain."
            Write-Host "6: Press '6' to reboot a server."
            Write-Host "7: Press '7' to install Azure AD PowerShell tools."
            Write-Host "8: Press '8' to convert a domain to federated."
            Write-Host "9: Press '9' to convert a domain to standard."
            Write-Host "10: Press '10' to view ADFS customization options."
            Write-Host "Q: Press 'Q' to quit."
        }
        
        function Show-ADFSSubMenu {
            param (
            [string]$Title = 'ADFS Post-Installation Configuration Options'
            )
            cls
            Write-Host "================ $Title ================"

            Write-Host "1: Press '1' to extend lifetimes for Token-Signing and Token-Decrypting certificates."
            Write-Host "2: Press '2' to enable end user password changes."
            Write-Host "3: Press '3' to enable WS-TRUST 1.3 for Desktop Client SSO (ADAL/Modern Authentication)."
            Write-Host "4: Press '4' to enable 'Keep Me Signed In' (changes ticket sessions to 24 hours)."
            Write-Host "5: Press '5' to enable usable ADFS logging via Event Viewer."
            Write-Host "6: Press '6' to set the ADFS Logo."
            Write-Host "7: Press '7' to set the text on the ADFS signon page."
            Write-Host "8: Press '8' to set primary authentication types to default."
            Write-Host "9: Press '9' to disable WindowsAuthentication popups on the intranet and force Forms usage."
            Write-Host "10: Press '10' to set Forms as the default authentication provider on the intranet and use WindowsAuthentication only as a fallback."
            Write-Host "11: Press '11' to turn off the SNI requirement on an ADFS server."
            Write-Host "12: Press '12' to turn off the SNI requirement on a Proxy server."
            Write-Host "13: Press '13' to remove the SNI configuration after a new ADFS cert is installed."
            Write-Host "14: Press '14' to remove the SNI configuration after a new Proxy cert is installed."
            Write-Host "15: Press '15' to add an inbound port 80 Windows Firewall rule."
            Write-Host "Q: Press 'Q' to quit and return to the main menu."
        }

    ## Primary Menu Functions
        ## Local or Remote
            function Get-RemoteAnswer {
                $title = "Local or Remote Server?"
                $message = "Would you like to configure this server or a remote server?"
                
                $Local = New-Object System.Management.Automation.Host.ChoiceDescription "&Local", `
                "Configure the local server."
                
                $Remote = New-Object System.Management.Automation.Host.ChoiceDescription "&Remote", `
                "Configure a remote server."
                
                $options = [System.Management.Automation.Host.ChoiceDescription[]]($Local, $Remote)
                
                $result = $host.ui.PromptForChoice($title, $message, $options, 0)
                
                switch ($result) {
                    0 {
                        "You selected Local, configuration will be performed on this server."
                        Continue
                    }
                    1 {
                        "You selected Remote, please enter the name of the server you would like to configure"
                        $RemoteServerName = Read-Host
                        if ($RemoteServerName -ne "") {
                            write-host "Remote server specified, continuing..."
                        } else {
                            write-host "The Remote server to configure was not specified. Please rerun this script option and specify a server name." -BackgroundColor Green -ForegroundColor Red
                            Break
                        }
        
                        Write-Host "Please enter administrator credentials for the remote server:"
                        $RemCred = Get-Credential -Message "Please enter administrator credentials for the remote server to be configured for ADFS or ADFS Proxy."
                        try {
                            Enter-PSSession -ComputerName $RemoteServerName -Credential $RemCred -ErrorAction Stop
                        } catch {
                            write-host "Exception Message: $($_.Exception.GetType).FullName)" -ForegroundColor Red
                            write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
                            write-host "Remote session failed to start. Please try running this script locally on the server." -BackgroundColor Green -ForegroundColor Red
                            Break 
                        }

                    }
                }
            }
            
        ## Reboot Timer
            Function TimedPrompt($prompt,$secondsToWait){   
                Write-Host -NoNewline $prompt
                $secondsCounter = 0
                $subCounter = 0
                While ( (!$host.ui.rawui.KeyAvailable) -and ($count -lt $secondsToWait) ){
                    start-sleep -m 10
                    $subCounter = $subCounter + 10
                    if($subCounter -eq 1000)
                    {
                        $secondsCounter++
                        $subCounter = 0
                        Write-Host -NoNewline "."
                    }       
                    If ($secondsCounter -eq $secondsToWait) { 
                        Write-Host "`r`n"
                    }
                }
                Write-Host "`r`n"
                $reboot = $true;
            }
                        
        ## Hosts File Function
            function add-hostfilecontent {            
                param (            
                    [parameter(Mandatory=$true)]            
                    [ValidatePattern("\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b")]            
                    [string]$IPAddress,            

                    [parameter(Mandatory=$true)]            
                    [string]$computer            
                )            
                $file = Join-Path -Path $($env:windir) -ChildPath "system32\drivers\etc\hosts"            
                if (-not (Test-Path -Path $file)){            
                    Throw "Hosts file not found"            
                }            
                $data = Get-Content -Path $file             
                $data += "$IPAddress  $computer"            
                Set-Content -Value $data -Path $file -Force -Encoding ASCII             
            }

        ## Install ADFS Certificate
            function Install-ADFSCert {
                write-host "Please enter the path to the ADFS certificate:" -ForegroundColor Red -BackgroundColor Green
                $CertFilePath = Read-Host
                if ($CertFilePath -ne "") {
                    try {
                        $certpassword = Read-Host "Please enter the certificate's password." -AsSecureString
                        Import-PfxCertificate -FilePath $CertFilePath -CertStoreLocation cert:\localMachine\my -Exportable -Confirm:$false -Password $certpassword -ErrorAction Stop
                    } catch {
                        write-host "Exception caught: $($_.Exception.GetType().FullName)" -ForegroundColor Red
                        write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
                        write-host "The certificate failed to import. Please try importing it manually."
                        Break
                    }
                } else {
                Write-Host "No certificate was specified, continuing..."
                }
            }

        ## Ask to Reboot
            function Get-RebootAnswer {
                $title = "Reboot Server?"
                $message = "Would you like to reboot the server?"

                $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
                "Reboot the server."

                $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
                "Do NOT reboot the server."

                $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

                $result = $host.ui.PromptForChoice($title, $message, $options, 1)

                switch ($result) {
                    0 {"You selected Yes, the server will be rebooted."
                        $val = TimedPrompt "Press key to cancel reboot; will begin in 10 seconds." 10
                        Write-Host $val
                        Restart-Computer -Force
                    }
                    1 {write-host "You selected No. The server will not be rebooted. Please reboot it manually and rerun this script to continue the ADFS installation." -ForegroundColor Red -BackgroundColor Green}
                }
            }

        ## Get Certificate Thumbprint
            function Get-CertificateInstallation {
                $CertThumbprint = Get-ChildItem -Path Cert:\LocalMachine\My | where {$_.Subject -like "CN=$FarmName*"}
                if ($CertThumbprint.Thumbprint -ne $null) {
                    write-host "A matching certificate was found, continuing..."
                } else {
                    write-host "A certificate matching the ADFS Farm name was not found, please install one and rerun this script."
                Break
                }
            }

        ## Check ADFS Install Status
            function Get-ADFSInstallStatus {
                $ADFSInstallStatus = (Get-WindowsFeature -Name adfs-federation | select Installed)
                if ($ADFSInstallStatus.Installed -eq $false) {
                    Write-Progress "ADFS is not installed. Installing now"
                    Install-WindowsFeature adfs-federation -IncludeManagementTools
                } else {
                    Write-Host "ADFS is already installed, continuing..."
                }
            }

        ## Check ADFS Install Status for Submenu
            function Get-ADFSInstallStatusForSubmenu {
                $ADFSInstallStatus = (Get-WindowsFeature -Name adfs-federation | select Installed)
                if ($ADFSInstallStatus.Installed -eq $false) {
                    Write-Host "ADFS is not installed on this server. This option must be run from the Primary ADFS server." -ForegroundColor Red
                    break Submenu
                } else {
                    Write-Host "ADFS is installed, continuing..."
                    Import-Module ADFS
                }
            }
            
        ## Check ADFS Install Status for SNI
            function Get-ADFSInstallStatusForSNI {
                $ADFSInstallStatus = (Get-WindowsFeature -Name adfs-federation | select Installed)
                if ($ADFSInstallStatus.Installed -eq $false) {
                    Write-Host "ADFS is not installed on this server. If this is a proxy server run Option #12." -ForegroundColor Red
                    break Submenu
                } else {
                    Write-Host "ADFS is installed, continuing..."
                    Import-Module ADFS
                }
            }
            
        ## Check Proxy Install Status for SNI
            function Get-ProxyInstallStatusForSNI {
                $ProxyInstallStatus = (Get-WindowsFeature -Name web-application-proxy | select Installed)
                if ($ProxyInstallStatus.Installed -eq $false) {
                    Write-Host "Web Application Proxy is not installed on this server. If this is an ADFS server run Option #11" -ForegroundColor Red
                    break Submenu
                } else {
                    Write-Host "Proxy is installed, continuing..."
                    Import-Module WebApplicationProxy
                }
            }
            
        ## Install First ADFS Server in Farm Using WID as Backend
            function Install-ADFSPrimaryServer {
                Import-Module ADFS
                $ADFSModuleStatus = Get-Module ADFS
                if ($ADFSModuleStatus -ne $null) {
                    "ADFS PowerShell Module is loaded, continuing..."
                } else {
                    "The ADFS Module was not loaded. Please install ADFS or reboot the server and rerun this script."
                    Get-RebootAnswer
                    Break
                }
                Write-Host "Please enter the ADFS Service Account Credentials"
                $ADFSServiceAccount = Get-Credential -Message "Please enter the ADFS Service Account credentials using the 'domain\username' format."
                            
                Install-AdfsFarm -CertificateThumbprint $CertThumbprint.Thumbprint -FederationServiceName $FarmName.ToString() -ServiceAccountCredential $ADFSServiceAccount -OverwriteConfiguration -Confirm:$false
            }
            
        ## Install First ADFS Server in Farm Using SQL as Backend
            function Install-ADFSPrimaryServerWithSQLBackend {
                Import-Module ADFS
                $ADFSModuleStatus = Get-Module ADFS
                if ($ADFSModuleStatus -ne $null) {
                    "ADFS PowerShell Module is loaded, continuing..."
                } else {
                    "The ADFS Module was not loaded. Please install ADFS or reboot the server and rerun this script."
                    Get-RebootAnswer
                    Break
                }
                Write-Host "Please enter the ADFS Service Account Credentials"
                $ADFSServiceAccount = Get-Credential -Message "Please enter the ADFS Service Account credentials using the 'domain\username' format."
                
                Write-Host "Please enter the hostname of the SQL backend server." -ForegroundColor Red
                $SQLHost = read-host
                
                Install-AdfsFarm -CertificateThumbprint $CertThumbprint.Thumbprint -FederationServiceName $FarmName.ToString() -ServiceAccountCredential $ADFSServiceAccount -OverwriteConfiguration -SQLConnectionString "Data Source=$SQLHost;Integrated Security=True"
            }

        ## Install Secondary ADFS Server in Farm Using WID as Backend
            function Install-ADFSSecondaryServer {
                Import-Module ADFS
                $ADFSModuleStatus = Get-Module ADFS
                if ($ADFSModuleStatus -ne $null) {
                    "ADFS PowerShell Module is loaded, continuing..."
                } else {
                    "The ADFS Module was not loaded. Please install ADFS or reboot the server and rerun this script."
                    Get-RebootAnswer
                    Break
                }
                Write-Host "Please enter the ADFS Service Account Credentials"
                $ADFSServiceAccount = Get-Credential -Message "Please enter the ADFS Service Account credentials using the 'domain\username' format."
                
                Write-Host "Please enter the name of the primary ADFS server in the existing farm:" -BackgroundColor Green -ForegroundColor Red
                $PrimaryADFSServer = Read-Host
                
                Add-AdfsFarmNode -ServiceAccountCredential $ADFSServiceAccount -PrimaryComputerName $PrimaryADFSServer -CertificateThumbprint $CertThumbprint.Thumbprint -OverwriteConfiguration -Confirm:$false
            }
        
        ## Install Secondary ADFS Server in Farm Using SQL as Backend
            function Install-ADFSSecondaryServerWithSQLBackend {
                Import-Module ADFS
                $ADFSModuleStatus = Get-Module ADFS
                if ($ADFSModuleStatus -ne $null) {
                    "ADFS PowerShell Module is loaded, continuing..."
                } else {
                    "The ADFS Module was not loaded. Please install ADFS or reboot the server and rerun this script."
                    Get-RebootAnswer
                    Break
                }
                Write-Host "Please enter the ADFS Service Account Credentials"
                $ADFSServiceAccount = Get-Credential -Message "Please enter the ADFS Service Account credentials using the 'domain\username' format."
                
                Write-Host "Please enter the name of the primary ADFS server in the existing farm:" -BackgroundColor Green -ForegroundColor Red
                $PrimaryADFSServer = Read-Host
                
                Write-Host "Please enter the hostname of the SQL backend server." -BackgroundColor Green -ForegroundColor Red
                $SQLHost = read-host
                
                Add-AdfsFarmNode -ServiceAccountCredential $ADFSServiceAccount -PrimaryComputerName $PrimaryADFSServer -CertificateThumbprint $CertThumbprint.Thumbprint -OverwriteConfiguration -Confirm:$false -SQLConnectionString "Data Source=$SQLHost;Integrated Security=True"
            }
            
        ## Install Web Application Proxy
            function Install-ADFSProxy {
                $ADFSInstallStatus = (Get-WindowsFeature -Name web-application-proxy | select Installed)
                if ($ADFSInstallStatus.Installed -eq $false) {
                    Write-Progress "ADFS Proxy is not installed. Installing now"
                    Install-WindowsFeature web-application-proxy -IncludeManagementTools
                } else {
                    Write-Host "ADFS Proxy is already installed, continuing..."
                }
                
                Import-Module WebApplicationProxy
                $ADFSModuleStatus = Get-Module WebApplicationProxy
                if ($ADFSModuleStatus -ne $null) {
                    Write-Host "Please enter the ADFS Service Account Credentials"
                    $ADFSServiceAccount = Get-Credential -Message "Please enter the ADFS Service Account credentials using the 'domain\username' format."
                    Install-WebApplicationProxy -CertificateThumbprint $CertThumbprint -FederationServiceName $FarmName -FederationServiceTrustCredential $ADFSServiceAccount
                } else {
                    Write-Host "The Web Application Proxy Module was not loaded. Please reboot the server and rerun this script" -BackgroundColor Green -ForegroundColor Red
                    Get-RebootAnswer
                    Break
                }
            }
            
        ## Join a Domain
            function Join-Domain {
                if ((gwmi win32_computersystem).partofdomain -eq $true) {
                    write-host -fore Green -BackgroundColor Green "Server is already domain joined, continuing..."
                    Continue
                } elseif ((gwmi win32_computersystem).partofdomain -eq $false) {
                    Write-Host "Please enter the name of the domain you would like to join:" -BackgroundColor Green -ForegroundColor Red
                    $DomainToJoin = read-host
                    $domaincred = Get-Credential -Message "Please enter Domain Admin credentials to join this server to the domain."
                    Add-Computer -DomainName $DomainToJoin -Credential $domaincred
                    Get-RebootAnswer
                }
            }
            
        ## Install Azure AD PowerShell
            function Install-AzureADPowerShell {
                Install-WindowsFeature Net-Framework-Core
                Invoke-WebRequest -Uri "https://download.microsoft.com/download/5/0/1/5017D39B-8E29-48C8-91A8-8D0E4968E6D4/en/msoidcli_64.msi" -OutFile .\MSOSignInAssistant.msi
                Invoke-WebRequest -Uri "http://go.microsoft.com/fwlink/p/?linkid=236297" -OutFile .\MSOPowerShell.msi
                .\MSOSignInAssistant.msi /quiet /passive /norestart
                Start-Sleep -s 10
                .\MSOPowerShell.msi /quiet /passive /norestart
                Start-Sleep -s 10
            }
                
            function Get-AzureADInstallStatus {
                $AzureADModuleStatus = Get-Module MSOnline
                if ($AzureADModuleStatus -ne "") {
                    Write-Host "The Azure AD PowerShell Module was loaded successfully, continuing..."
                } else {
                    Write-Host "The Azure AD PowerShell Module could not be loaded. Please try installing it manually using these instructions: https://msdn.microsoft.com/en-us/library/jj151815.aspx#bkmk_installmodule" -BackgroundColor Green -ForegroundColor Red
                    Break
                }
            }      
            
        ## Convert a Domain to Federated
            function Convert-DomainToFederated {
                Write-Host "Please enter the name of the domain to convert to federated:" -ForegroundColor Red -BackgroundColor Green
                $DomainToFederate = read-host
                
                if ($DomainToFederate -ne "") {
                    Write-Host "Please enter your Office 365 Global Administrator Credentials:"
                    $o365creds = Get-Credential -Message "Please enter your Office 365 Global Administrator credentials using the 'username@domain.onmicrosoft.com' format."
                    Connect-MsolService -Credential $o365creds
                    Convert-MsolDomainToFederated -DomainName $DomainToFederate -SupportMultipleDomain
                } else {
                    write-host "The domain to federate was not specified. Either your domain is already federated or you need to convert it using the 'Convert-MsolDomainToFederated -DomainName domain.com -SupportMultipleDomain' command." -ForegroundColor Red -BackgroundColor Green
                }
            }
            
        ## Convert a Domain to Managed
            function Convert-DomainToManaged {
                Write-Host "Please enter the name of the domain to conver to managed:" -ForegroundColor Red -BackgroundColor Green
                $DomainToManage = read-host
                
                if ($DomainToManage -ne "") {
                    Write-Host "Please enter your Office 365 Global Administrator Credentials:"
                    $o365creds = Get-Credential -Message "Please enter your Office 365 Global Administrator credentials using the 'username@domain.onmicrosoft.com' format."
                    Connect-MsolService -Credential $o365creds
                    Write-Host "Please enter the path you would like the passwords text file created at:" -ForegroundColor Red -BackgroundColor Green
                    $PasswordFilePath = read-host
                    Convert-MsolDomainToStandard -DomainName $DomainToManage -PasswordFile $PasswordFilePath -Confirm:$false
                }
            }
            
        ## Ask to Continue
            function Get-ContinueAnswer {
                $caption = "Confirm"
                $message = "Do you want to continue? (Y/N)"
                $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
                $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
                $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no)
                $answer = $host.ui.PromptForChoice($caption,$message,$choices,0)
                
                switch ($answer){
                    0 {"You entered Yes"; Continue}
                    1 {"You entered No"; Break Menu }
                }
            }
            
        ## Ask for ADFS with WID or SQL for Primary Server
            function Install-ADFSWithWIDorSQL {
                $title = "WID or SQL?"
                $message = "Do you want to use WID or SQL as the backend database? Choose WID if you are not sure. SQL SUPPORT IS EXPERIMENTAL AT THIS TIME."
                $WID = New-Object System.Management.Automation.Host.ChoiceDescription "&WID"
                $SQL = New-Object System.Management.Automation.Host.ChoiceDescription "&SQL"
                $choices = [System.Management.Automation.Host.ChoiceDescription[]]($WID,$SQL)
                $answer = $host.ui.PromptForChoice($title, $message, $choices, 0)
                
                switch ($answer){
                    0 {
                        write-host "You chose WID, continuing..." -ForegroundColor Green
                        Install-ADFSPrimaryServer
                    }
                    1 {
                        write-host "You chose SQL, continuing..." -ForegroundColor Green
                        Install-ADFSPrimaryServerWithSQLBackend
                    }
                }
            }
            
        ## Ask for ADFS with WID or SQL for Secondary Server
            function Install-ADFSSecondaryWithWIDorSQL {
                $title = "WID or SQL?"
                $message = "Do you want to use WID or SQL as the backend database? Choose WID if you are not sure. SQL SUPPORT IS EXPERIMENTAL AT THIS TIME."
                $WID = New-Object System.Management.Automation.Host.ChoiceDescription "&WID"
                $SQL = New-Object System.Management.Automation.Host.ChoiceDescription "&SQL"
                $choices = [System.Management.Automation.Host.ChoiceDescription[]]($WID,$SQL)
                $answer = $host.ui.PromptForChoice($title, $message, $choices, 0)
                
                switch ($answer){
                    0 {
                        write-host "You chose WID, continuing..." -ForegroundColor Green
                        Install-ADFSSecondaryServer
                    }
                    1 {
                        write-host "You chose SQL, continuing..." -ForegroundColor Green
                        Install-ADFSSecondaryServerWithSQLBackend
                    }
                }
            }
            
        ## Allow non-SNI Clients for ADFS
            function Configure-ADFSSNI {
                $ADFSCertificate = Get-AdfsSslCertificate | where {$_.PortNumber -eq "443"} | select -Last 1 -Property CertificateHash
                $ADFSCertHash = $ADFSCertificate.CertificateHash.ToString()
                netsh http add sslcert ipport=0.0.0.0:443 certhash=$ADFSCertHash appid='{5d89a20c-beab-4389-9447-324788eb944a}'
            }
        
        ## Allow non-SNI Clients for ADFS Proxy
            function Configure-ProxySNI {
                $ProxyCertificate = Get-WebApplicationProxySslCertificate | where {$_.PortNumber -eq "443"} | select -Last 1 -Property CertificateHash
                $ProxyCertHash = $ProxyCertificate.CertificateHash.ToString()
                netsh http add sslcert ipport=0.0.0.0:443 certhas=$ProxyCertHash appid='{f955c070-e044-456c-ac00-e9e4275b3f04}'
            }
            
        ## Disable SNI Settings for ADFS
            function Remove-ADFSSNI {
                $ADFSCertificate = Get-AdfsSslCertificate | where {$_.PortNumber -eq "443"} | select -Last 1 -Property CertificateHash
                $ADFSCertHash = $ADFSCertificate.CertificateHash.ToString()
                netsh http delete sslcert ipport=0.0.0.0:443
            }
            
        ## Disable SNI Settings for ADFS Proxy
            function Remove-ProxySNI {
                $ProxyCertificate = Get-WebApplicationProxySslCertificate | where {$_.PortNumber -eq "443"} | select -Last 1 -Property CertificateHash
                $ProxyCertHash = $ProxyCertificate.CertificateHash.ToString()
                netsh http delete sslcert ipport=0.0.0.0:443
            }
            
#### Begin Script Section ####

    # Show Menu 
    
        do
        {
            Show-Menu
            $input = Read-Host "Please make a selection"
            :Menu switch ($input)
            {
                '1' {
                        cls
                        'You chose option #1'
                        Write-Host 'Option #1 configures the first ADFS server in a new Farm. This requires that you have a service account and an account with Domain Admin privileges. You must also have a certificate that can be used with ADFS.' -ForegroundColor Red
                        Write-Host 'THIS OPTION WILL OVERWITE ANY EXISTING CONFIGURATION!' -BackgroundColor Red
                        Get-ContinueAnswer
                        Write-Host "Please enter the name of the new ADFS farm to configure:" -BackgroundColor Green -ForegroundColor Red
                        $FarmName = Read-Host
                        $CertThumbprint = Get-ChildItem -Path Cert:\LocalMachine\My | where {$_.Subject -like "CN=$FarmName*"}
                        Get-CertificateInstallation
                        Get-ADFSInstallStatus
                        Install-ADFSWithWIDorSQL
                        Restart-Service AdfsSrv -Force
                } '2' {
                        cls
                        'You chose option #2'
                        Write-Host 'Option #2 joins this server to an existing ADFS Farm. You must have the ADFS service account credentials as well as a certificate for ADFS.' -ForegroundColor Red
                        Write-Host 'THIS OPTION WILL OVERWITE ANY EXISTING CONFIGURATION!' -BackgroundColor Red
                        Get-ContinueAnswer
                        $CertThumbprint = Get-ChildItem -Path Cert:\LocalMachine\My | where {$_.Subject -like "CN=$FarmName*"}
                        Get-CertificateInstallation
                        Get-ADFSInstallStatus
                        Install-ADFSSecondaryWithWIDorSQL
                        Restart-Service AdfsSrv -Force
                } '3' {
                        cls
                        'You chose option #3'
                        Write-Host 'Option #3 configures this server as a Proxy for an existing ADFS Farm. You must have the ADFS service account credentials, the ADFS IP or VIP, and a certificate for ADFS.' -ForegroundColor Red
                        Get-ContinueAnswer
                        Write-Host "Please enter the IP address of the ADFS Farm or VIP of the load balancer for ADFS:" -BackgroundColor Green -ForegroundColor Red
                        $HOSTSIP = Read-Host
                        Write-Host "Please enter the name of the ADFS Farm (e.g. sso.domain.com):" -BackgroundColor Green -ForegroundColor Red
                        $FarmName = Read-Host
                        Add-HOSTFileContent -IPAddress $HOSTSIP -computer $FarmName
                        $CertThumbprint = Get-ChildItem -Path Cert:\LocalMachine\My | where {$_.Subject -like "CN=$FarmName*"}
                        Get-CertificateInstallation
                        Install-ADFSProxy
                } '4' {
                        cls
                        'You chose option #4'
                        Write-Host 'Option #4 imports a PFX certificate onto this server. You must have the PFX certificate file and the PFX password.' -ForegroundColor Red
                        Get-ContinueAnswer
                        Install-ADFSCert
                } '5' {
                        cls
                        'You chose option #5'
                        Write-Host 'Option 5 allows you to join this server to a domain. You must have domain administrator credentials.' -ForegroundColor Red
                        Get-ContinueAnswer
                        Join-Domain
                } '6' {
                        cls
                        'You chose option #6'
                        Get-RebootAnswer
                } '7' {
                        cls
                        'You chose option #7'
                        Write-Host 'Options #7 installs the Azure AD PowerShell tools. This will install .NET 3.5, the Microsoft Online Service Sign-In Assistant, and the Azure AD PowerShell module.' -ForegroundColor Red
                        Get-ContinueAnswer
                        Install-AzureADPowerShell
                        Get-AzureADInstallStatus
                } '8' {
                        cls
                        'You chose option #8'
                        Write-Host 'Option #8 allows you to convert a domain to federated in your Office 365 tenant. You must run this option from the primary ADFS server and have Office 365 Global Administrator credentials.' -ForegroundColor Red
                        Get-ContinueAnswer
                        Import-Module MSOnline
                        Get-AzureADInstallStatus
                        Convert-DomainToFederated
                } '9' {
                        cls
                        'You chose option #9'
                        Write-Host 'Option #9 allows you to convert a domain to standard in your Office 365 tenant. This will allow users to sign in via password synced passwords or using cloud passwords.' -ForegroundColor Red
                        Write-Host 'THIS OPTION WILL BREAK EXISTING AUTHENTICATION FUNCTIONALITY FOR CLOUD USERS IN THE SPECIFIED DOMAIN!!!' -BackgroundColor Red
                        Get-ContinueAnswer
                        Import-Module MSOnline
                        Get-AzureADInstallStatus
                        Convert-DomainToManaged
                } '10' {
                        cls
                        do
                        {
                            Show-ADFSSubMenu
                            $input = Read-Host "Please make a selection"
                            :SubMenu switch ($input)
                            {
                                '1' {
                                    cls
                                    'You chose option #1'
                                    'Option #1 extends the lifetimes for the Token-Signing and Token-Decrypting certificates to 5 years and regenerates the certificates.'
                                    Write-Host 'This will break existing relationships! Perform on new servers or during a change window!' -ForegroundColor Red
                                    Get-ContinueAnswer
                                    Get-ADFSInstallStatusForSubmenu
                                    Set-AdfsProperties -CertificateDuration 1827
                                    Update-AdfsCertificate -CertificateType Token-Decrypting -Urgent
                                    Update-AdfsCertificate -CertificateType Token-Signing -Urgent
                                    Restart-Service AdfsSrv -Force
                                    Get-AdfsProperties | Select CertificateDuration
                                    # Tested - Works
                                } '2' {
                                    cls
                                    'You chose option #2'
                                    'Option #2 enables the end user password reset webpage.'
                                    Get-ContinueAnswer
                                    Get-ADFSInstallStatusForSubmenu
                                    Enable-AdfsEndpoint "/adfs/portal/updatepassword/"
                                    Set-AdfsEndpoint "/adfs/portal/updatepassword/" -Proxy:$true
                                    Restart-Service AdfsSrv -Force
                                } '3' {
                                    cls
                                    'You chose option #3'
                                    'Option #3 enables WS-TRUST 1.3 for Desktop Client Single Sign-On.'
                                    Get-ContinueAnswer
                                    Get-ADFSInstallStatusForSubmenu
                                    Enable-AdfsEndpoint -TargetAddressPath "/adfs/services/trust/13/windowstransport"
                                    Restart-Service AdfsSrv -Force
                                } '4' {
                                    cls
                                    'You chose option #4'
                                    'Option #4 extends tickets for browser sessions to 24 hours.'
                                    Get-ContinueAnswer
                                    Get-ADFSInstallStatusForSubmenu
                                    Set-AdfsProperties -EnableKmsi:$true
                                    Restart-Service AdfsSrv -Force
                                } '5' {
                                    cls
                                    'You chose option #5'
                                    'Option #5 enables usable logging in Event Viewer.'
                                    Get-ContinueAnswer
                                    Get-ADFSInstallStatusForSubmenu
                                    Set-AdfsProperties -LogLevel Errors,Warnings,Information,SuccessAudits,FailureAudits
                                    Restart-Service AdfsSrv -Force
                                    # Tested - Works
                                } '6' {
                                    cls
                                    'You chose option #6'
                                    'Option #6 configures the ADFS logo.'
                                    Get-ContinueAnswer
                                    Get-ADFSInstallStatusForSubmenu
                                    Write-Host "Please enter the patch to the logo image file:" -ForegroundColor Red
                                    $logopath = read-host
                                    Set-AdfsWebTheme -TargetName default -Logo @{path="$logopath"}
                                    Restart-Service AdfsSrv -Force
                                } '7' {
                                    cls
                                    'You chose option #7'
                                    'Option #7 allows you to configure the ADFS webpage text.'
                                    Get-ContinueAnswer
                                    Get-ADFSInstallStatusForSubmenu
                                    Write-Host "Please enter the URL for the Help Desk link:" -ForegroundColor Red
                                    $helpdesklink = read-host
                                    Write-Host "Please enter the text for the Help Desk link:" -ForegroundColor Red
                                    $helpdesktext = read-host
                                    Write-Host "Please enter the URL for the Homepage link:" -ForegroundColor Red
                                    $homepagelink = read-host
                                    Write-Host "Please enter the text for the Homepage link:" -ForegroundColor Red
                                    $homepagetext = read-host
                                    Write-Host "Please enter the URL for the Privacy link:" -ForegroundColor Red
                                    $privacylink = read-host
                                    Write-Host "Please enter the text for the Privacy link:" -ForegroundColor Red
                                    $privacytext = read-host
                                    Set-AdfsGlobalWebContent -HelpDeskLink "$helpdesklink" -HelpDeskLinkText "$helpdesktext" -HomeLink "$homepagelink" -HomeLinkText "$homepagetext" -PrivacyLink "$privacylink" -PrivacyLinkText "$privacytext"
                                    Restart-Service AdfsSrv -Force
                                } '8' {
                                    cls
                                    'You chose option #8'
                                    'Option #8 sets the primary authentication types to default.'
                                    Get-ContinueAnswer
                                    Get-ADFSInstallStatusForSubmenu
                                    Set-AdfsGlobalAuthenticationPolicy -PrimaryExtranetAuthenticationProvider FormsAuthentication -PrimaryIntranetAuthenticationProvider FormsAuthentication, WindowsAuthentication
                                    Restart-Service AdfsSrv -Force
                                } '9' {
                                    cls
                                    'You chose option #9'
                                    'Option #9 disables Windows authentication popups and forces the usage of Forms authentication.'
                                    Get-ContinueAnswer
                                    Get-ADFSInstallStatusForSubmenu
                                    Set-AdfsGlobalAuthenticationPolicy -PrimaryExtranetAuthenticationProvider FormsAuthentication -PrimaryIntranetAuthenticationProvider FormsAuthentication
                                    Restart-Service AdfsSrv -Force
                                } '10' {
                                    cls
                                    'You chose option #10'
                                    'Option #10 sets Forms authentication as the default authentication type and sets Windows authentication as a fallback option.'
                                    Get-ContinueAnswer
                                    Get-ADFSInstallStatusForSubmenu
                                    Set-AdfsGlobalAuthenticationPolicy -PrimaryExtranetAuthenticationProvider FormsAuthentication -PrimaryIntranetAuthenticationProvider FormsAuthentication -WindowsIntegratedFallbackEnabled $true
                                    Restart-Service AdfsSrv -Force
                                } '11' {
                                    cls
                                    'You chose option #11'
                                    'Option #11 configures SNI to allow load balancer health checking and non-SNI clients to connect to this ADFS server.'
                                    Get-ContinueAnswer
                                    Get-ADFSInstallStatusForSNI
                                    Configure-ADFSSNI
                                } '12' {
                                    cls
                                    'You chose option #12'
                                    'Option #12 configures SNI to allow load balancer health checking and non-SNI clients to connect to this WAP server.'
                                    Get-ContinueAnswer
                                    Get-ProxyInstallStatusForSNI
                                    Configure-ProxySNI
                                } '13' {
                                    cls
                                    'You chose option #13'
                                    'Option #13 removes the SNI configuration for 0.0.0.0:443. You may need to run this option if you have recently changed the ADFS certificate.'
                                    Get-ContinueAnswer
                                    Get-ADFSInstallStatusForSNI
                                    Remove-ADFSSNI
                                    Write-Host "Please run Option #11 to reconfigure SNI for this ADFS server with the new certificate." -ForegroundColor Red
                                } '14' {
                                    cls
                                    'You chose option #14'
                                    'Option #14 removes the SNI configuration for 0.0.0.0:443. You may need to run this option if you have recently changed the Proxy certificate.'
                                    Get-ContinueAnswer
                                    Get-ProxyInstallStatusForSNI
                                    Remove-ProxySNI
                                    Write-Host "Please run Option #12 to reconfigure SNI for this Proxy server with the new certificate." -ForegroundColor Red
                                } '15' {
                                    cls
                                    'You chose option #15'
                                    'Option #15 adds an inbound firewall rule for port 80, which some Proxy servers may need for health checking.'
                                    'The health check page is http://servername/adfs/probe'
                                    Get-ContinueAnswer
                                    New-NetFirewallRule -Name "Allow Port 80 Inbound" -DisplayName "Allow Port 80 Inbound" -Enabled True -Profile Any -Action Allow -Direction Inbound -LocalPort 80 -Protocol TCP
                                } 'q' {
                                    $input = $null
                                    break Menu
                                }
                            }
                            pause
                        }
                        until ($input -eq 'q')
                } 'q' {
                        return
                }
            }
            pause
        }
        until ($input -eq 'q')
