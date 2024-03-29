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
param(		
		[string]$remotetool, #Copy the ".\tool" directory to the remote machine and execute the file you specify
		[switch]$list, #(Expects ./EndpointList.txt List) Start DFIR operations in every endpoint		
		[switch]$target, #Target one Endpoint for DFIR operations
		[switch]$local, #Execute DFIR operations in the lcal Endpoint
		[switch]$cshare, #using "-cshare" creates the share that will be used during DFIR
		[switch]$getedp, #using "-getedp" set the script in "Get Endpoints" mode
		[switch]$collect, #using "-collect" set the script in "Collector Mode"
		[switch]$autotarget, # Target one Endpoint for automatic DFIR & Collect operations
		[switch]$autolist #Expects ./EndpointList.txt List to retrieve targets for automatic DFIR & Collect operations
	 ) 

###### DFIR FUNCTIONS ######
# This section contains the functions used inside main routines

function BaseShareCreate {
	
	#Test Directories
	$_pathsExists = Test-Path  $_localPath;

	#Create Directories if $_pathsExists returns $false
	if($_pathsExists -eq $false)
	{
		New-Item -ItemType Directory -Force -Path $_localPath;	
		#Share Base Directory and set IR USER full control
		$UserId = "Everyone"; #$_domain +"\" + $_username
		New-SmbShare -Path $_localPath -Name IR_Data -FullAccess $UserId;
		$Acl = Get-Acl $_localPath;
		$NewAccessRule = New-Object system.security.accesscontrol.filesystemaccessrule("Everyone","FullControl","Allow");
		$Acl.SetAccessRule($NewAccessRule);
		Set-Acl $_localPath $Acl;
		Write-Host "Local Share " $_localPath  " has been created and shared correctly!";
	}
	else
	{
		Write-Host "Local Share " $_localPath  " already exists!";
	}
}

function DeploynExec {
			param(
				#Filename with extension "tool.exe" / "tool.bat"
				[string]$_toolFullNameWithExt
			)
			$_toolFullPath = -join(".\tools\", $_toolFullNameWithExt);
			$_toolExists = Test-Path $_toolFullPath;
			if($_toolExists -eq $true)
			{
				#Remote PSSession Establishment
				$RemoteSession = New-PSSession -Computername $_remoteEdp -Credential $_secureCreds;			
				#Tools Copying
				Copy-Item -ToSession $RemoteSession -Recurse -Path ".\tools" -Destination "C:\";
				#Deletes Remote Directories & Files
				Invoke-Command -Session $RemoteSession -ArgumentList $_toolFullNameWithExt -Scriptblock {
				param($_toolFullNameWithExt);
				$_DFIRPathExists = Test-Path  "C:\DFIR";
				if($_DFIRPathExists -eq $false)
				{
					New-Item -ItemType Directory -Force -Path "C:\DFIR";
				}
				$_toolPath = -join("C:\tools\", $_toolFullNameWithExt);
					#ToolExec		
					if($_toolPath -Match ".exe")
					{
						Start-Process -NoNewWindow -WindowStyle Hidden -FilePath $_toolPath;
					}
					elseif
					($_toolPath -Match ".bat")
					{
						cmd.exe /c $_toolPath
					}
				};
			
				#Disconnect & Rmeove Sessions
				Get-PSSession | Disconnect-PSSession;
				Get-PSSession | Remove-PSSession;
			}
			else
			{
				Write-Host "Cannot find tool in " $_toolFullPath;
			}
}


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
			BaseShareCreate;
			#Tools Copying
			Copy-Item -ToSession $RemoteSession -Recurse -Path ".\tools" -Destination "C:\";
						
			Invoke-Command -Session $RemoteSession -ArgumentList $_dataToExtract -Scriptblock {	
			param($_dataToExtract); # Param to pass local script var into invoke-command
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

function GetEndpoints {
	param (
				$_endpointName
			)
				$_remoteEdp = $_endpointName;
				$_dataToExtract = -join("C:\", $_remoteEdp, ".zip");
				$RemoteSession = New-PSSession -Computername $_remoteEdp -Credential $_secureCreds;
				Invoke-Command -Session $RemoteSession -ArgumentList $_dataToExtract -Scriptblock {
				param($_dataToExtract);				
				$_DFIRPathExists = Test-Path  "C:\DFIR";
				
				if($_DFIRPathExists -eq $false)
				{
					New-Item -ItemType Directory -Force -Path "C:\DFIR";
				}
				if($LastLogonLessThanDaysAgo -gt 0)
				{
					$today = Get-Date
					$cutoffdate = $today.AddDays(0 - $LastLogonLessThanDaysAgo)
					$targets = Get-ADComputer -Filter {(LastLogonDate -gt $cutoffdate)} -Properties Name #-SearchBase $ActiveDirectorySearchBase
				}
				else
				{
					$targets = Get-ADComputer -Filter {(LastLogonDate -gt 0)} -Properties Name #-SearchBase $ActiveDirectorySearchBase
				}

				$real_targets = New-Object System.Collections.ArrayList

				foreach ($tgt in $targets)
				{
					if ($tgt.Name -match $HostnameRegex){
						[void]$real_targets.Add($tgt.Name)
					}
				}

				if($Randomize){ $real_targets = $real_targets | Sort-Object {Get-Random} }

				if($outfile)
				{
					$real_targets | out-file "$PSScriptRoot\$outfile" 
					Write-Host "$($real_targets.Count) Targets found"
					Write-Host "List saved to: $PSScriptRoot\$outfile"
					Write-Host "All Done!"
				}else
				{
					Write-Host "$($real_targets.Count) Targets found"
					$real_targets | out-file "C:\DFIR\EndpointList.txt";
					Write-Host $real_targets
				}		
				
				#Creates NetFramework 4.5 method to compress files larger than 2 GB
				Add-Type -AssemblyName System.IO.Compression.FileSystem; #NET FRAMEWORK Reference					
				[IO.Compression.ZipFile]::CreateFromDirectory("C:\DFIR",$_dataToExtract, [IO.Compression.CompressionLevel]::Optimal, $true, [Text.Encoding]::Default);				
				
			};
			
			#EndpointList.txt LocalCopy
			Copy-Item -FromSession $RemoteSession -Path "C:\DFIR\EndpointList.txt" -Destination ".\EndpointList.txt";
			Write-Host "The .\EndpointList.txt file has been imported successfully";
			Start-Process ".\EndpointList.txt";
		#Disconnect & Rmeove Sessions
		Get-PSSession | Disconnect-PSSession;
		Get-PSSession | Remove-PSSession;
		
		
}

function CollectData {
	param (
				$_endpointName
			)
	$_remoteEdp = $_endpointName;
			#Collection ZIP File
			Write-Host "ATTENTION: This process can take several minutes based on remote file size... Be patient please :) ";
			$_dataToExtract = -join("C:\", $_remoteEdp, ".zip");
			$_localEdpPath = -join($_localPath, $_remoteEdp, ".zip"); #Path Variable
			$_localPathsExists = Test-Path  $_localEdpPath;
			BaseShareCreate;	
			#Remote PSSession Establishment
			# wmic /node:$servername process call create "winrm quickconfig" -Credential $_secureCreds
			# wmic /node:$servername share list brief -Credential $_secureCreds
			$RemoteSession = New-PSSession -Computername $_remoteEdp -Credential $_secureCreds;
			#$_dfirSharePath = -join("\\", $_serverIp, "\IR_Data\"); #PATH per RemoteDir	
					
			$_remoteZipExists = Invoke-Command -Session $RemoteSession -ArgumentList $_dataToExtract -Scriptblock {
			param($_dataToExtract);
			 Return Test-Path  $_dataToExtract;
			}
			if($_remoteZipExists -eq $true)
			{
				#Result Retrieve		
				Copy-Item -FromSession $RemoteSession -Path $_dataToExtract -Destination $_localEdpPath;
				Write-Host "DFIR data has been saved successfully! You can find it in " $_localEdpPath;
			}
			else
			{
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
				#Result Retrieve		
				Copy-Item -FromSession $RemoteSession -Path $_dataToExtract -Destination $_localEdpPath;
				Write-Host "DFIR data has been saved successfully! You can find it in " $_localEdpPath;
			}
			#Deletes Remote Directories & Files
			Invoke-Command -Session $RemoteSession -ArgumentList $_dataToExtract -Scriptblock {
			param($_dataToExtract);
				try{
					Remove-Item -Recurse -Confirm:$false -Force  "C:\tools\"; #Delete ToolsDir
					Remove-Item -Confirm:$false -Force $_dataToExtract; #Delete Zipped Data
					Remove-Item -Recurse -Confirm:$false -Force "C:\DFIR\"; #Delete Directory
					Write-Host "All remote DFIR tools and DIRS were removed successfully!"
				}catch
				{
					Write-Host "Data deletion unsuccessful! Try using -target swtich to start DFIR operations!"
				}
			
			};
		
			#Disconnect & Rmeove Sessions
			Get-PSSession | Disconnect-PSSession;
			Get-PSSession | Remove-PSSession;
			#Open Direcotry In Explorer
			Invoke-Item $_localEdpPath;
}

##############################
if (($collect -eq $false) -and
	($list -eq $false) -and
	($target -eq $false) -and
	($cshare -eq $false) -and
	($getedp -eq $false) -and
	($collect -eq $false) -and
	($autotarget -eq $false) -and
	($autolist -eq $false) -and
	($local -eq $false) -and
	($remotetool.Length -lt 3)
	)
{
	$Modules = @"

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


-cshare | - Creates the share C:\IR_DATA that will be used during DFIR operations
-local | - Target local Endpoint for DFIR operations
-getedp | - Gets Endpoint list (it will ask for Domain Controller Name) and generates .\EndpointList.txt
-target | - Target one Endpoint for DFIR operations
-collect | - Collects the DFIR directory in a specified remote host
-list | - It targets for DFIR operations all endpoints inside the ./EndpointList.txt (Use -list -collect to retrieve data) 
-remotetool "remotetool.exe/bat" | - Copy the .\tool directory to the remote machine and execute the file you specify [EXE or BAT]
-autotarget | - Expects ./EndpointList.txt Target one Endpoint for automatic DFIR & Collect operations
-autolist | - Expects ./EndpointList.txt List to retrieve targets for automatic DFIR & Collect operations


"@;

Clear-Host;
Write-Host $Modules;
Exit;
}
#Local EndpointData (Pref Domain Controller)
$ipV4 = Test-Connection -ComputerName (hostname) -Count 1  | Select -ExpandProperty IPV4Address;
$_serverIp =  $ipV4.IPAddressToString; #IP local endpoint
$_serverName = $env:computername; #FQDN local endpoint
#DFIR Share (Locally created)
$_localPath = "C:\IR_Data\";
if($local -ne $true)
{
	#Auth Data
	$_username = Read-Host -Prompt 'Input the Incident Response Domain Admin Username'; #USERNAME
	$_securePassword = Read-Host -Prompt 'Input the Incident Response Domain Admin Password' -AsSecureString; #PASSWORD
	$_domain = Read-Host -Prompt 'Input Domain'; #"DOMAINNAME"
	$_secureCreds = New-Object System.Management.Automation.PSCredential($_username, $_securePassword );
}


if($local -eq $true)
{	
			#####CSHARE CREATION###
			#Test Directories
			$_pathsExists = Test-Path  $_localPath;

			#Create Directories if $_pathsExists returns $false
			if($_pathsExists -eq $false)
			{
				New-Item -ItemType Directory -Force -Path $_localPath;	
				#Share Base Directory and set IR USER full control
				$UserId = "Everyone"; #$_domain +"\" + $_username
				New-SmbShare -Path $_localPath -Name IR_Data -FullAccess $UserId;
				$Acl = Get-Acl $_localPath;
				$NewAccessRule = New-Object system.security.accesscontrol.filesystemaccessrule("Everyone","FullControl","Allow");
				$Acl.SetAccessRule($NewAccessRule);
				Set-Acl $_localPath $Acl;
				Write-Host "Local Share " $_localPath  " has been created and shared correctly!";
			}
			else
			{
				Write-Host "Local Share " $_localPath  " already exists!";
			}
			#####CSHARE CREATION ends###
			
			Write-Host "In the process you will see some errors (usually in red) don't worry it depends on the remote system type and configurations.";
			#Collection ZIP File
			$_remoteEdp = $env:computername;
			$_dataToExtract = -join("C:\", $_remoteEdp, ".zip");
			$_localEdpPath = -join($_localPath, $_remoteEdp); #Path Variable
			#$_dfirSharePath = -join("\\", $_serverIp, "\IR_Data\"); #PATH per RemoteDir	
			$_localPathsExists = Test-Path  $_localEdpPath;
			
			
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
			Start-Process -NoNewWindow -WindowStyle Hidden -FilePath ".\tools\winpmem_mini_x64_rc2.exe" -ArgumentList ("C:\DFIR\" + $env:computername + ".raw");
			
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
			arp -a > C:\DFIR\Arp.txt;
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
}
if($cshare -eq $true)
{
	#Test Directories
	$_pathsExists = Test-Path  $_localPath;

	#Create Directories if $_pathsExists returns $false
	if($_pathsExists -eq $false)
	{
		New-Item -ItemType Directory -Force -Path $_localPath;	
		#Share Base Directory and set IR USER full control
		$UserId = "Everyone"; #$_domain +"\" + $_username
		New-SmbShare -Path $_localPath -Name IR_Data -FullAccess $UserId;
		$Acl = Get-Acl $_localPath;
		$NewAccessRule = New-Object system.security.accesscontrol.filesystemaccessrule("Everyone","FullControl","Allow");
		$Acl.SetAccessRule($NewAccessRule);
		Set-Acl $_localPath $Acl;
		Write-Host "Local Share " $_localPath  " has been created and shared correctly!";
	}
	else
	{
		Write-Host "Local Share " $_localPath  " already exists!";
	}
}
if(($remotetool -Match ".exe") -Or ($remotetool -Match ".bat"))
{
	#Asks for Host name
	$_remoteEdp = Read-Host -Prompt 'Input your taget Endpoint name';
	DeploynExec($remotetool);
}
if($autotarget -eq $true)
{
	#Asks for Host name
	$_remoteEdp = Read-Host -Prompt 'Input your taget Endpoint name';
	DIFRHost $_remoteEdp;
	Write-Host "I'm waiting 10 second before proceeding with data collection";
	Start-Sleep -s 10;
	CollectData $_remoteEdp;
}

if($autolist -eq $true)
{
	Write-Host "TODO - Remote DFIR into list foreach endpoint";
	$_EdpList = ".\EndpointList.txt";
	$_listExists = Test-Path $_EdpList;
	Write-Host $_EdpList;
	if($_listExists -eq $true)
	{
		foreach($line in [System.IO.File]::ReadLines($_EdpList))
		{				
			DIFRHost $line;
			Write-Host "I'm waiting 10 second before proceeding with data collection";
			Start-Sleep -s 10;
			CollectData $line;
		}		
	}
	else
	{
		Write-Host ".\EndpointList.txt does not exists! Run tool with the -getedp argument";
	}
}

if($getedp -eq $true)
{
	Write-Host "Retrieving Targets, please be patient..."
	#Asks for Domain Controller Host name
	$_remoteEdp = Read-Host -Prompt 'Input your Domain Controller name';
	GetEndpoints $_remoteEdp;
	
}
#Single Host script Execution
if($target -eq $true)
{
	#Asks for Host name
	$_remoteEdp = Read-Host -Prompt 'Input your taget Endpoint name';
	#Test Directories
	$_pathsExists = Test-Path  $_localPath;

	#Create Directories if $_pathsExists returns $false
	if($_pathsExists -eq $false)
	{
		New-Item -ItemType Directory -Force -Path $_localPath;	
		#Share Base Directory and set IR USER full control
		$UserId = "Everyone"; #$_domain +"\" + $_username
		New-SmbShare -Path $_localPath -Name IR_Data -FullAccess $UserId;
		$Acl = Get-Acl $_localPath;
		$NewAccessRule = New-Object system.security.accesscontrol.filesystemaccessrule("Everyone","FullControl","Allow");
		$Acl.SetAccessRule($NewAccessRule);
		Set-Acl $_localPath $Acl;
		Write-Host "Local Share " $_localPath  " has been created and shared correctly!";
	}
	else
	{
		Write-Host "Local Share " $_localPath  " already exists!";
	}
	DIFRHost $_remoteEdp;
}
if(($collect -eq $true) -and ($list -eq $false))
{
	#Asks for Host name
	$_remoteEdp = Read-Host -Prompt 'Input your taget Endpoint name';
	CollectData $_remoteEdp;
}
if (($collect -eq $false) -and ($list -eq $true))
{
	Write-Host "TODO - Remote DFIR into list foreach endpoint";
	$_EdpList = ".\EndpointList.txt";
	$_listExists = Test-Path $_EdpList;
	Write-Host $_EdpList;
	if($_listExists -eq $true)
	{
		foreach($line in [System.IO.File]::ReadLines($_EdpList))
		{	
			Write-Host "Doing stuff in target " $line;
			DIFRHost $line;			
		}		
	}
	else
	{
		Write-Host ".\EndpointList.txt does not exists! Run tool with the -getedp argument";
	}
}
if (($list -eq $true) -and ($collect -eq $true))
{
	Write-Host "TODO - Remote Collect into list foreach endpoint";
	$_EdpList = ".\EndpointList.txt";
	$_listExists = Test-Path $_EdpList;
	if($_listExists -eq $true)
	{
		foreach($line in [System.IO.File]::ReadLines($_EdpList))
		{
		    CollectData $line;
		}		
	}
	else
	{
		Write-Host ".\EndpointList.txt does not exists! Run tool with the -getedp argument";
	}
}
