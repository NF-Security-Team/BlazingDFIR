@echo off
set CustomerFTPUsername=y.nicolas.fasolo
set CustomerFTPPassword=MVL3DwW78pELjc3L
set host=%COMPUTERNAME%

echo Phase 1 - Creating landing dirs...
if not exist "C:\DFIR\" mkdir C:\DFIR
echo Phase 2 - Checking if root file C:\%host%.zip exists
if not exist C:\%host%.zip (
echo Phase 3 - Checking if acquisition data exists...
if not exist %host%_vel_KAPE.zip (
		echo Phase 4 - Gathering Data and preparing environment...
		mkdir collection
		mkdir C:\NTDS
		mkdir C:\NTDS\Dump
		PowerShell.exe -ExecutionPolicy Bypass -File .\data-collector.ps1
		echo Phase 4.1 - Starting Velociraptor for data gathering...
		.\velociraptor-v0.6.3-windows-amd64 artifacts collect Windows.KapeFiles.Targets --args=_Boot --args=_LogFile --args=LogFiles --args=_T --args=_MFT --args=_J --args=Amcache --args=Prefetch --args=SRUM --args=WBEM --args=EventLogs --args=RegistryHives --args=LNKFilesAndJumpLists --args=RecentFileCache --args=ScheduledTasks --args=PowerShellConsole --args=RDPCache --args Device="C:" --output %host%_vel_KAPE.zip -v
		echo Phase 4.2 - Adding results to %host%_vel_KAPE.zip
		7za.exe a %host%_vel_KAPE.zip collection		
		timeout /t 10
		echo Phase 4.3 - Gathering NTDS Dumps...
		rmdir /s /q collection
		ntdsutil "activate instance ntds" "ifm" "create full C:\NTDS\Dump" quit quit
		echo Phase 4.4  - Adding results to %host%_vel_KAPE.zip
		7za.exe a C:\NTDS\NTDS.zip "C:\NTDS\Dump"
		7za.exe a C:\NTDS\NTDS.zip "C:\Windows\NTDS"
		7za.exe a %host%_vel_KAPE.zip C:\NTDS\NTDS.zip			
		echo Phase 4.5 - Cleaning Phase...
		RMDIR /S /Q C:\NTDS
		timeout 10
		
	) else (
		rem file exist, do nothing
	)
	echo Waiting 15 seconds before proceeding...
	timeout 15
	7za.exe x -o"C:\%host%_vel_KAPE" "%host%_vel_KAPE.zip" -y
	echo Phase 5 - Starting BlazingDFIR_Short... (it can take some time)
	PowerShell.exe -ep bypass -File .\BlazingDIFR_Short.ps1 -local > nul
	echo Waiting 10 seconds before proceeding with Velociraptor compression...
	timeout 10
	7za.exe a C:\%host%.zip C:\%host%_vel_KAPE
)
else 
(
	echo file exist, do nothing
)
echo Phase 6 - Uploading data to Yarix cloud! DO NOT CLOSE THIS WINDOW...
PowerShell.exe -ExecutionPolicy Bypass -File ".\WinSCP_Synch.ps1" %CustomerFTPUsername% %CustomerFTPPassword%