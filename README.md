Incidence report data collection script README v2.0

This script collects various system data to produce an incidence report and an archive of system files
for the purpose of forensic inspection and currently supports Linux/IBM AIX/Sun Solaris and HP-UX . 

In order to prevent any unwanted system load it runs the commands via the log() function which uses 
the 'nice' command to execute commands with lower priority. 

For this purpose, all new commands should use log() function to call them.

Script should be run as root user, either directly by root user or via the su/sudo commands.

The directories for MD5SUM collection is listed inside MD5SUMDIRS variable. It should be modified 
inside the script according to the needs.

When run, it first creates a tar archive and then collects the information in the following order:

1. Process Information (ps, top, lsof etc)
2. User information (last, who, getent passwd etc)
3. Network information (netstat -an, ifconfig -a etc)
4. Host information (hostname, uname -a, uptime, dmesg etc)
5. Automated jobs (crontab -l, atq etc)
6. Disk Information (df -h, mount, fdisk etc)
7. Software Information (yum list, rpm -qa, swlist etc)

The script produces two files:

    /tmp/IR-Report-{HOSTNAME}-{YYYYMMDD}-{HHMMSS}.tar 
    /tmp/IR-Report-{HOSTNAME}-{YYYYMMDD}-{HHMMSS}.md5


The first contains all the files that is produced or collected by the script. 
The second file contains the md5 sum of the archive file.

The full details of commands and collected files for the presented data in the archive and the report file 
are presented below:

### COLLECTED FILES

    Tar archive includes this files & directories for all supported OS's

[ALL]
/var/log 
/var/spool/cron 
/etc/passwd 
/etc/group 
/etc/sudoers 
/etc/inittab 
/etc/rc* 
/etc/cron* 
/etc/host*
/etc/localtime
[any matches for following files in / fs]
.*history 
.bashrc
.*profile
[any root SUID/SGID files]

[RHEL]
/etc/fstab 
/var/spool/at 
/proc/cpuinfo 
/proc/meminfo 
/proc/modules
/etc/sysconfig/network-scripts

[SOLARIS]
/etc/ipf/ipf.conf

[AIX]
/var/adm/ras
/var/adm/cronlog

[HPUX]
/var/adm/syslog
/var/adm/cron
/var/sam/log


#### USER INFO

[ALL]
who
id
sudo -l
getent passwd

[RHEL]
last -dFwx

[SOLARIS|AIX|HPUX]
last

### Network info

[ALL]
ifconfig -a
netstat -an
netstat -rn

[RHEL]
lsof -i
iptables -S

[SOLARIS]
pfiles /proc/* #lsof equiv

[AIX]
lsof -i
lsfilt

[HPUX]
lsof -i
ipf -V # firewall rules
ipfstat -i
ipfstat -i -6
ipfstat -o
ipfstat -o -6

### HOST INFO

[ALL]
hostname
date
uname -a
uptime
vmstat
dmesg

[RHEL]
lsmod
cat /etc/redhat-release
sestatus -v
cat /proc/meminfo
cat /proc/cpuinfo

[SOLARIS]
psrinfo -v # Processor info
isainfo -nv
hostid
prtconf # Memory information

[AIX]
oslevel
prtconf | grep -i 'Processor Type'
getconf KERNEL_BITMODE
getconf HARDWARE_BITMODE
prtconf -k
uname -m
prtconf -m # Memory information

[HPUX]
print_manifest
/opt/ignite/bin/print_manifest
machinfo
uname -i
swapinfo -m
dmesg |grep -I physical
kmadmin -s # lsmod equiv

### CRON AND AT JOBS

[ALL]
for i in $(getent passwd | cut -d : -f 1);do log "crontab -l $i";done

[RHEL]
sudo atq

[SOLARIS|HPUX]
sudo atq
sudo at -l

[AIX]
cronadm cron  -l
cronadm at -l

#### DISK INFO

[ALL]
df -h
du -ch -d [1] /
mount [-l]

[RHEL]
fdisk -l

[SOLARIS]
echo|format # fdisk -l equivalent

[AIX]
lsvg
lslv
lquerypv
lquerylv
lsdev -Cc disk

[HPUX]
strings /etc/lvmtab
pvdisplay -v
ioscan -funC disk
diskinfo

### SOFTWARE INFO

[RHEL]
yum list all
yum history list
rpm -Va

[SOLARIS]
pkg list

[AIX]
lslpp -h all
lslpp -L all
rpm -qav
rpm -Va

[HPUX]
swlist -l product PH* # HPUX 10.x
swlist -l patch # HPUX 11

