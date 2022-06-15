#!/bin/bash

#################################################################################
# Written by: Nicolas Fasolo 
# Name: BlazingDIFR.sh
# email: nicolas.fasolo@hotmail.it
#
#
#
#	Collects DIFR data from a specified host that the script will ask for
# ex: .\BlazingDIFR.sh -collect
#
#	Start DIFR process in a specified host that the script will ask for
# ex: .\BlazingDIFR.sh -target
#
#	Start DIFR process in a specified host list (Expects ./EndpointList.txt List)
# ex: .\BlazingDIFR.sh -list
#
#	Collects DIFR data from a specified host list
# ex: .\BlazingDIFR.sh -list -collect
#
#################################################################################
script -O ./BlazingDIFR.log -T -q #logs in the same directory all the output
echo "######## Script Start DATE ######## " && date #Logs the date 
echo "######## Install dc3dd Phase ######## "
apt install dc3dd --assume-yes
dc3dd if=/dev/mem of=./physical_mem_out_dc3dd
#apt install memdump
#memdump > ./physical_mem_out_memdump
echo "######## Get Memory Dumps ######## "
dc3dd if=/proc/kcore of=./kcore_mem_out
dc3dd if=/dev/fmem of=./physmem
echo "######## Get Lifecycle System State & Routing Infos ######## "
#Lifecycle System State
netstat -naovp
ifconfig
printenv
hostname
whoami
id
logname
uptime
uname -a
cat /proc/version
cat /proc/cpuinfo
cat /proc/cmdline #Kernel Boot
netstat -nr #Routing Table
arp -a #arp chache
who
w
users
lsof -l
ps -e
ps -ef
ps aux
top -n 1 -b
pstree -a
#pmap -d %PID%
ps -eafww
ps auxww
#whereis -b %FILE%
#which -a FILE
ps -u root
pgrep -U root
lsmod
cat /proc/modules
#modinfo MODULE_NAME #Take module name from lsmod
xclip -o
#pmap -x PID #proc mem map
chkconfig -list #RedHat
service --status-all #shows status
ls /etc/rc*.d #Solaris
smf #Solaris 10+
iptables -t nat -nL
iptables -t mangle -nL
iptables -t filter -nL
iptables -t raw -nL
raw; do iptables -t $type -nL; done
echo "######## Linux Artifact Investigation ######## "
# Linux Artifact Investigation
echo "######## Find account w/ null password ######## "
#Find account w/ null password
awk -F: '($2 == "") {print $1}' /etc/shadow
echo "######## Account creation order ######## "
#Account creation order
sort -nk3 -t: /etc/passwd | less
echo "######## Find Duplicate User IDs ######## "
#Find Duplicate User IDs
cut -f3 -d: /etc/passwd | sort -n | uniq -c | awk '!/ 1 / {print $2}'
echo "######## Find UID 0 (roots) --> Should be only one ######## "
#Find UID 0 (roots) --> Should be only one
awk -F: '($3 == 0) {print $1}' /etc/passwd egrep ':0+:' /etc/passwd
echo "######## Find orphan files (this command change file access time) ######## "
#Find orphan files (this command change file access time)
find / -nouser -print
echo "######## Shell Histories ######## "
#Shell Histories
.bash_history
.sh_history
.history

echo "######## OS Useful Artifacts ########"
#OS Artifacts
cat /proc/mounts
cat /etc/fstab
cat /etc/exports #NFS exported dir's
cat /etc/samba/smb.conf #Samba Exports

echo "######## Scheduled Stuff ########"
#Scheduled Jobs
at
ls -la /var/spool/cron/atjobs # cat each job
ls -la /var/spool/cron/atspool
cat /etc/crontab

echo "######## Cron Jobs ########"
#OtherCrons
ls /etc/cron.daily
ls /etc/cron.hourly
ls /etc/cron.weekly
ls /etc/cron.monthly

more /etc/crontab
ls /etc/cron.*
ls /var/at/jobs
cat /etc/anacrontab

echo "######## Cron Jobs User Rights ########"
#user permission for crons
cat /etc/cron.allow
cat /etc/cron.deny

echo "######## Cron Jobs User Rights ########"
#Trusted Hosts relationships
cat /etc/hosts.equiv
cat /etc/hosts.lpd
.rhosts
cat /etc/X0.hosts #X11 entire System

echo "######## SSH Keys, Auths ########"
#SSH connect without password
#Collect authorized_keys from each user
for homedir in $(awk -F':' '{print $6}' /etc/passwd); do
cp -rf "${homedir}/.ssh/authorized_keys" "./${homedir}_SSHAuthKeys"
done

echo "######## Syslogging Checks ########"
#Logging Checks
cat /etc/syslog.conf
cat /etc/syslog-ng/syslog-ng.conf

echo "######## Current user Last Logon Data & LastLog ########"
#Last Logon Data
last
lastlog
cp /var/log/*tmp* ./var_logs_tmp
cp -R /var/log*  ./var_logs

echo "######## FileList Date < 7 Days ########"
#find files newer than 7 days
find -newermt '7 day ago'

echo "######## FileList Date > 30 Days ########"
#find files older than 30 days
find . -type f -atime +30 -print

#List all files (no limits)
#find / -print | xargs ls -ld

echo "######## System INTEGRITY CHECK ########"
##### INTEGRITY CHECK #####
rpm -Va
pkgchk #Solaris
dpkg -l #Show Package status
debsums # Debian