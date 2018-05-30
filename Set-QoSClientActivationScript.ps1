<#
.SYNOPSIS
Skype for Business Online QoS Client Activation Script

.Description
Skype for Business Online QoS Client Activation Script

.NOTES
  Version      	   		: 0.0.2
  Author(s)    			: Erwin Bierens
  Email/Blog/Twitter	: erwin@bierens.it https://erwinbierens.com @erwinbierens

.EXAMPLE
.\Set-QoSClientActivationScript.ps1

#>

Write-Host -ForegroundColor Yellow "Make sure you run this script in a elevated powershell console"
[void](Read-Host 'Press Enter run this script, or CTRL/C to end script…')

# Create QoS Policys
New-NetQosPolicy -Name "SkypeOnlineClientAudio1" -AppPathName "lync.exe" -IPProtocol UDP -IPSrcPortStart 3478 -IPSrcPortEnd 3479 -DSCPValue 46
New-NetQosPolicy -Name "SkypeOnlineClientAudio2" -AppPathName "lync.exe" -IPProtocol Both -IPSrcPortStart 50000 -IPSrcPortEnd 50019 -DSCPValue 46

New-NetQosPolicy -Name "SkypeOnlineClientVideo1" -AppPathName "lync.exe" -IPProtocol UDP -IPSrcPortStart 3480 -IPSrcPortEnd 3480 -DSCPValue 34
New-NetQosPolicy -Name "SkypeOnlineClientVideo2" -AppPathName "lync.exe" -IPProtocol Both -IPSrcPortStart 50020 -IPSrcPortEnd 50039 -DSCPValue 34

New-NetQosPolicy -Name "SkypeOnlineClientSharing1" -AppPathName "lync.exe" -IPProtocol UDP -IPSrcPortStart 3481 -IPSrcPortEnd 3481 -DSCPValue 24
New-NetQosPolicy -Name "SkypeOnlineClientSharing2" -AppPathName "lync.exe" -IPProtocol Both -IPSrcPortStart 50040 -IPSrcPortEnd 50059 -DSCPValue 24

Write-Host -ForegroundColor Green "----------------------------------------------------------------"
Write-Host -ForegroundColor Green "--------------- Created all of the QoS Policies ----------------"
Write-Host -ForegroundColor Green "----------------------------------------------------------------"

# List previous builded Policys
Get-NetQoSPolicy | Format-Table Name,AppPathName,IPProtocol,IPSrcPortStart,IPSrcPortEnd,DSCPValue

# Create Registry setting to enable QoS
New-Item -Path "HKLM:SYSTEM\CurrentControlSet\Services\Tcpip\" -Name QoS -Value "Default Value" -Force
New-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Services\Tcpip\QoS" -Name "Do not use NLA" -Value "1" -PropertyType String -Force |Out-Null

Write-Host -ForegroundColor Green "----------------------------------------------------------------"
Write-Host -ForegroundColor Green "-------------- Created all of the Registry Items ---------------"
Write-Host -ForegroundColor Green "----------------------------------------------------------------"
#update local store
gpupdate /force