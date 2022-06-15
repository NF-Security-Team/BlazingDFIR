Set-PSDebug -Off
reg export HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run collection\registry.txt /y
reg export HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce collection\registry1.txt /y
echo "------------------------------------Date And Time----------------------------------------------" >> collection\result.txt
date >> collection\result.txt 
echo "------------------------------------Systeminfo----------------------------------------------" >> collection\result.txt
systeminfo >> collection\result.txt
echo "------------------------------------Task list-----------------------------------------------" >> collection\result.txt
tasklist /v >> collection\result.txt
echo "------------------------------------Users-----------------------------------------------" >> collection\result.txt
net user >> collection\result.txt
echo "------------------------------------Local Groups-----------------------------------------------" >> collection\result.txt
net localgroup >> collection\result.txt
echo "------------------------------------Administrators group-----------------------------------------------" >> collection\result.txt
net localgroup administrators >> collection\result.txt
echo "------------------------------------Ipconfig /all-----------------------------------------------" >> collection\result.txt
ipconfig /all >> collection\result.txt
echo "------------------------------------DNS Cahce-----------------------------------------------" >> collection\result.txt
ipconfig /displaydns >> collection\result.txt
echo "------------------------------------Network Connections-----------------------------------------------" >> collection\result.txt
netstat -naob >> collection\result.txt
netstat -nr >> collection\result.txt
netstat -vb >> collection\result.txt
echo "------------------------------------Arp Table-----------------------------------------------" >> collection\result.txt
arp -a >> collection\result.txt
echo "------------------------------------Routing Table-----------------------------------------------" >> collection\result.txt
route print >> collection\result.txt
echo "------------------------------------Net Share-----------------------------------------------" >> collection\result.txt
net share >> collection\result.txt
echo "------------------------------------Services-----------------------------------------------" >> collection\result.txt
Get-WmiObject win32_service | select Name, DisplayName, State, PathName >> collection\result.txt
echo "------------------------------------Process list-----------------------------------------------" >> collection\result.txt
Get-WmiObject win32_process | select Caption, CommandLine, CreatonDate, Description, ExecutablePath, Name, SessionId, ProcessName >> collection\result.txt
echo "------------------------------------Group User-----------------------------------------------" >> collection\result.txt
Get-WmiObject Win32_GroupUser  | select PartComponent, GroupComponent >> collection\result.txt
echo "------------------------------------Logged On User-----------------------------------------------" >> collection\result.txt
Get-WmiObject Win32_LoggedOnUser   | select Antecedent, Dependent >>collection\result.txt
echo "------------------------------------Logged On Session-----------------------------------------------" >> collection\result.txt
Get-WmiObject Win32_LogonSession | select AuthenticationPackage, LogonId, LogonType, StartTime >> collection\result.txt
echo "------------------------------------Start Up Command-----------------------------------------------" >> collection\result.txt
Get-WmiObject Win32_StartupCommand >>collection\result.txt