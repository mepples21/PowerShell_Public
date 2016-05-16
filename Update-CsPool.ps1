<#

.SYNOPSIS
Helps manage reboots and patching for Roadrunner servers

.DESCRIPTION
##

.NOTES
    Version         : 1.0
    Wish list       : Make error logging more verbose (report computer name of computer throwing error)
                      Test functionality
                      Add SQL backend patching for AlwaysOn and Mirroring (probably mirroring first)
                      
    Author(s)       : Michael Epping (mepping@concurrency.com)
    Assumptions     : ExecutionPolicy of AllSigned (recommended), RemoteSigned or Unrestricted (not recommended)
    Limitations     :
    Known Issues    : None yet, but I'm sure you'll find some!

.EXAMPLE
<Enter Text>

/#>

## Define Parameters
    Param
        (
            [parameter(Mandatory=$true)]
            [string] $cspoolname = $(Read-Host "Name of the pool with servers to be updated.")

        )

## Define Functions

    # 

## Start Script

    # Check for PowerShell Version and Skype for Business Module
        $theVersion = $PSVersionTable.PSVersion
        $MajorVersion = $theVersion.Major

        Write-Host ""
        Write-Host "--------------------------------------------------------------"
        Write-Host "Powershell Version Check..." -foreground "yellow"
        if($MajorVersion -eq  "1")
        {
            Write-Host "This machine only has Version 1 Powershell installed.  This version of Powershell is not supported." -foreground "red"
        }
        elseif($MajorVersion -eq  "2")
        {
            Write-Host "This machine has Version 2 Powershell installed. This version of Powershell is not supported." -foreground "red"
        }
        elseif($MajorVersion -eq  "3")
        {
            Write-Host "This machine has version 3 Powershell installed. CHECK PASSED!" -foreground "green"
        }
        elseif($MajorVersion -eq  "4")
        {
            Write-Host "This machine has version 4 Powershell installed. CHECK PASSED!" -foreground "green"
        }
        else
        {
            Write-Host "This machine has version $MajorVersion Powershell installed. Unknown level of support for this version." -foreground "yellow"
        }
        Write-Host "--------------------------------------------------------------"
        Write-Host ""

        Function Get-MyModule 
        { 
        Param([string]$name) 
            
            if(-not(Get-Module -name $name)) 
            { 
                if(Get-Module -ListAvailable | Where-Object { $_.name -eq $name }) 
                { 
                    Import-Module -Name $name 
                    return $true 
                } #end if module available then import 
                else 
                { 
                    return $false 
                } #module not available 
            } # end if not module 
            else 
            { 
                return $true 
            } #module already loaded 
        } #end function get-MyModule 


        $Script:LyncModuleAvailable = $false
        $Script:SkypeModuleAvailable = $false

        Write-Host "--------------------------------------------------------------"
        #Import Lync Module
        if(Get-MyModule "Lync")
        {
            Invoke-Expression "Import-Module Lync"
            Write-Host "Imported Lync Module..." -foreground "green"
            $Script:LyncModuleAvailable = $true
        }
        else
        {
            Write-Host "Unable to import Lync Module... The Lync module is required to run this tool." -foreground "yellow"
        }
        #Import SkypeforBusiness Module
        if(Get-MyModule "SkypeforBusiness")
        {
            Invoke-Expression "Import-Module SkypeforBusiness"
            Write-Host "Imported SkypeforBusiness Module..." -foreground "green"
            $Script:SkypeModuleAvailable = $true
        }
        else
        {
            Write-Host "Unable to import SkypeforBusiness Module... (Expected on a Lync 2013 system)" -foreground "yellow"
        }

    # Get pool members
        $csservers = Get-CsComputer -Pool $cspoolname
        
    # Check if script is being run from one of the pool servers
        $LocalComputerName = $(Get-WmiObject Win32_Computersystem).name
        $LocalComputerDomain = $(Get-WmiObject Win32_Computersystem).domain
        $LocalComputerFqdn = $LocalComputerName + '.' + $LocalComputerDomain
        foreach ($server in $csservers) {
            if ($LocalComputerFqdn -eq $server.Fqdn) {
                write-host "This script is being run from a server in the specified pool. Please rerun this script from a differrent server not in the pool." -ForegroundColor Red
                Break
            } else {
                Continue
            }
        }
        
    # Perform patch on each server in pool
        try {
            foreach ($server in $csservers) {
                # Fail over services
                Invoke-CsComputerFailover -ComputerName $server.Fqdn.ToString() -Confirm:$false
                
                # Wait for RTC services to stop
                    $RTCServiceStatus = Get-CsWindowsService -ComputerName $server.Fqdn.ToString()
                    foreach ($service in $RTCServiceStatus) {
                        do {
                            if ($service.Status -ne "Stopped") {
                                Write-Host  "$service.status is still running. Waiting..."
                                Start-Sleep 5
                            } else {
                                Continue
                            }
                        } until ($service.status -eq "Stopped")
                    }
                
                # Start session on remote computer
                Invoke-Command -ComputerName $server.Fqdn.ToString() -Scriptblock {
                
                    # Check if Windows Update PowerShell Module is Installed and Install if it is not
                        
                        # Check module installation
                            $PSUpdateModuleExists = Get-Item -Path C:\WindowsUpdatePowerShell\PSWindowsUpdate
                            
                            if ($PSUpdateModuleExists -ne $null) {
                                ipmo C:\WindowsUpdatePowerShell\PSWindowsUpdate
                                try {
                                    Get-WUInstall -MicrosoftUpdate -IgnoreUserInput -AcceptAll -Verbose
                                }
                                catch {
                                    write-host "Exception Message: $($_.Exception.GetType).FullName)" -ForegroundColor Red
                                    write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
                                    Break  
                                }                        
                            } else {                       
                                # Download, Extract, and Install moduleif necessary
                                    try {
                                        mkdir c:\WindowsUpdatePowerShell
                                        Invoke-WebRequest -Uri https://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc/file/41459/43/PSWindowsUpdate.zip -OutFile c:\WindowsUpdatePowerShell\PSWindowsUpdate.zip
                                        $BackUpPath = “c:\WindowsUpdatePowerShell\PSWindowsUpdate.zip”
                                        $Destination = “C:\WindowsUpdatePowerShell”
                                        Add-Type -assembly “system.io.compression.filesystem”
                                        [io.compression.zipfile]::ExtractToDirectory($BackUpPath, $destination)
                                        ipmo c:\WindowsUpdatePowerShell\PSWindowsUpdate
                                    }
                                    catch {
                                        write-host "Exception Message: $($_.Exception.GetType).FullName)" -ForegroundColor Red
                                        write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
                                        Break
                                    }
                                    
                                # Install Windows Updates
                                    try {
                                        Get-WUInstall -MicrosoftUpdate -IgnoreUserInput -AcceptAll -Verbose
                                    }
                                    catch {
                                        write-host "Exception Message: $($_.Exception.GetType).FullName)" -ForegroundColor Red
                                        write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
                                        Break  
                                    }
                            }
                }
                    
                # Check if reboot required and reboot server
                    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
                    $name = 'PendingFileRenameOperations'
                    Invoke-Command -ComputerName $server.Fqdn.ToString() -Scriptblock {$RebootStatus = Get-ItemProperty -Path $path -Name $name}
                    $RebootStatus | Select-Object @{
                        LABEL='RebootRequired';
                        EXPRESSION={if($_.PendingFileRenameOperations){$true}}}
                    
                    if ($RebootStatus.RebootRequired -eq $true) {
                        Restart-Computer -ComputerName $server.Fqdn.ToString() -Force
                        Start-Sleep 20
                        do {
                            $ServiceStatus = Get-Service W3SVC -ComputerName $server.Fqdn.ToString
                            Write-Host "Waiting for the W3SVC service to start on $server.Fqdn."
                        } until ($ServiceStatus.Status -eq "Running")
                    } else {
                        Continue
                    }
                    
                # Fail services back
                    try {
                        Invoke-CsComputerFailback -ComputerName $server.Fqdn.ToString() -Confirm:$false
                    }
                    catch {
                        write-host "Exception Message: $($_.Exception.GetType).FullName)" -ForegroundColor Red
                        write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
                        Exit
                    }
            }
        }
        catch {
            write-host "Exception Message: $($_.Exception.GetType).FullName)" -ForegroundColor Red
            write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
            Break
        }