#!/bin/bash

# PS4='+ $(date "+%s.%N")\011 '
# exec 3>&2 2>/tmp/bashstart.$$.log
# set -x

#Define all basic variables
DATE=$(date)
SECONDS=$(date -d "$DATE" +%s)
CONVERT=1048576

#Commands and Urls
#SSL_CHECK_URL="https://api.ssllabs.com/api/v3/analyze?host=$HOST_URL&publish=off&ignoreMismatch=on&all=done"

#Define necessary variables
export LC_ALL=C

#Define common functions
makeOrAddToGroup() {
    TITLE="$1"
    TYPE="$2"
    OBJECT="{ \"title\" : \"$TITLE\", \"type\" : \"$TYPE\", \"values\" : [$3] }"
    if [ "$4" != "" ]
    then
        echo "$4,$OBJECT"
    else
        echo "$OBJECT"
    fi
}

makeOrAddToValues() {
    TITLE="$1"
    TYPE="$2"
    THRESHOLD="$3"
    VALUE="$4"
    OBJECT="{ \"title\" : \"$TITLE\" , \"type\" : \"$TYPE\" , \"threshold\" : \"$THRESHOLD\" , \"value\" : \"$VALUE\" }"
    if [ "$5" != "" ]
    then
        echo "$5,$OBJECT"
    else
        echo "$OBJECT"
    fi
}

getCPUUsage() {
    top -b -n2 -p1 -d0.1 | grep "Cpu(s)" | tail -1 | awk -F ':' '{print $2}' | sed 's/[,%]/ /g' | awk '{print $7}' | awk '{printf "%0.1f", 100 - $1}'
}

getCPUName() {
    grep -i 'model name' /proc/cpuinfo | tr -d '\t' | tail -1 | sed 's/model name: //g'
}

getCPUCores() {
    nproc --all
}

getMEMUsage() {
    free | tail -n 2 | grep -i "mem" | awk '{printf "%0.1f", $3 / $2 * 100}'
}

getMEMUsed() {
    free | tail -n 2 | grep -i "mem" | awk -v v1=$CONVERT '{printf "%0.1f", $3 / v1}'
}

getMEMTotal() {
    free | tail -n 2 | grep -i "mem" | awk -v v1=$CONVERT '{printf "%0.1f", $2 / v1}'
}

getMEMFree() {
    free | tail -n 2 | grep -i "mem" | awk -v v1=$CONVERT '{printf "%0.1f", $4 / v1}'
}

getMEMFreeUsage() {
    free | tail -n 2 | grep -i "mem" | awk '{printf "%0.1f", $4 / $2 * 100}'
}

getMEMCache() {
    free | tail -n 2 | grep -i "mem" | awk -v v1=$CONVERT '{printf "%0.1f", $6 / v1}'
}

getMEMCacheUsage() {
    free | tail -n 2 | grep -i "mem" | awk '{printf "%0.1f", $6 / $2 * 100}'
}

getSwapUsage() {
    free | tail -n 2 | grep -i "swap" | awk '{printf "%0.1f", $3 / $2 * 100}'
}

getSwapUsed() {
    free | tail -n 2 | grep -i "swap" | awk -v v1=$CONVERT '{printf "%0.1f", $3 / v1}'
}

getSwapTotal() {
    free | tail -n 2 | grep -i "swap" | awk -v v1=$CONVERT '{printf "%0.1f", $2 / v1}'
}

getSwapFree() {
    free | tail -n 2 | grep -i "swap" | awk -v v1=$CONVERT '{printf "%0.1f", $4 / v1}'
}

getSwapFreeUsage() {
    free | tail -n 2 | grep -i "swap" | awk '{printf "%0.1f", $4 / $2 * 100}'
}

getSwapCache() {
    free | tail -n 2 | grep -i "swap" | awk -v v1=$CONVERT '{printf "%0.1f", $6 / v1}'
}

getSwapCacheUsage() {
    free | tail -n 2 | grep -i "swap" | awk '{printf "%0.1f", $6 / $2 * 100}'
}

getCPUProcesses() {
    top -b -n2 -d0.1 -o %CPU | awk '/^top/{i++}i==2' | tail -n +7 | awk '{print $1"|"$2"|"$9"|"$10"|"$12"|"$11}' | tr '\n' '#'
}

getMEMProcesses() {
    ps axo "%p|%U|%C|" o "pmem" o "|%c|" o "rss" --sort=-pmem | tr '\n' '#' | tr -d ' ' | sed -r 's/(.*)#/\1/'
}

getOSName() {
    cat /etc/*release | grep ^NAME= | awk -F '=' '{print $2}' | tr -d '"'
}

getOSVersion() {
    cat /etc/*release | grep ^VERSION= | awk -F '=' '{print $2}' | tr -d '"'
}

getOSArch() {
    uname -m
}

getKernelName() {
    uname -s
}

getKernelRelease() {
    uname -r
}

getKernelVersion() {
    uname -v
}

getServerTime() {
    date
}

getUpTime() {
    uptime -p
}

getUsers() {
    printf "USERNAME|UID|GID|FULL NAME|HOME#" && sort -g -t : -k 3 /etc/passwd | awk -F ':' '{print $1"|"$3"|"$4"|"$5"|"$6}' | tr '\n' '#'
}

getGrps() {
    printf "NAME|GID|USERS#" && sort -g -t : -k 3 /etc/group | awk -F ':' '{print $1"|"$3"|"$4}' | tr '\n' '#'
}

getLogins() {
    printf "USER|IP|LOGIN - LOGOUT|LENGTH#" && last -di | grep -v reboot | awk '{ printf $1"|"$3"|"; s = ""; for (i = 4; i <= NF; i++) s = s $i " "; print s }' | sed 's/ (/|/g' | tr -d ')' | sed '$d' | sed '$d' | tr '\n' '#'
}

getHostname() {
    hostname
}

getPublicIP() {
    curl --max-time 1 --connect-time 1 https://ipapi.co/ip
    # echo "test"
}

getPrivateIP() {
    hostname -I | awk '{print $1}'
}

getConnections() {
    NETSTAT=$(netstat >/dev/null 2>&1 | sed 1d; echo $?);
    SS=$(ss >/dev/null 2>&1 | sed 1d; echo $?);
    if [ "$NETSTAT" -eq 0 ]
    then
        CONNECTIONS=$(netstat -tun | awk '/EST/{print $4"|"$5}')
    elif [ "$SS" -eq 0 ]
    then
        CONNECTIONS=$(ss -tun | awk '/EST/{print $5"|"$6}')
    fi
    CONNECTION_HEADER=$(printf "PORT|IP|ORG|CITY|REGION|COUNTRY|POSTAL#")
    printf "%s" "$CONNECTION_HEADER"; echo "$CONNECTIONS" | grep -v "^127.\\|^:" | grep -Po ".*(?=:)" | tr '\n' '#'
    # echo "test"
}

# getDiskActivityUsage() {
#     top -b -n2 -d1 -o %CPU | awk -F ':' '{print $2}' | sed 's/[,%]/ /g' | awk '{print $9}'
# }

getRootDiskType() {
    df -PT / | tail -n 1 | awk '{print $2}'
}

getRootDiskTotal() {
    df -PT / | tail -n 1 | awk -v v1=$CONVERT '{printf "%0.1f", $3 / v1}'
}

getRootDiskUsed() {
    df -PT / | tail -n 1 | awk -v v1=$CONVERT '{printf "%0.1f", $4 / v1}'
}

getRootDiskUsage() {
    df -PT / | tail -n 1 | awk '{printf "%0.1f", $4 / $3 * 100}'
}

getRootDiskFree() {
    df -PT / | tail -n 1 | awk -v v1=$CONVERT '{printf "%0.1f", $5 / v1}'
}

getRootDiskFreeUsage() {
    df -PT / | tail -n 1 | awk '{printf "%0.1f", $5 / $3 * 100}'
}

getDiskPartitions() {
    df -hT | awk '{print $1"|"$2"|"$3"|"$4"|"$5"|"$6"|"$7}' | tr '\n' '#' | sed 's/\\/\//g'
}

if [ "$1" != "TEST" ] 
then
    while :
    do
        #Run dd command to get write info
        #DD=$(dd if=/dev/zero of=/tmp/output bs=8k count=10k 2>&1 | tail -n 1; rm -f /tmp/output;);

        exec 3< <(getCPUUsage)
        exec 4< <(getCPUName)
        exec 5< <(getCPUCores)
        exec 6< <(getMEMUsage)
        exec 7< <(getMEMUsed)
        exec 8< <(getMEMTotal)
        exec 9< <(getMEMFree)
        exec 10< <(getMEMFreeUsage)
        exec 11< <(getMEMCache)
        exec 12< <(getMEMCacheUsage)
        exec 13< <(getSwapUsage)
        exec 14< <(getSwapUsed)
        exec 15< <(getSwapTotal)
        exec 16< <(getSwapFree)
        exec 17< <(getSwapFreeUsage)
        exec 18< <(getCPUProcesses)
        exec 19< <(getMEMProcesses)
        exec 20< <(getOSName)
        exec 21< <(getOSVersion)
        exec 22< <(getOSArch)
        exec 23< <(getKernelName)
        exec 24< <(getKernelRelease)
        exec 25< <(getKernelVersion)
        exec 26< <(getServerTime)
        exec 27< <(getUpTime)
        exec 28< <(getUsers)
        exec 29< <(getGrps)
        exec 30< <(getLogins)
        exec 31< <(getHostname)
        exec 32< <(getPublicIP)
        exec 33< <(getPrivateIP)
        exec 34< <(getConnections)
        # exec 35< <(getDiskActivityUsage)
        exec 36< <(getRootDiskType)
        exec 37< <(getRootDiskTotal)
        exec 38< <(getRootDiskUsed)
        exec 39< <(getRootDiskUsage)
        exec 40< <(getRootDiskFree)
        exec 41< <(getRootDiskFreeUsage)
        exec 42< <(getDiskPartitions)

        read -ru 3 CPU_USAGE
        read -ru 4 CPU_NAME
        read -ru 5 CPU_CORES
        read -ru 6 MEM_USAGE
        read -ru 7 MEM_USED
        read -ru 8 MEM_TOTAL
        read -ru 9 MEM_FREE
        read -ru 10 MEM_FREE_USAGE
        read -ru 11 MEM_CACHE
        read -ru 12 MEM_CACHE_USAGE
        read -ru 13 SWAP_USAGE
        read -ru 14 SWAP_USED
        read -ru 15 SWAP_TOTAL
        read -ru 16 SWAP_FREE
        read -ru 17 SWAP_FREE_USAGE
        read -ru 18 CPU_PROCESSES
        read -ru 19 MEM_PROCESSES
        read -ru 20 OS_NAME
        read -ru 21 OS_VERSION
        read -ru 22 OS_ARCH
        read -ru 23 KERNEL_NAME
        read -ru 24 KERNEL_RELEASE
        read -ru 25 KERNEL_VERSION
        read -ru 26 SERVER_TIME
        read -ru 27 UP_TIME
        read -ru 28 USERS
        read -ru 29 GRPS
        read -ru 30 LOGINS
        read -ru 31 HOSTNAME
        read -ru 32 PUBLIC_IP
        read -ru 33 PRIVATE_IP
        read -ru 34 CONNECTIONS
        # read -ru 35 DISK_ACTIVITY_USAGE
        read -ru 36 ROOT_DISK_TYPE
        read -ru 37 ROOT_DISK_TOTAL
        read -ru 38 ROOT_DISK_USED
        read -ru 39 ROOT_DISK_USAGE
        read -ru 40 ROOT_DISK_FREE
        read -ru 41 ROOT_DISK_FREE_USAGE
        read -ru 42 DISK_PARTITIONS

        exec 3<&-
        exec 4<&-
        exec 5<&-
        exec 6<&-
        exec 7<&-
        exec 8<&-
        exec 9<&-
        exec 10<&-
        exec 11<&-
        exec 12<&-
        exec 13<&-
        exec 14<&-
        exec 15<&-
        exec 16<&-
        exec 17<&-
        exec 18<&-
        exec 19<&-
        exec 20<&-
        exec 21<&-
        exec 22<&-
        exec 23<&-
        exec 24<&-
        exec 25<&-
        exec 26<&-
        exec 27<&-
        exec 28<&-
        exec 29<&-
        exec 30<&-
        exec 31<&-
        exec 32<&-
        exec 33<&-
        exec 34<&-
        #exec 35<&-
        exec 36<&-
        exec 37<&-
        exec 38<&-
        exec 39<&-
        exec 40<&-
        exec 41<&-
        exec 42<&-

        ##Build json objects
        TAB=""
        GROUP=""

        #CPU
        DATA=""

        #CPU Used Chart
        TITLE="CPU Used"
        TYPE="chart"
        THRESHOLD="85"
        VALUE="$CPU_USAGE"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #CPU Name
        TITLE="Name"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$CPU_NAME"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #CPU Cores
        TITLE="Cores"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$CPU_CORES"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #CPU Usage
        TITLE="Usage"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$CPU_USAGE%"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #CPU Group
        TITLE="CPU"
        TYPE="chart"
        GROUP=$(makeOrAddToGroup "$TITLE" "$TYPE" "$DATA" "$GROUP")


        #Memory
        DATA=""

        #Memory Used Chart
        TITLE="Memory Used"
        TYPE="chart"
        THRESHOLD="70"
        VALUE="$MEM_USAGE"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Memory Total
        TITLE="Total"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$MEM_TOTAL GB"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Memory Used
        TITLE="Used"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$MEM_USED GB ($MEM_USAGE%)"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Memory Free
        TITLE="Free"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$MEM_FREE GB ($MEM_FREE_USAGE%)"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Memory Cache
        TITLE="Cache"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$MEM_CACHE GB ($MEM_CACHE_USAGE%)"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Memory Group
        TITLE="Memory"
        TYPE="chart"
        GROUP=$(makeOrAddToGroup "$TITLE" "$TYPE" "$DATA" "$GROUP")


        #Swap
        DATA=""

        #Swap Used Chart
        TITLE="Swap Used"
        TYPE="chart"
        THRESHOLD="70"
        VALUE="$SWAP_USAGE"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Swap Total
        TITLE="Total"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$SWAP_TOTAL GB"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Swap Used
        TITLE="Used"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$SWAP_USED GB ($SWAP_USAGE%)"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Swap Free
        TITLE="Free"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$SWAP_FREE GB ($SWAP_FREE_USAGE%)"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Swap Group
        TITLE="Swap"
        TYPE="chart"
        GROUP=$(makeOrAddToGroup "$TITLE" "$TYPE" "$DATA" "$GROUP")


        #CPU Processes
        DATA=""

        #CPU Process List
        TITLE="CPU Processes"
        TYPE="search"
        THRESHOLD=""
        VALUE="$CPU_PROCESSES"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #CPU Proccesses Group
        TITLE="CPU Proccesses"
        TYPE="search"
        GROUP=$(makeOrAddToGroup "$TITLE" "$TYPE" "$DATA" "$GROUP")


        #MEM Processes
        DATA=""

        #MEM Process List
        TITLE="MEM Processes"
        TYPE="search"
        THRESHOLD=""
        VALUE="$MEM_PROCESSES"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #MEM Proccesses Group
        TITLE="MEM Proccesses"
        TYPE="search"
        THRESHOLD=""
        GROUP=$(makeOrAddToGroup "$TITLE" "$TYPE" "$DATA" "$GROUP")

        #Status Tab
        TITLE="Status"
        TYPE="tab"
        TAB=$(makeOrAddToGroup "$TITLE" "$TYPE" "$GROUP" "$TAB")
        GROUP=""


        ##OS
        DATA=""

        #OS Name
        TITLE="Name"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$OS_NAME"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #OS Version
        TITLE="Version"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$OS_VERSION"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #OS Arch
        TITLE="Arch"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$OS_ARCH"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #OS Group
        TITLE="Operating System"
        TYPE="text"
        GROUP=$(makeOrAddToGroup "$TITLE" "$TYPE" "$DATA" "$GROUP")


        ##Kernel
        DATA=""

        #Kernel Name
        TITLE="Name"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$KERNEL_NAME"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Kernel Release
        TITLE="Release"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$KERNEL_RELEASE"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Kernel Version
        TITLE="Version"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$KERNEL_VERSION"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Kernel Group
        TITLE="Kernel"
        TYPE="text"
        GROUP=$(makeOrAddToGroup "$TITLE" "$TYPE" "$DATA" "$GROUP")


        ##Time
        DATA=""

        #Time Name
        TITLE="Server Time"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$SERVER_TIME"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Up Time
        TITLE="Uptime"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$UP_TIME"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Time Group
        TITLE="Time"
        TYPE="text"
        GROUP=$(makeOrAddToGroup "$TITLE" "$TYPE" "$DATA" "$GROUP")


        ##Users
        DATA=""

        #User List
        TITLE="Users"
        TYPE="search"
        THRESHOLD=""
        VALUE="$USERS"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Users Group
        TITLE="Users"
        TYPE="text"
        GROUP=$(makeOrAddToGroup "$TITLE" "$TYPE" "$DATA" "$GROUP")


        ##Groups
        DATA=""

        #Group List
        TITLE="Groups"
        TYPE="search"
        THRESHOLD=""
        VALUE="$GRPS"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Grps Group
        TITLE="Groups"
        TYPE="text"
        GROUP=$(makeOrAddToGroup "$TITLE" "$TYPE" "$DATA" "$GROUP")


        ##Logins
        DATA=""

        #Login List
        TITLE="Logins"
        TYPE="search"
        THRESHOLD=""
        VALUE="$LOGINS"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Logins Group
        TITLE="Logins"
        TYPE="text"
        GROUP=$(makeOrAddToGroup "$TITLE" "$TYPE" "$DATA" "$GROUP")

        #General Tab
        TITLE="General"
        TYPE="tab"
        TAB=$(makeOrAddToGroup "$TITLE" "$TYPE" "$GROUP" "$TAB")
        GROUP=""


        ##Computer
        DATA=""

        #Computer Name
        TITLE="Host Name"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$HOSTNAME"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Computer Public IP
        TITLE="Public IP"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$PUBLIC_IP"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Computer Private IP
        TITLE="Private IP"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$PRIVATE_IP"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Computer Location
        # TITLE="Location"
        # VALUE="$LOCATION"
        # TYPE="detail"
        # DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Computer Group
        TITLE="Computer"
        TYPE="text"
        GROUP=$(makeOrAddToGroup "$TITLE" "$TYPE" "$DATA" "$GROUP")


        ##Connection
        DATA=""

        #Connection IP List
        TITLE="IP List"
        TYPE="search"
        THRESHOLD=""
        VALUE="$CONNECTIONS"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Connection Group
        TITLE="Connections"
        TYPE="text"
        GROUP=$(makeOrAddToGroup "$TITLE" "$TYPE" "$DATA" "$GROUP")

        #Network Tab
        TITLE="Network"
        TYPE="tab"
        TAB=$(makeOrAddToGroup "$TITLE" "$TYPE" "$GROUP" "$TAB")
        GROUP=""


        #Disk
        DATA=""

        #Disk Actvity Chart
        # TITLE="Disk Activity"
        # TYPE="chart"
        # THRESHOLD="85"
        # VALUE="$DISK_ACTIVITY_USAGE"
        # DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Disk Type
        TITLE="Type"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$ROOT_DISK_TYPE"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Disk Total
        TITLE="Total"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$ROOT_DISK_TOTAL GB"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Disk Used
        TITLE="Used"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$ROOT_DISK_USED GB ($ROOT_DISK_USAGE%)"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Disk Free
        TITLE="Free"
        TYPE="detail"
        THRESHOLD=""
        VALUE="$ROOT_DISK_FREE GB ($ROOT_DISK_FREE_USAGE%)"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        # #Disk Write Speed
        # DISK_WRITE_SPEED=$(echo "$DD" | awk -F ',' '{print $4}' | sed 's/^[ ]//')
        # TITLE="Write Speed"
        # TYPE="detail"
        # VALUE="$DISK_WRITE_SPEED"
        # DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Disk Group
        TITLE="Root Disk"
        TYPE="text"
        GROUP=$(makeOrAddToGroup "$TITLE" "$TYPE" "$DATA" "$GROUP")


        #Disk Partitions
        DATA=""

        #Disk Partitions List
        TITLE="Disk Partitions"
        TYPE="search"
        THRESHOLD=""
        VALUE="$DISK_PARTITIONS"
        DATA=$(makeOrAddToValues "$TITLE" "$TYPE" "$THRESHOLD" "$VALUE" "$DATA")

        #Disk Partitions Group
        TITLE="Disk Partitions"
        TYPE="search"
        GROUP=$(makeOrAddToGroup "$TITLE" "$TYPE" "$DATA" "$GROUP")

        # #Biggest Files Info
        # BIGGEST_FILES=$(find ~ -type f -exec du -S {} + 2>/dev/null | sort -rn | head -n 5 | awk -v v1=$CONVERT '{printf "%0.3f", $1 / v1 * 1024; print " MB "$2 }' | perl -pe 's/\n/\\n\\n/g')
        # KEY="Biggest FIles"
        # VALUE="$BIGGEST_FILES"
        # RESULTS+=$($JQ -n --arg KEY "$KEY" --arg VALUE "$VALUE" --arg TYPE "$TYPE" --arg DISPLAY "$DISPLAY" \
        # '{ key : $KEY , value : $VALUE , type : $TYPE , display : $DISPLAY }')

        #IO Tab
        TITLE="IO"
        TYPE="tab"
        TAB=$(makeOrAddToGroup "$TITLE" "$TYPE" "$GROUP" "$TAB")
        GROUP=""


        #Put all the group data together
        if [ "$1" == "SYSOUT" ] 
        then
            echo "{ \"results\" : [ $TAB ] }"
        else
            echo "{ \"results\" : [ $TAB ] }" > "/tmp/ServerStats.txt"
        fi

        # set +x
        # exec 2>&3 3>&-
    done
fi