#################################################################################
# Written by: Nicolas Fasolo 
# Name: BlazingDIFR.ps1
# email: nicolas.fasolo@hotmail.it
#
#	Collects DIFR data from a specified host that the script will ask for
# ex: .\BlazingDIFR.ps1 -collect
#
#	Start DIFR process in a specified host that the script will ask for
# ex: .\BlazingDIFR.ps1 -target
#
#	Start DIFR process in a specified host list (Expects ./EndpointList.txt List)
# ex: .\BlazingDIFR.ps1 -list
#
#	Collects DIFR data from a specified host list
# ex: .\BlazingDIFR.ps1 -list -collect
#
#################################################################################
#ARGS
###### DFIR FUNCTIONS ######
# This section contains the functions used inside main routines

##############################
###### Core FUNCTIONS Routines ######

function DIFRHost {

			param (
				$_endpointName
			)

			$_remoteEdp = $_endpointName;
			#Collection ZIP File
			$_dataToExtract = -join("C:\", $_remoteEdp, ".zip");
			$_localEdpPath = -join($_localPath, $_remoteEdp); #Path Variable
			#Remote PSSession Establishment
			#wmic /node:$_endpointName process call create "winrm quickconfig" -Credential $_secureCreds
			#wmic /node:$servername share list brief -Credential $_secureCreds
			$RemoteSession = New-PSSession -Computername $_remoteEdp -Credential $_secureCreds;
			#$_dfirSharePath = -join("\\", $_serverIp, "\IR_Data\"); #PATH per RemoteDir	
			$_localPathsExists = Test-Path  $_localEdpPath;
			#Tools Copying
			Copy-Item -ToSession $RemoteSession -Recurse -Path ".\tools" -Destination "C:\";
						
			Invoke-Command -Session $RemoteSession -ArgumentList $_dataToExtract -Scriptblock {	
			param($_dataToExtract); # Param to pass local script var into invoke-command
			$_DFIRPathExists = Test-Path  "C:\DFIR";
			if($_DFIRPathExists -eq $false)
			{
				New-Item -ItemType Directory -Force -Path "C:\DFIR";
			}
#			$_DFIRFileExists = Test-Path  $_dataToExtract;
#			if($_DFIRFileExists -eq $true)
#			{
#				Remove-Item -Recurse -Force $_dataToExtract;
#			}	
			
			#MEMORY ACQUISITION			
			Start-Process -NoNewWindow -WindowStyle Hidden -FilePath "C:\tools\winpmem_mini_x64_rc2.exe" -ArgumentList ("C:\DFIR\" + $env:computername + ".raw");
			
			#AUTORUNS SECTION
			Write-Host "Starting comprehensive autoruns collection for all users...";	
			Start-Process -NoNewWindow -WindowStyle Hidden -FilePath "C:\tools\autoruns_collector.bat";		
			Write-Host "Success!";	
			#Wait time SECTION
			Write-Host "I'm waiting to let memory acquisition process end successfully...";		
			$_sleepTime = 80;
			DO
			{
				Start-Sleep -s 1;
				$_sleepTime = $_sleepTime - 1;
				Write-Host $_sleepTime "seconds left";
			}while($_sleepTime -gt 0)
			
			
			#ENUMERATION SECTION	
			Write-Host "Enumeration Sections has started...";
			### System infos ###
			systeminfo > C:\DFIR\SysInfos.txt;
			wmic csproduct get name > C:\DFIR\csproduct.txt;
			wmic bios get serialnumber > C:\DFIR\BiosSerial.txt;
			### Shares infos ###			
			wmic share list brief > C:\DFIR\SharesList.txt;
			net use > C:\DFIR\netUse.txt;
			net session > C:\DFIR\netSession.txt;
			net view \\127.0.0.1 > C:\DFIR\netView.txt;
			Write-Host "Shares infos gathered!";
			### Process infos ###
			wmic process list > C:\DFIR\ProcessList.txt;
			wmic process list status > C:\DFIR\ProcessListStatus.txt;
			wmic process list memory > C:\DFIR\ProcessListMemory.txt;
			Get-Process > C:\DFIR\Get_Process.txt;
			wmic job list brief > C:\DFIR\WMIjobList.txt;
			Write-Host "Process infos gathered!";
			### Autostart infos ###
			wmic startup list brief > C:\DFIR\AutostartData.txt;
			wmic ntdomain list brief >> C:\DFIR\AutostartData.txt;
			schtasks > C:\DFIR\schtasks.txt;
			Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" -Destination "C:\DFIR\Startup_1" -Recurse;			
			Copy-Item -Path "%userprofile%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs" -Destination "C:\DFIR\Startup_2" -Recurse;
			Copy-Item -Path "C:\Windows\System32\Tasks" -Destination "C:\DFIR\Sys32Tasks" -Recurse;	
			Copy-Item -Path "C:\Windows\Tasks" -Destination "C:\DFIR\WinTasks" -Recurse;	
			Write-Host "Some autostart infos gathered!";
			### Domain infos ###
			wmic ntdomain list >  C:\DFIR\NtdomainList.txt;
			wmic useraccount list >  C:\DFIR\UseraccountList.txt;
			wmic group list >  C:\DFIR\DomaingroupsList.txt;
			Write-Host "Domain infos gathered!";
			### System account list ###
			wmic sysaccount list >  C:\DFIR\SysaccountList.txt;
			wmic USERACCOUNT get "Domain,Name,Sid" > C:\DFIR\LocalUsersAccounts.txt;
			Write-Host "System account list gathered!";
			### CPU Cache infos ###
			wmic memcache list brief > C:\DFIR\CPUcache.txt;
			Get-WmiObject win32_processor >> C:\DFIR\CPUcache.txt;	
			Write-Host "CPU Cache infos gathered!";
			### Network Data ###
			ipconfig /allcompartments /all > C:\DFIR\NetworkGeneralData.txt;
			netstat -naob > C:\DFIR\NetStats.txt;
			netstat -nr  >> C:\DFIR\NetStats.txt;
			netstat -vb >> C:\DFIR\NetStats.txt;
			nbtstat -S > C:\DFIR\nbtstat.txt;
			route print > C:\DFIR\routePrint.txt;
			apr -a > C:\DFIR\Arp.txt;
			netsh wlan show all > C:\DFIR\netshAll.txt;
			Get-NetRoute | Format-List -Property * > C:\DFIR\NetRoute.txt;	
			Get-NetNeighbor | Format-List -Property * > C:\DFIR\ARPcache.txt;	
			wmic nicconfig get description,IPAddress,MACaddress > C:\DFIR\NICconfig.txt;	
			Write-Host "Network Data gathered!";
			### DNS infos ###
			ipconfig /displaydns > C:\DFIR\DNSInfos.txt;
			Copy-Item -Path "%SystemRoot%\System32\Drivers\etc\hosts" -Destination "C:\DFIR\hosts";
			Write-Host "DNS INFOs Data gathered!";
			### OS Specifics ###
			wmic os LIST Full > C:\DFIR\OSinfo.txt;
			wmic computersystem LIST full >> C:\DFIR\OSinfo.txt;
			Write-Host "OS Specifics gathered!";
			### Service Infos ###
			net start > C:\DFIR\netStart.txt;
			tasklist > C:\DFIR\tasklist.txt;
			tasklist /svc > C:\DFIR\tasklistSVC.txt;
			wmic service list config > C:\DFIR\servicesConfig.txt;
			Write-Host "Service Data gathered!";
			### Peripherals ###
			wmic path Win32_PnPdevice > C:\DFIR\OSinfo.txt;
			Write-Host "Peripherals Data gathered!";
			### Patches ###
			wmic qfe list > C:\DFIR\qfeList.txt;
			wmic computersystem get manufacturer > C:\DFIR\deviceManufacturer.txt;
			cipher /y > C:\DFIR\cypheredEFS.txt;
			Write-Host "Patches Data gathered!";
			### Windows Event Logs ###
			Copy-Item -Path "C:\Windows\System32\winevt\Logs" -Destination "C:\DFIR\WinevtLogs" -Recurse;
			Write-Host "Windows Event Logs gathered!";
			### Windows Firewall ###
			netsh firewall show portopening > C:\DFIR\windowsFirewall_portopening.txt;
			netsh firewall show allowedprogram > C:\DFIR\windowsFirewall_allowedprogram.txt;
			netsh firewall show config > C:\DFIR\windowsFirewall_config.txt;
			Write-Host "Windows Firewall Data gathered!";
			### Temporary Files ###
			Copy-Item -Path $env:TEMP -Destination "C:\DFIR\userTMP" -Recurse;
			Copy-Item -Path "C:\Windows\temp" -Destination "C:\DFIR\winTMP" -Recurse;
			Write-Host "Temporary Files gathered!";
			### Registry Export ###
			reg export HKLM "C:\DFIR\HKLM.Reg" /y;
			Write-Host "HKLM Registry gathered!";	
			### Current User Registry Export ###
			reg export HKCU "C:\DFIR\HKCU.Reg" /y;
			Write-Host "HKCU Registry gathered!";					
			### Directory Listing and File Search ###	
			Write-Host "Searching for password files...";			
			wmic DATAFILE where "drive='C:' AND Name like '%password%'" GET Name,readable,size /VALUE > C:\DFIR\PasswordFiles.txt;
			Write-Host "Done!";
			
			
			### AV products listing ###
			try
			{
				wmic /namespace:\\root\securitycenter2 path antivirusproduct get * /value > C:\DFIR\AVproductsSecCenter.txt;
				Write-Host "Av data gathered!";
			}
			catch
			{
				Write-Host "The target does not have SecurityCenter2 --> Probably it is a server, no antivirus data available!"
			}	
			
			#COMPRESSION SECTION	
			Write-Host "Starting to compress payload... Hold on...";
			$completed = $false;			
			DO
			{
				try{
					#Compress-Archive -Path C:\Enumeration.txt -Update -DestinationPath $_dataToExtract;	
					#Creates NetFramework 4.5 method to compress files larger than 2 GB
					Add-Type -AssemblyName System.IO.Compression.FileSystem; #NET FRAMEWORK Reference	
					[IO.Compression.ZipFile]::CreateFromDirectory("C:\DFIR",$_dataToExtract, [IO.Compression.CompressionLevel]::Optimal, $true, [Text.Encoding]::Default);
					$completed = $true;
					Write-Host "Payload Compessed, you can use -collect switch to retrieve data from " $env:computername " PATH --> " $_dataToExtract;
				}
				catch
				{
					$completed = $false;
					Write-Host "Payload Compession failed, I'll retry in 5 seconds";
					Write-Host $_;
					Start-Sleep -s 5;
				}
			}while($completed -eq $false)
			
		};	
		
		#Disconnect & Rmeove Sessions
		Get-PSSession | Disconnect-PSSession;
		Get-PSSession | Remove-PSSession;
}

#################################################################################
# Written by: Nicolas Fasolo 
# Name: BlazingDIFR.ps1
# email: nicolas.fasolo@hotmail.it
#
# Copyright NF_Security
#
#	Collects DIFR data from a specified host that the script will ask for
# ex: .\BlazingDIFR.ps1 -collect
#
#	Start DIFR process in a specified host that the script will ask for
# ex: .\BlazingDIFR.ps1 -target
#
#	Start DIFR process in a specified host list
# ex: .\BlazingDIFR.ps1 -list
#
#	Collects DIFR data from a specified host list
# ex: .\BlazingDIFR.ps1 -list -collect
#
#################################################################################

#DFIR Share (Locally created)

Write-Host "In the process you will see some errors (usually in red) don't worry it depends on the system type and configurations.";
#Collection ZIP File
$_remoteEdp = $env:computername;
$_dataToExtract = -join("C:\", $_remoteEdp, ".zip");

$_DFIRPathExists = Test-Path  "C:\DFIR";
if($_DFIRPathExists -eq $false)
{
	New-Item -ItemType Directory -Force -Path "C:\DFIR";
}
$_DFIRFileExists = Test-Path  $_dataToExtract;
if($_DFIRFileExists -eq $true)
{
	Remove-Item -Recurse -Force $_dataToExtract;
}	

#MEMORY ACQUISITION			
#Start-Process -NoNewWindow -WindowStyle Hidden -FilePath ".\tools\winpmem_mini_x64_rc2.exe" -ArgumentList ("C:\DFIR\" + $env:computername + ".raw");

#AUTORUNS SECTION
Write-Host "Starting comprehensive autoruns collection for all users...";	
Start-Process -NoNewWindow -WindowStyle Hidden -FilePath ".\tools\autoruns_localcollector.bat";
Write-Host "Success!";	
#Wait time SECTION
Write-Host "I'm waiting to let memory acquisition process end successfully...";		
$_sleepTime = 80;
DO
{
	Start-Sleep -s 1;
	$_sleepTime = $_sleepTime - 1;
	Write-Host $_sleepTime "seconds left";
}while($_sleepTime -gt 0)


#ENUMERATION SECTION	
Write-Host "Enumeration Sections has started...";
### System infos ###
systeminfo > C:\DFIR\SysInfos.txt;
wmic csproduct get name > C:\DFIR\csproduct.txt;
wmic bios get serialnumber > C:\DFIR\BiosSerial.txt;
### Shares infos ###			
wmic share list brief > C:\DFIR\SharesList.txt;
net use > C:\DFIR\netUse.txt;
net session > C:\DFIR\netSession.txt;
net view \\127.0.0.1 > C:\DFIR\netView.txt;
Write-Host "Shares infos gathered!";
### Process infos ###
wmic process list > C:\DFIR\ProcessList.txt;
wmic process list status > C:\DFIR\ProcessListStatus.txt;
wmic process list memory > C:\DFIR\ProcessListMemory.txt;
Get-Process > C:\DFIR\Get_Process.txt
wmic job list brief > C:\DFIR\WMIjobList.txt;
Write-Host "Process infos gathered!";
### Autostart infos ###
wmic startup list brief > C:\DFIR\AutostartData.txt;
wmic ntdomain list brief >> C:\DFIR\AutostartData.txt;
schtasks > C:\DFIR\schtasks.txt;
Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" -Destination "C:\DFIR\Startup_1" -Recurse;			
Copy-Item -Path "C:\%userprofile%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs" -Destination "C:\DFIR\Startup_2" -Recurse;
Copy-Item -Path "C:\Windows\System32\Tasks" -Destination "C:\DFIR\Sys32Tasks" -Recurse;	
Copy-Item -Path "C:\Windows\Tasks" -Destination "C:\DFIR\WinTasks" -Recurse;	
Write-Host "Some autostart infos gathered!";
### Domain infos ###
wmic ntdomain list >  C:\DFIR\NtdomainList.txt;
wmic useraccount list >  C:\DFIR\UseraccountList.txt;
wmic group list >  C:\DFIR\DomaingroupsList.txt;
Write-Host "Domain infos gathered!";
### System account list ###
wmic sysaccount list >  C:\DFIR\SysaccountList.txt;
wmic USERACCOUNT get "Domain,Name,Sid" > C:\DFIR\LocalUsersAccounts.txt;
Write-Host "System account list gathered!";
### CPU Cache infos ###
wmic memcache list brief > C:\DFIR\CPUcache.txt;
Get-WmiObject win32_processor >> C:\DFIR\CPUcache.txt;	
Write-Host "CPU Cache infos gathered!";
### Network Data ###
ipconfig /allcompartments /all > C:\DFIR\NetworkGeneralData.txt;
netstat -naob > C:\DFIR\NetStats.txt;
netstat -nr  >> C:\DFIR\NetStats.txt;
netstat -vb >> C:\DFIR\NetStats.txt;
nbtstat -S > C:\DFIR\nbtstat.txt;
route print > C:\DFIR\routePrint.txt;
arp -a > C:\DFIR\Arp.txt;
netsh wlan show all > C:\DFIR\netshAll.txt;
Get-NetRoute | Format-List -Property * > C:\DFIR\NetRoute.txt;	
Get-NetNeighbor | Format-List -Property * > C:\DFIR\ARPcache.txt;	
wmic nicconfig get description,IPAddress,MACaddress > C:\DFIR\NICconfig.txt;	
Write-Host "Network Data gathered!";
### DNS infos ###
ipconfig /displaydns > C:\DFIR\DNSInfos.txt;
Copy-Item -Path "C:\%SystemRoot%\System32\Drivers\etc\hosts" -Destination "C:\DFIR\hosts";
Write-Host "DNS INFOs Data gathered!";
### OS Specifics ###
wmic os LIST Full > C:\DFIR\OSinfo.txt;
wmic computersystem LIST full >> C:\DFIR\OSinfo.txt;
Write-Host "OS Specifics gathered!";
### Service Infos ###
net start > C:\DFIR\netStart.txt;
tasklist > C:\DFIR\tasklist.txt;
tasklist /svc > C:\DFIR\tasklistSVC.txt;
wmic service list config > C:\DFIR\servicesConfig.txt;
Write-Host "Service Data gathered!";
### Peripherals ###
wmic path Win32_PnPdevice > C:\DFIR\OSinfo.txt;
Write-Host "Peripherals Data gathered!";
### Patches ###
wmic qfe list > C:\DFIR\qfeList.txt;
wmic computersystem get manufacturer > C:\DFIR\deviceManufacturer.txt;
cipher /y > C:\DFIR\cypheredEFS.txt;
Write-Host "Patches Data gathered!";
### Windows Event Logs ###
Copy-Item -Path "C:\Windows\System32\winevt\Logs" -Destination "C:\DFIR\WinevtLogs" -Recurse;
Write-Host "Windows Event Logs gathered!";
### Windows Firewall ###
netsh firewall show portopening > C:\DFIR\windowsFirewall_portopening.txt;
netsh firewall show allowedprogram > C:\DFIR\windowsFirewall_allowedprogram.txt;
netsh firewall show config > C:\DFIR\windowsFirewall_config.txt;
Write-Host "Windows Firewall Data gathered!";
### Temporary Files ###
Copy-Item -Path $env:TEMP -Destination "C:\DFIR\userTMP" -Recurse;
Copy-Item -Path "C:\Windows\temp" -Destination "C:\DFIR\winTMP" -Recurse;
Write-Host "Temporary Files gathered!";
### Registry Export ###
reg export HKLM "C:\DFIR\HKLM.Reg" /y;
Write-Host "HKLM Registry gathered!";			
### Directory Listing and File Search ###	
Write-Host "Searching for password files...";			
wmic DATAFILE where "drive='C:' AND Name like '%password%'" GET Name,readable,size /VALUE > C:\DFIR\PasswordFiles.txt;	
Write-Host "Done!";						
### AV products listing ###
try
{
	wmic /namespace:\\root\securitycenter2 path antivirusproduct get * /value > C:\DFIR\AVproductsSecCenter.txt;
	Write-Host "Av data gathered!";
}
catch
{
	Write-Host "The target does not have SecurityCenter2 --> Probably it is a server, no antivirus data available!"
}	

#COMPRESSION SECTION	
Write-Host "Starting to compress payload... Hold on... (It can take several minutes, but it is worth!)";
Write-Host "REMINDER: The process will take more time if the destination host has an high amount of RAM";
$completed = $false;			
DO
{
	try{
		#Compress-Archive -Path C:\Enumeration.txt -Update -DestinationPath $_dataToExtract;	
		#Creates NetFramework 4.5 method to compress files larger than 2 GB
		Add-Type -AssemblyName System.IO.Compression.FileSystem; #NET FRAMEWORK Reference	
		[IO.Compression.ZipFile]::CreateFromDirectory("C:\DFIR",$_dataToExtract, [IO.Compression.CompressionLevel]::Optimal, $true, [Text.Encoding]::Default);
		
		$completed = $true;
		Write-Host "Payload Compessed, you can use -collect switch to retrieve data from " $env:computername " PATH --> " $_dataToExtract;
	}
	catch
	{
		$completed = $false;
		Write-Host "Payload Compession failed, I'll retry in 5 seconds";
		Write-Host $_;
		Start-Sleep -s 5;
	}
}while($completed -eq $false)