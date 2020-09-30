#!/usr/bin/ksh

# DESCRIPTION
# Incidence report data collection script
# This script collects various system data to produce an incidence report 
# and an archive of system files for the purpose of forensic incpection.
# The script should be run as root user, either directly by root user or via the su command.

# The full output archive can be fount at /tmp/IR-Report-xxxxxxx.tar with a md5 sum file.
# PLEASE edit MD5SUMDIRS variable to specify the list of directories to create MD5SUMs

VERSION="0.2.6.1"

#SET UMASK for rw-------
umask 0177

# FILE DEFS
FSUFFIX="$(/usr/bin/hostname)-$(/usr/bin/date +%Y%m%d-%H%m%S)"
OUTDIR="/tmp/IR-${FSUFFIX}"
ARCHDIR="${OUTDIR}/arch"
INFODIR="${OUTDIR}/info"
TARFILE="${ARCHDIR}/IR-datacollection-${FSUFFIX}.tar"
SUIDFLS="${ARCHDIR}/IR-suids-${FSUFFIX}.tar"
TARBALL="/tmp/IR-Report-${FSUFFIX}.tar"
TARHASH="/tmp/IR-Report-${FSUFFIX}.md5"
SECTION="OUTPUT"

# The list of directories to create MD5SUMS
MD5SUMDIRS="/sbin /usr/sbin"

/usr/bin/mkdir -p "$OUTDIR" "$ARCHDIR" "$INFODIR"

usage(){
    /usr/bin/echo "Incidence report data collection script $VERSION"
    /usr/bin/echo "Usage: $0 [-h] [-s]"
    /usr/bin/echo
    /usr/bin/echo "-s   suspicious mode, archive /root and /home"
    /usr/bin/echo "-h   print this help message"
    /usr/bin/echo 
}

# internal function for verbose logging
logme() {
    OUTFILE="${INFODIR}/${SECTION}-${FSUFFIX}.txt"
    /usr/bin/echo "$(/usr/bin/date "+%Y%m%d %H:%M:%S") ###### $1" | /usr/bin/tee -a $OUTFILE
    /usr/bin/echo " " >> $OUTFILE
}

log() {
    OUTFILE="${INFODIR}/${SECTION}-${FSUFFIX}.txt"
    /usr/bin/echo "$(/usr/bin/date "+%Y%m%d %H:%M:%S") ###### $1" | /usr/bin/tee -a "$OUTFILE"
    eval "/usr/bin/nice $1"  >> "$OUTFILE" 2>&1
    /usr/bin/echo " " >> $OUTFILE
}

# Common commands for USER INFO
common_user_info(){
    log "/usr/bin/who"
    log "/usr/bin/id"
    log "/usr/bin/sudo -l"
    log "/usr/bin/getent passwd"
}

# Common commands for NETWORK INFO
common_network_info(){
    log "/usr/sbin/ifconfig -a"
    log "/usr/bin/netstat -an"
    log "/usr/bin/netstat -nr"
}

# Common commands for HOST INFO
common_host_info(){
    log "/usr/bin/hostname"
    log "/usr/bin/date"
    log "/usr/bin/uname -a"
    log "/usr/bin/uptime"
    log "/usr/bin/vmstat"
    log "/usr/bin/dmesg"
}

# Common functions to find crontabs
common_cron_info(){
# Find crontabs for ALL users
for i in $(/usr/bin/getent passwd | /usr/bin/cut -d : -f 1);do log "/usr/bin/crontab -l $i";done
}

common_collect_files(){
    logme "Collecting system files"
    log "/usr/bin/tar cf $TARFILE /var/log /var/spool/cron /etc/passwd /etc/group /etc/sudoers /etc/inittab /etc/rc* /etc/cron* /etc/host* /etc/localtime"

    logme "Finding history and profile files"
    log "/usr/bin/find / \( -name '.*history' -o -name '.bashrc' -o -name '.*profile' \) -print|/usr/bin/xargs /usr/bin/tar rfv $TARFILE"

    logme "Creating an archive of SUID/SGID files"
    log "/usr/bin/find / -user root -perm -u+s -print | /usr/bin/xargs /usr/bin/tar cvf $SUIDFLS"
    log "/usr/bin/find / -user root -perm -g+s -print | /usr/bin/xargs /usr/bin/tar rvf $SUIDFLS"
}

collect_home(){
    logme "Collecting /root and /home"
    log "/usr/bin/tar rf $TARFILE --exclude='.ssh' /home /root /export/home"
}

collect_rhel() {
# OS: RHEL
    logme "RHEL OS data collection"

# Create an archive of system files
    common_collect_files
    log "/usr/bin/tar rf $TARFILE /etc/fstab /var/spool/at /proc/cpuinfo /proc/meminfo /proc/modules /etc/sysconfig/network-scripts"

# PROCESS INFO
    SECTION="PROCESS_INFO"
    logme "PROCESS INFO"
    log "/usr/bin/pstree -aAhglpSu"
    log "/usr/bin/ps afux"
    log "/usr/bin/top -n 1 -b"
    log "/usr/sbin/lsof"

# USER INFO
    SECTION="USER_INFO"
    logme "USER INFO"
    log "/usr/bin/last -dFwx"
    common_user_info

# NETWORK INFO
    SECTION="NETWORK_INFO"
    logme "NETWORK INFO"
    common_network_info
    log "/usr/sbin/lsof -i"
    log "/usr/sbin/iptables -S"

# HOST INFO    
    SECTION="HOST_INFO"
    logme "HOST INFO"
    common_host_info
    # LINUX SPECIFIC
    log "/usr/sbin/lsmod"
    log "/usr/bin/cat /etc/redhat-release"
    log "/usr/sbin/sestatus -v"
    log "/usr/bin/cat /proc/meminfo"
    log "/usr/bin/cat /proc/cpuinfo"

# AUTOMATED JOBS
    SECTION="JOB_INFO"
    logme "AUTOMATED JOBS"
    for i in $(/usr/bin/getent passwd | /usr/bin/cut -d : -f 1);do log "/usr/bin/crontab -l -u $i";done

    # list all at jobs
    log "/usr/bin/sudo /usr/bin/atq"

# print all at jobs
for i in $(/usr/bin/sudo /usr/bin/atq|/usr/bin/awk '{print $1}');do
 log "/usr/bin/sudo /usr/bin/at -c $i"
done

# DISK INFO
    SECTION="DISK_INFO"
    logme "DISK INFO"
    log "/usr/sbin/fdisk -l"
    log "/usr/bin/df -h"
    log "/usr/bin/du  -ch -d 1 /"
    log "/usr/bin/mount -l"

# SOFTWARE INFO
    SECTION="SOFTWARE_INFO"
    logme "SOFTWARE INFO"
    log "/usr/bin/yum list all"
    log "/usr/bin/yum history list"
    log "/usr/bin/rpm -Va"

# MD5 sum of $MD5SUMDIRS
    SECTION="MD5SUM"
    log "/usr/bin/find $MD5SUMDIRS -type f -exec /usr/bin/md5sum {} \;"

} # end of collect_rhel

collect_sol() {
# OS: SOLARIS
logme "SOLARIS OS data collection"
PATH="$PATH:/usr/bin:/usr/sbin"

# Create an archive of system files
    common_collect_files
    log "/usr/bin/tar rf $TARFILE /etc/ipf/ipf.conf"

# PROCESS INFO
    SECTION="PROCESS_INFO"
    logme "PROCESS INFO"
    log "/usr/bin/ps -ef"
    # SOLARIS SPECIFIC
    log "/usr/bin/ptree"
    log "/usr/bin/top -b"

# USER INFO
    SECTION="USER_INFO"
    logme "USER INFO"
    log "/usr/bin/last"
    common_user_info

# NETWORK INFO
    SECTION="NETWORK_INFO"
    logme "NETWORK INFO"
    common_network_info

    # SOLARIS SPECIFIC
    log "/usr/bin/pfiles /proc/*" # lsof equiv

# HOST INFO
    SECTION="HOST_INFO"
    logme "HOST INFO"
    common_host_info

    # SOLARIS SPESIFIC
    logme "Processor Info"
    log "/usr/sbin/psrinfo -v" # Processor info
    logme "Describe instruction set architectures"
    log "/usr/bin/isainfo -nv"
    logme "The numeric identifier of the current host"
    log "/usr/bin/hostid"
    log "/usr/sbin/prtconf" # Memory information

# AUTOMATED JOBS
    SECTION="JOB_INFO"
    logme "AUTOMATED JOBS"
    common_cron_info

    # list all at jobs
    log "/usr/bin/atq"
    log "/usr/bin/at -l"

# DISK INFO
    SECTION="DISK_INFO"
    logme "DISK INFO"
    log "/usr/bin/df -h"
    log "/usr/bin/du  -sh -d /"
    log "/usr/sbin/mount"

    # SOLARIS SPECIFIC
    log "/usr/bin/echo|/usr/sbin/format" # fdisk -l equivalent

# SOFTWARE INFO
    SECTION="SOFTWARE_INFO"
    logme "SOFTWARE INFO"

    # SOLARIS SPECIFIC
    log "/usr/bin/pkg list"

# MD5 sum of $MD5SUMDIRS
    SECTION="MD5SUM"
    log "/usr/bin/find $MD5SUMDIRS -type f -exec /usr/bin/digest -a md5 -v {} \;"

} # end of collect_sol

collect_aix() {
# OS: AIX
logme "IBM AIX data collection"
PATH="$PATH:/usr/bin:/usr/sbin"

# Create an archive of system files
    common_collect_files
    log "/usr/bin/tar rf $TARFILE /var/adm/ras /var/adm/cronlog"

# PROCESS INFO
    SECTION="PROCESS_INFO"
    logme "PROCESS INFO"
    log "/usr/bin/ps -ef"
    log "/usr/sbin/lsof"
    # FIND top --batch equiv

# USER INFO
    SECTION="USER_INFO"
    logme "USER INFO"
    log "/usr/bin/last"
    common_user_info

# NETWORK INFO
    SECTION="NETWORK_INFO"
    logme "NETWORK INFO"
    common_network_info
    log "/usr/sbin/lsof -i"

    # AIX SPECIFIC
    logme "TODO check lsfilt result"
    log "lsfilt"

# HOST INFO
    SECTION="HOST_INFO"
    logme "HOST INFO"
    common_host_info

    # AIX SPECIFIC
    log "oslevel"
    logme "Processor Info"
    log "/usr/sbin/prtconf | /usr/bin/grep -i 'Processor Type'"
    logme "Describe instruction set architectures"
    log "getconf KERNEL_BITMODE"
    log "getconf HARDWARE_BITMODE"
    log "/usr/sbin/prtconf -k"
    logme "The numeric identifier of the current host"
    log "/usr/bin/uname -m"
    log "/usr/sbin/prtconf -m" # Memory information

# AUTOMATED JOBS
    SECTION="JOB_INFO"
    logme "AUTOMATED JOBS"
    common_cron_info

    # AIX SPECIFIC
    logme "TODO check cronadm output for cron and at jobs"
    log "cronadm cron  -l"
    log "cronadm at -l"

# DISK INFO
    SECTION="DISK_INFO"
    logme "DISK INFO"
    log "/usr/bin/df -h"
    log "/usr/bin/du  -sh -d /"
    log "mount"

    # AIX SPECIFIC
    logme "TODO check LVM information here"
    log "lsvg"
    log "lslv"
    log "lquerypv"
    log "lquerylv"
    log "lsdev -Cc disk"

# SOFTWARE INFO
    SECTION="SOFTWARE_INFO"
    # AIX SPECIFIC
    logme "SOFTWARE INFO"
    log "lslpp -h all"
    log "lslpp -L all"
    log "/usr/bin/rpm -qav"
    log "/usr/bin/rpm -Va"

# MD5 sum of $MD5SUMDIRS
    SECTION="MD5SUM"
    log "/usr/bin/find $MD5SUMDIRS -type f -exec csum -h MD5 {} \;"

} # end of collect_aix

collect_hpux() {
# OS: HP-UX
logme "HP-UX data collection"
PATH="$PATH:/usr/bin:/usr/sbin"

# Create an archive of system files
    common_collect_files
    log "/usr/bin/tar rf $TARFILE /var/adm/syslog /var/adm/cron /var/sam/log"

# PROCESS INFO
    SECTION="PROCESS_INFO"
    logme "PROCESS INFO"
    log "/usr/bin/ps -ef"
    log "/usr/bin/top -d 1"

# USER INFO
    SECTION="USER_INFO"
    logme "USER INFO"
    log "/usr/bin/last"
    common_user_info

# NETWORK INFO
    SECTION="NETWORK_INFO"
    logme "NETWORK INFO"
    common_network_info
    log "/usr/sbin/lsof -i"

    # HPUX SPECIFIC
    logme "TODO check ipf result for"
    log "ipf -V"
    log "ipfstat -i"
    log "ipfstat -i -6"
    log "ipfstat -o"
    log "ipfstat -o -6"
    logme "TODO check lanscan output"
    log "lanscan"

# HOST INFO
    SECTION="HOST_INFO"
    logme "HOST INFO"
    common_host_info

    # HPUX SPECIFIC
    logme "TODO check print_manifest output"
    log "print_manifest"
    log "/opt/ignite/bin/print_manifest"
    logme "TODO check machinfo output"
    log "machinfo"
    logme "The numeric identifier of the current host"
    log "/usr/bin/uname -i"
    logme "TODO check swapinfo output for memory info"
    log "swapinfo -m"
    log "/usr/bin/dmesg |/usr/bin/grep -I physical"
    logme "TODO check kernel module info"
    log "kmadmin -s"

# AUTOMATED JOBS
    SECTION="JOB_INFO"
    logme "AUTOMATED JOBS"
    common_cron_info

    # list all at jobs
    log "/usr/bin/atq"
    log "/usr/bin/at -l"

# DISK INFO
    SECTION="DISK_INFO"
    logme "DISK INFO"
    log "/usr/bin/df -h"
    log "/usr/bin/du  -sh -d /"
    log "mount"

    # HPUX SPECIFIC
    logme "TODO check LVM info"
    log "strings /etc/lvmtab"
    log "pvdisplay -v"
    logme "TODO check ioscan result for disk info"
    log "ioscan -funC disk"
    log "diskinfo"

# SOFTWARE INFO
    SECTION="SOFTWARE_INFO"
    logme "SOFTWARE INFO"

    # HPUX SPECIFIC
    logme "TODO check swlist output"
    log "swlist -l product PH*" # HPUX 10.x
    log "swlist -l patch" # HPUX 11

# MD5 sum of $MD5SUMDIRS
    SECTION="MD5SUM"
    log "/usr/bin/find $MD5SUMDIRS -type f -exec /usr/bin/md5sum {} \;"

} # end of collect_hpux

# OS detection by uname -a
detect_os() {
    logme "Detecting OS Version"
    case "$(uname -a)" in
     Linux*)   logme "LINUX detected, assuming RHEL"
               OSTYPE_="linux"
               collect_rhel;;
     AIX*)     logme "AIX detected"
               OSTYPE_="aix"
               collect_aix;;
     SunOS*)   logme "SOLARIS detected"
               OSTYPE_="solaris"
               collect_sol;;
     HP-UX*)    logme "HP-UX detected"
               OSTYPE_="hpux"
               collect_hpux;;
     *)        logme "Unknown OS detected: $(uname -a)"
               /usr/bin/echo "UNKNOWN OS $(uname -a)";;
    esac
}

md5sum_tarball(){
 case $OSTYPE_ in
  linux|hpux)	/usr/bin/md5sum $TARBALL > $TARHASH;;
  solaris)	/usr/bin/digest -a md5 -v $TARBALL > $TARHASH;;
  aix)		csum -h MD5 $TARBALL > $TARHASH;;
 esac
}


info_banner(){
  /usr/bin/more << EOF_INFO

The script execution has finished. You can find the produced files in the following tar archive:

    $TARBALL
    $TARHASH

EOF_INFO
}

gdpr_banner(){
  /usr/bin/more << EOF_GDPR

###########################################
  THE GDPR TERMS AGREEMENT TEXT GOES HERE
###########################################

EOF_GDPR
  /usr/bin/echo "Do you agree with the GDPR terms? (yes/no)"
  read GDPR_ANSWER
}

prepare_files(){
     logme "Compressing $TARFILE"
     log "/usr/bin/gzip -9 $TARFILE"
     logme "Creating $TARBALL"
     log "/usr/bin/tar cvf $TARBALL $OUTDIR"
     rm -rf "$OUTDIR"
     md5sum_tarball
     info_banner
}

### Main function ###
gdpr_banner
case "$GDPR_ANSWER" in
 yes) if [ $(/usr/bin/whoami) != "root" ];then
      /usr/bin/echo "You must be root to run the script!"
    else
     if [ $# -eq 0 ];then
     logme "Incidence Report Data Collection Script Version $VERSION"
     detect_os
     SECTION="OUTPUT"
     prepare_files
    else
     case "$1" in
        -s)
            logme "Incidence Report Data Collection Script Version $VERSION"
            detect_os
            SECTION="OUTPUT"
            collect_home
            prepare_files
            ;;
        *)
            usage
            ;;
     esac
      fi
    fi;;
 *) echo "You must agree with the GDPR terms to continue";;
esac
