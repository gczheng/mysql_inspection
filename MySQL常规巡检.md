MySQL常规巡检

[TOC]

##  一、巡检脚本

巡检脚本包括三个文件inspection.conf、inspection_mysql.sh、mysqltuner.pl



```bash
bash>ll
-rw-r--r-- 1 root root    994 Nov  1 16:33 inspection.conf
-rwxr-xr-x 1 root root  39221 Nov  1 15:26 inspection_mysql_v4.sh
-rwxr-xr-x 1 root root 219803 Nov  1 11:32 mysqltuner.pl
```


##  二、下载巡检脚本

* 下载地址：

[Github：mysql_inspection]()

## 三、脚本执行说明

### 1、inspection.conf 使用说明

使用说明：配置mysql登录账号信息以及mysql的标准配置

```bash
#============================================================================================================
#MySQL巡检配置
#============================================================================================================

#mysql用户名
MYSQL_USER=root

#mysql用户密码
MYSQL_PASS='xxxxxxx'

#mysql客户端
MYSQL_COMM=mysql

#备份路径
BAK_PATH=/r2/bak_sql

#mysql全局日志
GLOBAL_LOG=`hostname`_global_`date +%Y%m%d`.txt

#mycnf内容输出
MYCNF=`hostname`_mycnf_`date +%Y%m%d`.txt

#mysqltuner输出日志
MYSQLTUNER_LOG=`hostname`_mysqltuner_`date +%Y%m%d`.txt

#检查mysql标准配置日志
#TANDARD_MYSQL_CONF=`hostname`_standard_`date +%Y%m%d`.txt

#检查mysql标准配置
standard_basedir=/usr/
standard_datadir=/r2/mysqldata/
standard_plugin=/usr/lib64/mysql/plugin/
standard_osmysqluser=mysql
standard_log_error=/r2/mysqldata/error.log
standard_pid=/r2/mysqldata/`hostname`.pid
standard_socket=/r2/mysqldata/mysql.sock
```

### 2、inspection_mysql.sh  使用说明

inspection_mysql.sh

脚本简述 :主脚本通过读取inspection.conf 配置文件来执行，调用perl来执行 mysqltuner.pl来提供优化建议

```bash
#!/bin/bash
# line:         V1.4
# mail:         gczheng@139.com
# data:         2018-11-01
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
VERSTON=`${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS}  -Bse "select @@version" |cut -b 1-3`
if [ $VERSTON = "5.5" ];then
    ${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "SELECT user,host,password FROM mysql.user;"
else
    ${MYSQL_COMM} -h${MYSQL_HOST} -u${MYSQL_USER}  -p${MYSQL_PASS} -e "SELECT user,host,authentication_string  FROM mysql.user;"
fi
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

```



### 3、mysqltuner.pl 使用说明

脚本简述：这是mysql调优工具，给出一些基本的建议

* 单独运行

./mysqltuner.pl  --user=xxxxxx    --pass='xxxxxx'

或者

./mysqltuner.pl 按照提示输入账号秘密

```bash
[root@node05 inspection]# ./mysqltuner.pl
 >>  MySQLTuner 1.7.13 - Major Hayden <major@mhtx.net>
 >>  Bug reports, feature requests, and downloads at http://mysqltuner.com/
 >>  Run with '--help' for additional options and output filtering

[--] Skipped version check for MySQLTuner script
Please enter your MySQL administrative login: root
Please enter your MySQL administrative password: [OK] Currently running supported MySQL version 5.7.18-log
[OK] Operating on 64-bit architecture

-------- Log file Recommendations ------------------------------------------------------------------
[--] Log file: /r2/mysqldata/error.log(15M)
[OK] Log file /r2/mysqldata/error.log exists
[OK] Log file /r2/mysqldata/error.log is readable.
[OK] Log file /r2/mysqldata/error.log is not empty
[OK] Log file /r2/mysqldata/error.log is smaller than 32 Mb
[!!] /r2/mysqldata/error.log contains 199 warning(s).
[!!] /r2/mysqldata/error.log contains 48 error(s).
[--] 13 start(s) detected in /r2/mysqldata/error.log
[--] 1) 2018-09-23T11:30:44.421380+08:00 0 [Note] /usr/local/mysql/bin/mysqld: ready for connections.
[--] 2) 2018-09-08T14:02:24.419793+08:00 0 [Note] /usr/local/mysql/bin/mysqld: ready for connections.
[--] 3) 2018-08-28T14:22:13.766952+08:00 0 [Note] /usr/local/mysql/bin/mysqld: ready for connections.
[--] 4) 2018-08-28T14:19:05.843599+08:00 0 [Note] /usr/local/mysql/bin/mysqld: ready for connections.
[--] 5) 2018-08-28T13:36:32.106335+08:00 0 [Note] /usr/local/mysql/bin/mysqld: ready for connections.
[--] 6) 2018-08-28T12:09:18.446973+08:00 0 [Note] /usr/local/mysql/bin/mysqld: ready for connections.
[--] 7) 2018-08-28T11:51:36.883974+08:00 0 [Note] /usr/local/mysql/bin/mysqld: ready for connections.
[--] 8) 2018-08-06T17:45:10.958564+08:00 0 [Note] /usr/local/mysql/bin/mysqld: ready for connections.
[--] 9) 2018-04-14T12:31:03.915754+08:00 0 [Note] /usr/local/mysql/bin/mysqld: ready for connections.
[--] 10) 2018-04-03T09:28:06.695373+08:00 0 [Note] /usr/local/mysql/bin/mysqld: ready for connections.
[--] 11 shutdown(s) detected in /r2/mysqldata/error.log
[--] 1) 2018-08-28T14:21:14.925010+08:00 0 [Note] /usr/local/mysql/bin/mysqld: Shutdown complete
[--] 2) 2018-08-28T13:39:34.139421+08:00 0 [Note] /usr/local/mysql/bin/mysqld: Shutdown complete
[--] 3) 2018-08-28T12:13:11.415338+08:00 0 [Note] /usr/local/mysql/bin/mysqld: Shutdown complete
[--] 4) 2018-08-28T12:05:50.779021+08:00 0 [Note] /usr/local/mysql/bin/mysqld: Shutdown complete
[--] 5) 2018-08-06T17:45:39.133446+08:00 0 [Note] /usr/local/mysql/bin/mysqld: Shutdown complete
[--] 6) 2018-04-14T12:45:53.671195+08:00 0 [Note] /usr/local/mysql/bin/mysqld: Shutdown complete
[--] 7) 2018-04-03T10:00:19.702983+08:00 0 [Note] /usr/local/mysql/bin/mysqld: Shutdown complete
[--] 8) 2018-04-03T09:24:02.192051+08:00 0 [Note] /usr/local/mysql/bin/mysqld: Shutdown complete
[--] 9) 2018-03-30T15:31:22.754077+08:00 0 [Note] /usr/local/mysql/bin/mysqld: Shutdown complete
[--] 10) 2018-03-30T15:26:57.967712+08:00 0 [Note] /usr/local/mysql/bin/mysqld: Shutdown complete

-------- Storage Engine Statistics -----------------------------------------------------------------
[--] Status: +ARCHIVE +BLACKHOLE +CSV -FEDERATED +InnoDB +MEMORY +MRG_MYISAM +MyISAM +PERFORMANCE_SCHEMA
[--] Data in InnoDB tables: 1.7G (Tables: 14)
[OK] Total fragmented tables: 0

-------- Analysis Performance Metrics --------------------------------------------------------------
[--] innodb_stats_on_metadata: OFF
[OK] No stat updates during querying INFORMATION_SCHEMA.

-------- Security Recommendations ------------------------------------------------------------------
[OK] There are no anonymous accounts for any database users
[OK] All database users have passwords assigned
[!!] User 'dbbackup@localhost' has user name as password.
[!!] User 'monitor@%' has user name as password.
[!!] User 'repl@%' has user name as password.
[!!] User 'gcdb@%' does not specify hostname restrictions.
[!!] User 'monitor@%' does not specify hostname restrictions.
[!!] User 'repl@%' does not specify hostname restrictions.
[!!] There is no basic password file list!

-------- CVE Security Recommendations --------------------------------------------------------------
[--] Skipped due to --cvefile option undefined

-------- Performance Metrics -----------------------------------------------------------------------
[--] Up for: 39d 5h 25m 12s (6M q [2.059 qps], 309K conn, TX: 2G, RX: 553M)
[--] Reads / Writes: 21% / 79%
[--] Binary logging is enabled (GTID MODE: ON)
[--] Physical Memory     : 3.7G
[--] Max MySQL memory    : 280.9G
[--] Other process memory: 39.2M
[--] Total buffers: 5.0G global + 28.2M per thread (10000 max threads)
[--] P_S Max memory usage: 72B
[--] Galera GCache Max memory usage: 0B
[!!] Maximum reached memory usage: 5.3G (143.80% of installed RAM)
[!!] Maximum possible memory usage: 280.9G (7589.63% of installed RAM)
[!!] Overall possible memory usage with other process exceeded memory
[OK] Slow queries: 0% (31/6M)
[OK] Highest usage of available connections: 0% (10/10000)
[!!] Aborted connections: 49.33%  (152905/309937)
[OK] Query cache is disabled by default due to mutex contention on multiprocessor machines.
[OK] Sorts requiring temporary tables: 0% (1 temp sorts / 216 sorts)
[OK] No joins without indexes
[!!] Temporary tables created on disk: 26% (140K on disk / 526K total)
[OK] Thread cache hit rate: 99% (10 created / 309K connections)
[!!] Table cache hit rate: 3% (1K open / 28K opened)
[OK] Open file limit used: 0% (70/50K)
[OK] Table locks acquired immediately: 100% (331K immediate / 331K locks)
[OK] Binlog cache memory access: 100.00% (2414856 Memory / 2414858 Total)

-------- Performance schema ------------------------------------------------------------------------
[--] Memory used by P_S: 72B
[--] Sys schema is installed.

-------- ThreadPool Metrics ------------------------------------------------------------------------
[--] ThreadPool stat is disabled.

-------- MyISAM Metrics ----------------------------------------------------------------------------
[!!] Key buffer used: 18.2% (195M used / 1B cache)
[OK] Key buffer size / total MyISAM indexes: 1.0G/43.0K
[OK] Read Key buffer hit rate: 99.9% (5K cached / 7 reads)

-------- InnoDB Metrics ----------------------------------------------------------------------------
[--] InnoDB is enabled.
[--] InnoDB Thread Concurrency: 64
[OK] InnoDB File per table is activated
[OK] InnoDB buffer pool / data size: 4.0G/1.7G
[!!] Ratio InnoDB log file size / InnoDB Buffer pool size (100 %): 2.0G * 2/4.0G should be equal 25%
[!!] InnoDB buffer pool instances: 8
[--] Number of InnoDB Buffer Pool Chunk : 32 for 8 Buffer Pool Instance(s)
[OK] Innodb_buffer_pool_size aligned with Innodb_buffer_pool_chunk_size & Innodb_buffer_pool_instances
[OK] InnoDB Read buffer efficiency: 99.99% (545706828 hits/ 545736823 total)
[!!] InnoDB Write Log efficiency: 73.85% (6832250 hits/ 9251110 total)
[OK] InnoDB log waits: 0.00% (0 waits / 2418860 writes)

-------- AriaDB Metrics ----------------------------------------------------------------------------
[--] AriaDB is disabled.

-------- TokuDB Metrics ----------------------------------------------------------------------------
[--] TokuDB is disabled.

-------- XtraDB Metrics ----------------------------------------------------------------------------
[--] XtraDB is disabled.

-------- Galera Metrics ----------------------------------------------------------------------------
[--] Galera is disabled.

-------- Replication Metrics -----------------------------------------------------------------------
[--] Galera Synchronous replication: NO
[--] No replication slave(s) for this server.
[--] Binlog format: ROW
[--] XA support enabled: ON
[--] Semi synchronous replication Master: Not Activated
[--] Semi synchronous replication Slave: Not Activated
[--] This is a standalone server

-------- Recommendations ---------------------------------------------------------------------------
General recommendations:
    Control warning line(s) into /r2/mysqldata/error.log file
    Control error line(s) into /r2/mysqldata/error.log file
    Set up a Secure Password for user@host ( SET PASSWORD FOR 'user'@'SpecificDNSorIp' = PASSWORD('secure_password'); )
    Restrict Host for user@% to user@SpecificDNSorIp
    Reduce your overall MySQL memory footprint for system stability
    Dedicate this server to your database for highest performance.
    Reduce or eliminate unclosed connections and network issues
    When making adjustments, make tmp_table_size/max_heap_table_size equal
    Reduce your SELECT DISTINCT queries which have no LIMIT clause
    Increase table_open_cache gradually to avoid file descriptor limits
    Read this before increasing table_open_cache over 64: http://bit.ly/1mi7c4C
    Read this before increasing for MariaDB https://mariadb.com/kb/en/library/optimizing-table_open_cache/
    This is MyISAM only table_cache scalability problem, InnoDB not affected.
    See more details here: https://bugs.mysql.com/bug.php?id=49177
    This bug already fixed in MySQL 5.7.9 and newer MySQL versions.
    Beware that open_files_limit (50000) variable
    should be greater than table_open_cache (1024)
    Before changing innodb_log_file_size and/or innodb_log_files_in_group read this: http://bit.ly/2wgkDvS
Variables to adjust:
  *** MySQL's maximum memory usage is dangerously high ***
  *** Add RAM before increasing MySQL buffer variables ***
    tmp_table_size (> 32M)
    max_heap_table_size (> 32M)
    table_open_cache (> 1024)
    innodb_log_file_size should be (=512M) if possible, so InnoDB total log files size equals to 25% of buffer pool size.
    innodb_buffer_pool_instances(=4)

```

## 四、执行结果

 inspection_mysql_v4.sh mysqltuner.pl 需要执行权限，mysql需要root权限

```bash
[root@slave1 inspection]# chmod -x inspection_mysql_v4.sh mysqltuner.pl
[root@slave1 inspection]# ./inspection_mysql_v4.sh 2>/dev/null
#>>>>>>>>>>>>>>>>>>>>>>>>> slave1 ------ 2018-11-01 16:35:58 <<<<<<<<<<<<<<<<<<<<<<<#
+------------+
| version()  |
+------------+
| 5.7.18-log |
+------------+

#===========================================================================================================#
# 1 The system basic infomation                                                                             #
#===========================================================================================================#

#-----------------------------------------------------------------------------------------------------------#
1.0 server product name is:

Product Name: PowerEdge R720xd

#-----------------------------------------------------------------------------------------------------------#
1.1 server cpuinfo is:

24 *Intel(R) Xeon(R) CPU E5-2620

#-----------------------------------------------------------------------------------------------------------#
1.2 server physical memory number is:

1 *16384 MB 2 *8192 MB 1 *16384 MB 2 *8192 MB

#-----------------------------------------------------------------------------------------------------------#
1.3 server hd disk info is:

文件系统                                                容量  已用  可用 已用% 挂载点
/dev/sda6                                                53G  8.6G   42G   18% /
devtmpfs                                                 34G     0   34G    0% /dev
tmpfs                                                    34G     0   34G    0% /dev/shm
tmpfs                                                    34G  2.7G   31G    8% /run
tmpfs                                                    34G     0   34G    0% /sys/fs/cgroup
/dev/sdg1                                               1.2T  310G  800G   28% /data5
/dev/sdc1                                               975G  370G  555G   41% /data1
/dev/sdd1                                               975G  317G  608G   35% /data2
/dev/sdb1                                               1.0T  726G  224G   77% /r2
/dev/sdh1                                               1.2T  311G  799G   28% /data6
/dev/sde1                                               975G  328G  598G   36% /data3
/dev/sdf1                                               975G  333G  593G   36% /data4
/dev/sdj1                                               1.2T  313G  797G   29% /data7
/dev/sdi1                                               1.2T  315G  796G   29% /data8
/dev/sda3                                               1.1G  106M  848M   12% /boot
/dev/sda5                                               205G  5.4G  189G    3% /usr/local


#-----------------------------------------------------------------------------------------------------------#
1.4 server hostname is:

slave1

#-----------------------------------------------------------------------------------------------------------#
1.5 server ipaddree is:

192.168.102.131


#-----------------------------------------------------------------------------------------------------------#
1.6 server version is:

CentOS Linux release 7.3.1611 (Core)

#-----------------------------------------------------------------------------------------------------------#
1.7 server system kernel version is:

3.10.0-514.el7.x86_64

#-----------------------------------------------------------------------------------------------------------#
1.8 server CPU load average is:

3.42 2.45 2.22

#-----------------------------------------------------------------------------------------------------------#
1.9 server memory Summary is:

FREE / TOTAL 32765 / 64217 MB

#-----------------------------------------------------------------------------------------------------------#
1.10 server top task status is:

Tasks: 367 total,   1 running, 364 sleeping,   0 stopped,   2 zombie

#-----------------------------------------------------------------------------------------------------------#
1.11 server top cpu status is:

%Cpu(s):  5.5 us,  2.6 sy,  0.0 ni, 91.7 id,  0.2 wa,  0.0 hi,  0.1 si,  0.0 st

#-----------------------------------------------------------------------------------------------------------#
1.12 server top mem status is:

KiB Mem : 65758324 total, 12051048 free, 47868896 used,  5838380 buff/cache
KiB Swap: 33553404 total, 33551392 free,     2012 used. 11977532 avail Mem

#-----------------------------------------------------------------------------------------------------------#
1.13 server top swap status is:

KiB Swap: 33553404 total, 33551392 free,     2012 used. 11966972 avail Mem

#-----------------------------------------------------------------------------------------------------------#
1.14  mysqld services active is:

mysql.service  loaded  active  running
pmm-mysql-metrics-42002.service  loaded  active  running
pmm-mysql-queries-0.service  loaded  active  running

#-----------------------------------------------------------------------------------------------------------#
1.15 mysqld number is:

1

#-----------------------------------------------------------------------------------------------------------#
1.16 server ESTABLISHED TCP connect number is:

ESTABLISHED 457
TIME_WAIT 942


#===========================================================================================================#
# 2.1 MySQL basic infomation                                                                                #
#===========================================================================================================#

Import variables
Import global status

#-----------------------------------------------------------------------------------------------------------#
2.1 mysql runing version is: 5.7.18-log

#-----------------------------------------------------------------------------------------------------------#
2.2 mysql port is: 3306

#-----------------------------------------------------------------------------------------------------------#
2.3 mysql client connect number is: 3

#-----------------------------------------------------------------------------------------------------------#
2.4 current mysql server QPS is: 23.3333

#-----------------------------------------------------------------------------------------------------------#
2.5 current mysql server TPS is: 0

#-----------------------------------------------------------------------------------------------------------#
2.6 current mysql key_buffer_write_hits is: 92.26%

#-----------------------------------------------------------------------------------------------------------#
2.7 current mysql Innodb_buffer_read_hits is: 99.99%

#-----------------------------------------------------------------------------------------------------------#
2.8 there is no any value!

#-----------------------------------------------------------------------------------------------------------#
2.9 current mysql key_cache_miss_rate is: 2.387%

#-----------------------------------------------------------------------------------------------------------#
2.10 mysql expire_logs_days is:

expire_logs_days 30

#-----------------------------------------------------------------------------------------------------------#
2.11 mysql 3306 statistical response time（tcprstat）

timestamp	count	max	min	avg	med	stddev	95_max	95_avg	95_std	99_max	99_avg	99_std
1541061367	0	0	0	0	0	0	0	0	0	0	0	0
1541061368	8	619	106	254	189	171	443	202	109	443	202	109
1541061369	0	0	0	0	0	0	0	0	0	0	0	0
1541061370	0	0	0	0	0	0	0	0	0	0	0	0
1541061371	8	715	138	290	230	178	398	230	81	398	230	81
1541061372	0	0	0	0	0	0	0	0	0	0	0	0
1541061373	0	0	0	0	0	0	0	0	0	0	0	0
1541061374	8	479	83	208	169	133	371	170	90	371	170	90
1541061375	0	0	0	0	0	0	0	0	0	0	0	0
1541061376	0	0	0	0	0	0	0	0	0	0	0	0

#-----------------------------------------------------------------------------------------------------------#
2.12 mysql read_only status is:

innodb_read_only	OFF
read_only	OFF
super_read_only	OFF
tx_read_only	OFF

#-----------------------------------------------------------------------------------------------------------#
2.13 mysql innodb_flush_log_at_trx_commit conf is:

innodb_flush_log_at_trx_commit	2

#-----------------------------------------------------------------------------------------------------------#
2.14 mysql sync_binlog conf is:

sync_binlog	0

#-----------------------------------------------------------------------------------------------------------#
2.15 mysql slow conf is:

log_slow_admin_statements	OFF
log_slow_slave_statements	OFF
slow_launch_time	2
slow_query_log	ON
slow_query_log_file	/r2/mysqldata/slow.log

#-----------------------------------------------------------------------------------------------------------#
2.16 mysql long_query_time conf is:

long_query_time	10.000000

#-----------------------------------------------------------------------------------------------------------#
2.17 mysql slow status is:

Slow_launch_threads	0
Slow_queries	157

#-----------------------------------------------------------------------------------------------------------#
2.18 mysql max_connections is:

max_connections 10000

#-----------------------------------------------------------------------------------------------------------#
2.19 mysql Max_used_connections is:

Max_used_connections 8 Max_used_connections_time 2018-09-27 04:00:11

#-----------------------------------------------------------------------------------------------------------#
2.20 mysql thread status is:

Threads_cached	7
Threads_connected	1
Threads_created	8
Threads_running	1

#-----------------------------------------------------------------------------------------------------------#
2.21 mysql innodb_flush_method is:

innodb_flush_method O_DIRECT

#-----------------------------------------------------------------------------------------------------------#
2.22 mysql abort status is:

Aborted_clients	2
Aborted_connects	2

#-----------------------------------------------------------------------------------------------------------#
2.23 mysql log_warnings status is:

log_warnings 2

#-----------------------------------------------------------------------------------------------------------#
2.24 mysql log_bin status is:

log_bin ON

#-----------------------------------------------------------------------------------------------------------#
2.25 mysql binlog_format is:

binlog_format MIXED

#===========================================================================================================#
# 2.2 MySQL static parameter                                                                                #
#===========================================================================================================#

#-----------------------------------------------------------------------------------------------------------#
2.3.1 mysql basedir is:

/usr/

#-----------------------------------------------------------------------------------------------------------#
2.3.2 mysql datadir is:

/r2/mysqldata/

#-----------------------------------------------------------------------------------------------------------#
2.3.3 mysql plugindir is:

/usr/lib64/mysql/plugin/

#-----------------------------------------------------------------------------------------------------------#
2.3.4 mysql error log is:

/r2/mysqldata/error.log

#-----------------------------------------------------------------------------------------------------------#
2.3.5 mysql pid-file is:

/r2/mysqldata/slave1.pid

#-----------------------------------------------------------------------------------------------------------#
2.3.6 mysql socket is:

/r2/mysqldata/mysql.sock

#-----------------------------------------------------------------------------------------------------------#
2.3.7 mysql port log is:

3306

#-----------------------------------------------------------------------------------------------------------#
2.3.8 mysql static parameter check :

mysql basedir is OK!
mysql datadir is OK!
mysql plugin is OK!
mysql log_error is OK!
mysql pid is OK!
mysql socket is OK!

#===========================================================================================================#
# 4 MySQL Replication and Statistics                                                                        #
#===========================================================================================================#
#-----------------------------------------------------------------------------------------------------------#
3.1 mysql slave_status is:

MySQL Slave is running!

#-----------------------------------------------------------------------------------------------------------#
3.2 mysql master_host is:

192.168.102.130

#-----------------------------------------------------------------------------------------------------------#
3.3 MySQL master 信息
*************************** 1. row ***************************
             File: slave1-bin.000958
         Position: 699382221
     Binlog_Do_DB:
 Binlog_Ignore_DB:
Executed_Gtid_Set: 746122da-663e-11e7-9de1-b8ca3a6567c4:1-19119,
a57cd625-663e-11e7-9ba9-b8ca3a64d66c:18606-190213162:190249486-190252207:190327015-207860771:207860811-244861160:244862559-1116656470

#-----------------------------------------------------------------------------------------------------------#
3.4 MySQL slave 信息
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: 192.168.102.130
                  Master_User: repl
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: slave1-bin.000757
          Read_Master_Log_Pos: 977018627
               Relay_Log_File: slave1-relay-bin.000966
                Relay_Log_Pos: 977018842
        Relay_Master_Log_File: slave1-bin.000757
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
              Replicate_Do_DB:
          Replicate_Ignore_DB:
           Replicate_Do_Table:
       Replicate_Ignore_Table:
      Replicate_Wild_Do_Table:
  Replicate_Wild_Ignore_Table:
                   Last_Errno: 0
                   Last_Error:
                 Skip_Counter: 0
          Exec_Master_Log_Pos: 977018627
              Relay_Log_Space: 977019138
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Master_SSL_Allowed: No
           Master_SSL_CA_File:
           Master_SSL_CA_Path:
              Master_SSL_Cert:
            Master_SSL_Cipher:
               Master_SSL_Key:
        Seconds_Behind_Master: 0
Master_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Master_Server_Id: 1
                  Master_UUID: a57cd625-663e-11e7-9ba9-b8ca3a64d66c
             Master_Info_File: /r2/mysqldata/master.info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
      Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
           Master_Retry_Count: 86400
                  Master_Bind:
      Last_IO_Error_Timestamp:
     Last_SQL_Error_Timestamp:
               Master_SSL_Crl:
           Master_SSL_Crlpath:
           Retrieved_Gtid_Set: a57cd625-663e-11e7-9ba9-b8ca3a64d66c:739182758-1116656470
            Executed_Gtid_Set: 746122da-663e-11e7-9de1-b8ca3a6567c4:1-19119,
a57cd625-663e-11e7-9ba9-b8ca3a64d66c:18606-190213162:190249486-190252207:190327015-207860771:207860811-244861160:244862559-1116656470
                Auto_Position: 0
         Replicate_Rewrite_DB:
                 Channel_Name:
           Master_TLS_Version:

#-----------------------------------------------------------------------------------------------------------#
3.5 MySQL slave user信息

#-----------------------------------------------------------------------------------------------------------#
3.6 MySQL 账号信息

+--------------+-----------+
| user         | host      |
+--------------+-----------+
| monitor      | %         |
| repl         | %         |
| root         | %         |
| root         | localhost |
+--------------+-----------+


#-----------------------------------------------------------------------------------------------------------#
3.7 MySQL 数据量信息
+--------------+--------------+--------------------+--------------------+--------------------+
| 引擎类型     | 表的数量     | 总数据量大小       | 数据的总大小       | 索引的总大小       |
+--------------+--------------+--------------------+--------------------+--------------------+
| InnoDB       |         1475 | 8555.11MB          | 6741.61MB          | 1813.50MB          |
| MyISAM       |          815 | 462.22MB           | 375.53MB           | 86.69MB            |
+--------------+--------------+--------------------+--------------------+--------------------+

#-----------------------------------------------------------------------------------------------------------#
3.8 MySQL 各个库数据库量

+--------------+-----------------+--------------+--------------------+--------------------+--------------------+--------------+
| 引擎类型     | 库名            | 表的数量     | 总数据量大小       | 数据的总大小       | 索引的总大小       | 碎片空间     |
+--------------+-----------------+--------------+--------------------+--------------------+--------------------+--------------+
| InnoDB       | adbcd_data      |            7 | 231.38MB           | 231.38MB           | 0.00MB             | 32.00MB      |
| InnoDB       | adbss_dtss      |          182 | 1417.19MB          | 1156.67MB          | 260.52MB           | 796.00MB     |
+--------------+-----------------+--------------+--------------------+--------------------+--------------------+--------------+

#-----------------------------------------------------------------------------------------------------------#
3.9 执行mysqltuner.pl 脚本

execute mysqltuner

#-----------------------------------------------------------------------------------------------------------#
3.10 MySQL 显示my.cnf 信息

Import my.cnf

#===========================================================================================================#
# 4 MySQL backup and error.log                                                                              #
#===========================================================================================================#

#-----------------------------------------------------------------------------------------------------------#
4.1 mysql bakcup list:

#-----------------------------------------------------------------------------------------------------------#
mysql backup_status is:

WARNING:The mysql bakup directory /r2/bak_sql is not existed,Please check.


#-----------------------------------------------------------------------------------------------------------#
4.2 mysql error log :

2018-09-08T14:31:12.555799+08:00 0 [Warning] Using pre 5.5 semantics to load error messages from /usr/share/.
2018-09-08T14:31:18.596139+08:00 0 [Warning] Failed to set up SSL because of the following SSL library error: SSL context is not usable without certificate and private key
2018-09-23T11:22:29.289013+08:00 0 [Warning] Using pre 5.5 semantics to load error messages from /usr/share/.
2018-09-23T11:22:59.916567+08:00 0 [Warning] Failed to set up SSL because of the following SSL library error: SSL context is not usable without certificate and private key



#===========================================================================================================#
# 5 WARNING......                                                                                           #
#===========================================================================================================#

MySQL is Running


#------------------------------------------------Done-------------------------------------------------------#

```



