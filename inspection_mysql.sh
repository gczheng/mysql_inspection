#!/bin/bash
# mail:         zhenggc@ipanel.cn & lincm<lincm@ipanel.cn>
# data:         2018-11-01
# line:         V1.5
# mail:         gczheng@139.com
# data:         2018-12-01
# script_name:  inspection_mysql.sh
# Function:     MySQL巡检包含（mysqltuner.pl、inspection.conf)与inspection_mysql.sh放在同一目录下

#============================================================================================================
#定义颜色的变量
#============================================================================================================

. ./inspection.conf

echo_color(){
    color=${1} && shift
    case ${color} in
        black)
            echo -e "\e[0;30m${@}\e[0m"
            ;;
        red)
            echo -e "\e[0;31m${@}\e[0m"
            ;;
        green)
            echo -e "\e[0;32m${@}\e[0m"
            ;;
        yellow)
            echo -e "\e[0;33m${@}\e[0m"
            ;;
        blue)
            echo -e "\e[0;34m${@}\e[0m"
            ;;
        purple)
            echo -e "\e[0;35m${@}\e[0m"
            ;;
        cyan)
            echo -e "\e[0;36m${@}\e[0m"
            ;;
        *)
            echo -e "\e[0;37m${@}\e[0m"
            ;;
    esac    # --- end of case ---
}

#============================================================================================================
#设置MySQL配置信息
#============================================================================================================
#MYSQL_USER=root             #mysql的用户名
#MYSQL_PASS=iforgot          #mysql的登录用户密码
MYSQL_HOST="localhost"       #mysql的主机IP
#MYSQL_COMM=mysql 
DATE=`date -d today +"%Y-%m-%d %T"`
#BAK_PATH=/r2/bak_sql
TIME_INTERVAL=3 #等待时间
#GLOBAL_LOG=`hostname`_global_`date +%Y%m%d`.txt
#MYCNF=`hostname`_mycnf_`date +%Y%m%d`.txt
#MYSQLTUNER_LOG=`hostname`_mysqltuner_`date +%Y%m%d`.txt
#STANDARD_MYSQL_CONF=`hostname`_standard_`date +%Y%m%d`.txt
HOSTNAME=`hostname`  #主机名


#============================================================================================================
# 判断mysql账号密码是否存在，不存在请输入密码
#============================================================================================================
echo_color green "#>>>>>>>>>>>>>>>>>>>>>>>>> ${HOSTNAME} ------ ${DATE} <<<<<<<<<<<<<<<<<<<<<<<#"

if [[ ! -n ${MYSQL_USER} && ! -n ${MYSQL_PASS} ]]; then
read  -s  -p "Enter your MySQL user:" MYSQL_USER
echo
echo_color green "User name is ${MYSQL_USER} " 
echo
read  -s  -p "Enter your MySQL password:" MYSQL_PASS
echo
fi



${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "select version();"
if [ $? -ne 0 ]
then
    echo_color red "mysql login failure, please check mysql process or the username and password match or mysql service no running!"  > ${GLOBAL_LOG}
    err_exit=`cat  ${GLOBAL_LOG}`
    echo_color red ${err_exit} 
    exit 0
else
    echo_color green "MySQL is Running" > ${GLOBAL_LOG}
fi

#============================================================================================================
#设置主机配置信息
#============================================================================================================
hostname=`hostname`  #主机名
ipaddress=`ip route | awk '/src/ && !/docker/{for(i=1;i<=NF;++i)if($i == "src"){print $(i+1)}}' ` #IP地址
cpuinfo=`cat /proc/cpuinfo|grep "name"|cut -d: -f2 |awk '{print "*"$1,$2,$3,$4}'|uniq -c` #cpu
phmem=`dmidecode | grep -A 16 "Memory Device$" |grep Size:|grep -v "No Module Installed"|awk '{print "*" $2,$3}'|uniq -c` #物理内存数量
server_versions=`cat /etc/redhat-release `     #系统版本
kernel_versions=`uname -a  |awk '{print $3}'`  #内核版本
product_name=`dmidecode | grep  "Product Name" | awk 'NR==1'` 
cpuload=`cat /proc/loadavg | awk '{print $1,$2,$3}'`
MYSQL_HOST="localhost"       #mysql的主机IP
#MYSQL_COMM=mysql 
DATE=`date -d today +"%Y-%m-%d %T"`
#BAK_PATH=/r2/bak_sql
TIME_INTERVAL=3 #等待时间

#============================================================================================================
#内存情况
#============================================================================================================

mem_total=$(free -m |grep Mem|awk '{print $2}')
mem_used=$(free -m |grep Mem|awk '{print $3}')
mem_rate=`expr $mem_used/$mem_total*100|bc -l`

#============================================================================================================
#内存使用量
#============================================================================================================

mem_sum=`free -m | xargs | awk '{print "Free/total memory: " $17 " / " $8 " MB"}' \
| awk -F":" 'BEGIN{print " FREE / TOTAL " }  {print $2 }'`

#============================================================================================================
#硬盘容量
#============================================================================================================

dk_usage=`df -H |awk -F '\t' '{ print $1,$2,$3,$4,$5,$6}'`

#============================================================================================================
# MySQL original state
#============================================================================================================

# cat >> $STANDARD_MYSQL_CONF <<EOF 
# standard_basedir=/usr
# standard_datadir=/r2/mysqldata/
# standard_plugin=/usr/lib64/mysql/plugin/
# standard_osmysqluser=mysql
# standard_log_error=/r2/mysqldata/${hostname}.err
# standard_pid=/r2/mysqldata/${hostname}.pid
# standard_socket=/r2/mysqldata/mysql.sock
# EOF

osmysqluser=`ps -ef|grep -w mysqld |grep -v grep |awk '{print $1}'`

#============================================================================================================
# 1.1主机基本信息 
#============================================================================================================
echo
echo_color yellow "#===========================================================================================================#"
echo_color yellow "# 1 The system basic infomation                                                                             #"
echo_color yellow "#===========================================================================================================#"
echo

echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "1.0 server product name is:" 
echo
echo  ${product_name}
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "1.1 server cpuinfo is: " 
echo
echo ${cpuinfo}
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "1.2 server physical memory number is: " 
echo
echo ${phmem}
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#" 
echo -e "1.3 server hd disk info is: " 
echo
echo -e "${dk_usage}"
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "1.4 server hostname is:" 
echo
echo  ${hostname}
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "1.5 server ipaddree is: " 
echo
echo -e "${ipaddress}"
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "1.6 server version is: " 
echo
echo ${server_versions}
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "1.7 server system kernel version is: "
echo
echo ${kernel_versions}
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#" 
echo -e "1.8 server CPU load average is: " 
echo
echo ${cpuload}
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "1.9 server memory Summary is: " 
echo
echo ${mem_sum}
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#" 
echo -e "1.10 server top task status is: " 
echo
top -c -n 1 |grep Tasks
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#" 
echo -e "1.11 server top cpu status is: " 
echo
top -c -n 1 |grep Cpu
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#" 
echo -e "1.12 server top mem status is: " 
echo
top -c  -n 1|grep Mem  
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#" 
echo -e "1.13 server top swap status is: " 
echo
top -c -n 1|grep Swap
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#" 
echo -e "1.14  mysqld services active is: " 
echo

version=$(uname -r |awk -F '.' '{ print $(NF-1) }')
if [ "${version}" != "el7" ];then
    chkconfig --list | grep mysql 
else 
    #systemctl -a |grep mysql 
    systemctl -a |grep mysql |awk '{sub(/[[:blank:]]*$/,"",$1);print  $1  "  "  $2  "  " $3 "  "  $4  "  "}'

fi
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "1.15 mysqld number is: "
echo
ps -ef | grep "mysqld_safe" | grep -v "grep" | wc -l
echo   
echo_color blue "#-----------------------------------------------------------------------------------------------------------#" 
echo -e "1.16 server ESTABLISHED TCP connect number is: " 
echo
netstat -n | awk '/^tcp/ {++S[$NF]} END {for(a in S) print a, S[a]}'
echo
#============================================================================================================
#MySQL信息
#============================================================================================================

echo
echo_color yellow "#===========================================================================================================#"
echo_color yellow "# 2.1 MySQL basic infomation                                                                                #"
echo_color yellow "#===========================================================================================================#"
echo

vs_file="variables_status_`date +%Y%m%d%H%M%S`.txt"
${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "show variables" 1>${vs_file} 
echo_color cyan "Import variables "

gs_file="global_status_`date +%Y%m%d%H%M%S`.txt"
${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "show global status" 1>${gs_file} 

echo_color cyan "Import global status "
echo 

#============================================================================================================ 
#MySQL版本和端口
#============================================================================================================
mysql_version=`grep -w "version" $vs_file |awk '{print $2}';` 
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.1 mysql runing version is: ${mysql_version} " 
echo
mysql_port=`grep -w "port" $vs_file |awk '{print $2}'; `
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.2 mysql port is: ${mysql_port} " 
echo
#============================================================================================================
#客户端连接的MySQL进程连接数
#============================================================================================================
client_conn_num=`${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e'show full processlist' |grep -v Id |wc -l`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.3 mysql client connect number is: ${client_conn_num} " 
echo

#============================================================================================================ 
#QPS(每秒事务量)
#============================================================================================================
qps_sql="show global status like 'Questions';"
qps1=`${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "${qps_sql}" |grep -v Variable_name |cut -f 2 `
sleep "${TIME_INTERVAL}"
qps2=`${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "${qps_sql}" |grep -v Variable_name |cut -f 2`
qps=`awk 'BEGIN{print ('${qps2}'-'${qps1}') / '${TIME_INTERVAL}'}'` #shell默认不支持浮点运算
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.4 current mysql server QPS is: ${qps} " 
echo
rm -rf ${qps_re}
#============================================================================================================
#TPS(每秒事务量)
#============================================================================================================
tps_commit_sql="show  status where Variable_name in('Com_commit'); "
tps_rollback_sql="show  status where Variable_name in('Com_rollback'); "

tps1_commit=`${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e"${tps_commit_sql}" |grep -v Variable_name |cut -f 2`
tps1_rollback=`${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e"${tps_rollback_sql}" |grep -v Variable_name |cut -f 2 `
tps1=`awk 'BEGIN{print '${tps1_commit}' + '${tps1_rollback}'}'`
sleep "${TIME_INTERVAL}"
tps2_commit=`${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e"${tps_commit_sql}" |grep -v Variable_name |cut -f 2`
tps2_rollback=`${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e"${tps_rollback_sql}" |grep -v Variable_name |cut -f 2 `
tps2=`awk 'BEGIN{print '${tps2_commit}' + '${tps2_rollback}'}'` #shell默认不支持浮点运算
tps_nums=`awk 'BEGIN{print '${tps2}' - '${tps1}'}'`
tps_avg=`awk 'BEGIN{print '${tps_nums}' / '${TIME_INTERVAL}'}'` #shell默认不支持浮点运算
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.5 current mysql server TPS is: ${tps_avg} "
echo

#============================================================================================================
#key_buffer_write_hits = (1-key_writes / key_write_requests) * 100%
#============================================================================================================
kbwd_01="show  status like 'Key_writes'; "
kbwd_02="show  status like 'Key_write_requests'; "
kbwd_re01="kbwd01_`date +%Y%m%d%H%M%S`.txt"
kbwd_re02="kbwd02_`date +%Y%m%d%H%M%S`.txt"
${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e"${kbwd_01}" |grep -v Variable_name \
|cut -f 2 >${kbwd_re01}
${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e"${kbwd_02}" |grep -v Variable_name \
|cut -f 2 >${kbwd_re02}
kbwd_03=`cat ${kbwd_re01}`
kbwd_04=`cat ${kbwd_re02}`
if [ "${kbwd_03}" -eq 0  ] ;then
 echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
 echo -e "2.6 there is no any value!" 
 echo
else
 kbwd_05=`awk 'BEGIN{print '${kbwd_03}' / '${kbwd_04}'}'` #shell默认不支持浮点运算
 kbwd_06=`awk 'BEGIN{print '1-${kbwd_05}'}'` #shell默认不支持浮点运算
 key_buffer_write_hits=`awk 'BEGIN{print '${kbwd_06}' * 100}'`
 echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
 echo -e "2.6 current mysql key_buffer_write_hits is: ${key_buffer_write_hits:0:5}% " 
 echo
fi
rm -rf  ${kbwd_re01}
rm -rf  ${kbwd_re02}
 
#============================================================================================================ 
#InnoDB Buffer命中率
#Innodb_buffer_read_hits = (1 - innodb_buffer_pool_reads / innodb_buffer_pool_read_requests) * 100%
#============================================================================================================
innob_01="show  status like 'Innodb_buffer_pool_reads'; "
innob_02="show  status like 'Innodb_buffer_pool_read_requests'; "
innob_re01="innob_re01_`date +%Y%m%d%H%M%S`.txt"
innob_re02="innob_re02_`date +%Y%m%d%H%M%S`.txt"
${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e"${innob_01}" |grep -v Variable_name \
|cut -f 2 >${innob_re01}
${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e"${innob_02}" |grep -v Variable_name \
|cut -f 2 >${innob_re02}
innob_03=`cat ${innob_re01}`
innob_04=`cat ${innob_re02}`
if [ "${innob_03}" -eq 0  ] ;then
 echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
 echo -e "2.7 there is no any value!" 
 echo
else
 innob_05=`awk 'BEGIN{print '${innob_03}' / '${innob_04}'}'` #shell默认不支持浮点运算
 innob_06=`awk 'BEGIN{print '1-${innob_05}'}'` #shell默认不支持浮点运算
 innodb_buffer_read_hits=`awk 'BEGIN{print '${innob_06}' * 100}'`
 echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
 echo -e "2.7 current mysql Innodb_buffer_read_hits is: ${innodb_buffer_read_hits:0:5}% " 
 echo
fi
rm -rf ${innob_re01}
rm -rf ${innob_re02} 

#============================================================================================================
#Query Cache命中率
#Query_cache_hits =((Qcache_hits/(Qcache_hits+Qcache_inserts+Qcache_not_cached))*100)
#============================================================================================================
qc_01="show  status like 'Qcache_hits'; "
qc_02="show  status like 'Qcache_inserts'; "
qc_03="show  status like 'Qcache_not_cached'; "
qc_re01="qc_re01_`date +%Y%m%d%H%M%S`.txt"
qc_re02="qc_re02_`date +%Y%m%d%H%M%S`.txt"
qc_re03="qc_re03_`date +%Y%m%d%H%M%S`.txt"
${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e"${qc_01}" |grep -v Variable_name \
|cut -f 2 >${qc_re01}
${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e"${qc_02}" |grep -v Variable_name \
|cut -f 2 >${qc_re02}
${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e"${qc_03}" |grep -v Variable_name \
|cut -f 2 >${qc_re03}

qc_04=`cat ${qc_re01}`
qc_05=`cat ${qc_re02}`
qc_06=`cat ${qc_re03}`
if [ "${qc_04}" -eq 0  ] ;then
 echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
 echo -e "2.8 there is no any value!" 
 echo
else
 qc_07=`awk 'BEGIN{print '${qc_04}' + '${qc_05}' + '${qc_06}' }'` 
 qc_08=`awk 'BEGIN{print  '${qc_04}'/'${qc_07}'}'` 
 query_cache_hits=`awk 'BEGIN{print '${qc_08}' * 100}'`
 echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
 echo -e "2.8 current mysql query_cache_hits is: ${query_cache_hits:0:5}% " 
 echo
fi
rm -rf ${qc_re01}
rm -rf ${qc_re02}
rm -rf ${qc_re03}

#============================================================================================================ 
#索引请求命中率
#key_cache_miss_rate = Key_reads / Key_read_requests * 100%   保持 key_cache_miss_rate < 0.1%
#============================================================================================================
Key_reads=`grep -w "Key_reads" $gs_file |awk '{print $2}'`
Key_read_requests=`grep -w "Key_read_requests" $gs_file  |awk '{print $2}' ` 

if [ "${Key_reads}" -eq 0  ] ;then
 echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
 echo -e "2.9 there is no any value!" 
 echo
else
 kr_01=`awk 'BEGIN{print '${Key_reads}' / '${Key_read_requests}'}'` #shell默认不支持浮点运算
# kr_02=`awk 'BEGIN{print '1-${kr_01}'}'` #shell默认不支持浮点运算
 key_cache_miss_rate=`awk 'BEGIN{print '${kr_01}' * 100}'`
 echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
 echo -e "2.9 current mysql key_cache_miss_rate is: ${key_cache_miss_rate:0:5}% " 
 echo
fi

#============================================================================================================
#binlog日志保留天数
#============================================================================================================
expire_logs_days=`grep "expire_logs_days" $vs_file`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.10 mysql expire_logs_days is: "
echo
echo ${expire_logs_days} 
echo

#============================================================================================================
# mysql 3306端口响应时间（毫秒）
#============================================================================================================
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.11 mysql 3306 statistical response time（tcprstat）"
echo
tcprstat -p 3306 -t 1 -n 10
echo


#============================================================================================================
#MySQL 只读状态
#============================================================================================================
read_only_status=`grep "read_only" $vs_file`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.12 mysql read_only status is: "
echo
echo "${read_only_status} "
echo

#============================================================================================================
#MySQL redo log刷新策略
#============================================================================================================
innodb_flush_log_at_trx_commit=`grep "innodb_flush_log_at_trx_commit" $vs_file`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.13 mysql innodb_flush_log_at_trx_commit conf is: "
echo
echo "${innodb_flush_log_at_trx_commit}"
echo

#============================================================================================================
#MySQL binlog刷新策略
#============================================================================================================
sync_binlog=`grep "sync_binlog" $vs_file`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.14 mysql sync_binlog conf is: "
echo
echo "${sync_binlog}"
echo

#============================================================================================================
#MySQL 慢查询配置信息
#============================================================================================================
slow_conf=`grep "slow" $vs_file`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.15 mysql slow conf is: "
echo
echo "${slow_conf}"
echo

#============================================================================================================
#MySQL 慢查询时间
#============================================================================================================

long_query_time=`grep "long_query_time" $vs_file`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.16 mysql long_query_time conf is: "
echo
echo "${long_query_time}"
echo
#============================================================================================================
#MySQL 慢查询状态
#============================================================================================================

Slows=`grep "Slow" $gs_file`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.17 mysql slow status is: "
echo
echo "${Slows}"
echo

#============================================================================================================
#MySQL 最大连接数
#============================================================================================================
max_connections=`grep "max_connections" $vs_file`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.18 mysql max_connections is: "
echo
echo ${max_connections} 
echo


#============================================================================================================
#MySQL 最大用户连接数
#============================================================================================================
Max_used_connections=`grep "Max_used_connections" $gs_file`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.19 mysql Max_used_connections is: "
echo
echo ${Max_used_connections} 
echo

#============================================================================================================
#MySQL 线程创建情况
#============================================================================================================
Thread=`grep "Thread" ${gs_file}`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.20 mysql thread status is: "
echo
echo "${Thread}" 
echo

#============================================================================================================
#MySQL Innodb刷新磁盘方式
#============================================================================================================
innodb_flush_method=`grep "innodb_flush_method" $vs_file`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.21 mysql innodb_flush_method is: "
echo
echo ${innodb_flush_method}
echo

#============================================================================================================
#MySQL Abort 连接情况
#============================================================================================================
abort=`grep "Aborted" $gs_file`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.22 mysql abort status is: "
echo
echo "${abort}"
echo

#============================================================================================================
#MySQL 日志报警级别
#============================================================================================================
log_warnings=`grep -w "log_warnings" $vs_file`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.23 mysql log_warnings status is: "
echo
echo  ${log_warnings} 
echo

#============================================================================================================
#MySQL binlog 状态
#============================================================================================================
log_bin=`grep -w "log_bin" $vs_file`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.24 mysql log_bin status is: "
echo
echo  ${log_bin} 
echo

#============================================================================================================
#MySQL binlog_format 日志格式
#============================================================================================================
binlog_format=`grep "binlog_format" $vs_file`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.25 mysql binlog_format is: "
echo
echo  ${binlog_format} 
echo

echo_color yellow "#===========================================================================================================#"
echo_color yellow "# 2.2 MySQL static parameter                                                                                #"
echo_color yellow "#===========================================================================================================#"
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.3.1 mysql basedir is: "
echo                            
grep -w "basedir" $vs_file |cut -f 2
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.3.2 mysql datadir is: "
echo 
grep -w "datadir" $vs_file |cut -f 2
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.3.3 mysql plugindir is: "
echo 
grep -w "plugin" $vs_file  |cut -f 2
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.3.4 mysql error log is: "
echo 
grep -w "log_error" $vs_file  |cut -f 2
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.3.5 mysql pid-file is: "
echo 
grep -w "pid" $vs_file  |cut -f 2
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.3.6 mysql socket is: "
echo 
grep -w "socket" $vs_file |cut -f 2
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.3.7 mysql port log is: "
echo 
grep -w "port" $vs_file |cut -f 2
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "2.3.8 mysql static parameter check : "
echo 
chk_parameter="basedir datadir plugin log_error pid socket "
if [ -s $vs_file ];then
    for parameter in $chk_parameter
    do
        S1=`grep -w "${parameter}"  $vs_file |cut -f 2`
        S2=standard_${parameter}
        eval S3=$(echo \$$S2)
        #S3=`echo ${S2}`
        #S3=`grep -w ${S2} $STANDARD_MYSQL_CONF |cut -d "=" -f 2`
        #S3=`grep -w ${S2} $STANDARD_MYSQL_CONF |cut -d "=" -f 2`
    if [ "${S1}" == "${S3}" ];then
        echo_color green "mysql $parameter is OK!"
    else
        echo_color red  "WARNING:The $parameter configure is error,Please check "  |tee -a ${GLOBAL_LOG}
            continue
    fi
    done
fi
echo

echo_color yellow "#===========================================================================================================#"
echo_color yellow "# 4 MySQL Replication and Statistics                                                                        #"
echo_color yellow "#===========================================================================================================#"

#============================================================================================================
#MySQL 主从状态
#============================================================================================================
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "3.1 mysql slave_status is: "
echo

slave_hosts=`${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS}  -BN -e "show slave hosts"  |wc -l`

if [ ${slave_hosts} == '0' ]
then

    slave_status=`${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "show slave status\G;" | grep -i "Running" `
    master_host=`${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "show slave status\G;" | grep -i "Master_Host"|cut -f 2 -d ":" |sed 's/^[ \t]*//g'`
    IO_env=`echo ${slave_status} | grep IO | awk  ' {print $2}'`
    SQL_env=`echo ${slave_status} | grep SQL | awk  ' {print $2}'`

    if [ "$IO_env" = "Yes" -a "$SQL_env" = "Yes" ]
    then
        echo_color green "MySQL Slave is running!"
    else
        echo_color red "WARNING:The mysql master-slave is failure or not configure,Please check" |tee -a ${GLOBAL_LOG}
    fi
   
else
     echo_color green "This host is master!"
fi
echo 

#============================================================================================================
#MySQL Master_Host
#============================================================================================================
#master_host=`${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "show slave status\G;" | grep -i "Master_Host"|cut -f 2 -d ":" |sed 's/^[ \t]*//g'`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "3.2 mysql master_host is:"
echo
if [ ${slave_hosts} == 0 ];then
    echo "${master_host}" 
fi
echo   

echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "3.3 MySQL master 信息"

${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "show master status \G " 
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "3.4 MySQL slave 信息"

if [ ${slave_hosts} == 0 ];then
${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "show slave status \G" 
fi
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "3.5 MySQL slave user信息"

if [ ${slave_hosts} == 0 ];then
    ${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "show full processlist \G"  |grep Binlog
fi
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "3.6 MySQL 账号信息"

${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "SELECT user,host FROM mysql.user;" 

echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "3.7 MySQL 数据量信息"
${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "SELECT ENGINE AS 引擎类型,count(ENGINE) AS 表的数量,concat(round(sum((data_length+index_length)/1024/1024),2),'MB') AS 总数据量大小,concat(round(sum(data_length)/1024/1024,2),'MB') AS 数据的总大小,concat(round(sum(index_length)/1024/1024,2),'MB') AS 索引的总大小 FROM information_schema.TABLES WHERE table_schema NOT IN ('information_schema','performance_schema','mysql','sys') AND ENGINE IS NOT NULL GROUP BY ENGINE ORDER BY ENGINE ASC"
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "3.8 MySQL 各个库数据库量"
echo
${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "SELECT ENGINE AS 引擎类型,table_schema AS 库名,count(ENGINE) AS 表的数量,concat(round(sum((data_length+index_length)/1024/1024),2),'MB') AS 总数据量大小,concat(round(sum(data_length)/1024/1024,2),'MB') AS 数据的总大小,concat(round(sum(index_length)/1024/1024,2),'MB') AS 索引的总大小,concat( round( sum( data_free) / 1024 / 1024 , 2 ), 'MB' ) AS 碎片空间 FROM information_schema.TABLES WHERE table_schema NOT IN ('information_schema','performance_schema','mysql','sys') AND ENGINE IS NOT NULL GROUP BY table_schema ORDER BY table_schema ASC;" 

echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "3.9 执行mysqltuner.pl 脚本"
echo
/usr/bin/perl mysqltuner.pl  --user ${MYSQL_USER} --pass ${MYSQL_PASS} > ${MYSQLTUNER_LOG}
echo_color cyan "execute mysqltuner "
echo

echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "3.10 MySQL 显示my.cnf 信息"
echo
egrep  -v "^$|^#" /etc/my.cnf  >${MYCNF}
echo_color cyan "Import my.cnf "
echo

echo_color yellow "#===========================================================================================================#"
echo_color yellow "# 4 MySQL backup and error.log                                                                              #"
echo_color yellow "#===========================================================================================================#"
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "4.1 mysql bakcup list: "
echo 
bkinfo_01="bakinfo_`date +%Y%m%d%H%M%S`.txt"
if [ ! -d $BAK_PATH ]; then
    echo "WARNING:The mysql bakup directory ${BAK_PATH} is not existed,Please check." > ${bkinfo_01} |tee -a  ${GLOBAL_LOG}
    else
    ls -l $BAK_PATH > ${bkinfo_01}
fi                                                                       
bkinfo_02=`cat ${bkinfo_01}`
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "mysql backup_status is: "
echo
echo -e "${bkinfo_02}" 
echo
rm -rf ${bkinfo_01}
echo
echo_color blue "#-----------------------------------------------------------------------------------------------------------#"
echo -e "4.2 mysql error log : "
mysql_error_log=`${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "show variables" | grep -w "log_error" |cut -f 2`
grep -I err $mysql_error_log | tail -n 10
echo

echo
echo_color yellow "#===========================================================================================================#"
echo_color yellow "# 5 WARNING......                                                                                           #"
echo_color yellow "#===========================================================================================================#"

echo  
cat ${GLOBAL_LOG}
echo
rm -rf ${STANDARD_MYSQL_CONF}
rm -rf ${GLOBAL_LOG}
rm -rf ${vs_file}
rm -rf ${gs_file} 
echo
echo_color yellow "#------------------------------------------------Done-------------------------------------------------------#"
