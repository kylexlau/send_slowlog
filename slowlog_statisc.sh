#!/bin/bash

## 定时任务请设置在凌晨，并且在凌晨4点前

MyDate=`date  +%Y%m%d`
MyTimestap=`date -d ${MyDate}  +%s `
CurrentTimestap=`date +%s`
SLOWLOG_PATH=/mysql/mysqldata/
SLOWLOG_FILE=mysql-slow.log
SLOWLOG_BAKPATH=/mysql/logs/slowlog-bak
TOOL_PATH=/mysql/sh/tool
SLOWLOG_BAKFILE=${SLOWLOG_FILE}_${MyDate}
BAKFILE_LOG=${SLOWLOG_BAKPATH}/bakfile.log
BAKFILE_ERROTLOG=${SLOWLOG_BAKPATH}/bakfile_error.log
STATISC_FILE=${SLOWLOG_BAKPATH}/statiscSlowLog_${MyDate}.log

DIGESTCOM='/mysql/sh/tool/pt-query-digest  --limit 20 '

MYSQLCOM="mysql "
dbuser="user"
dbpass='pass'
dbport=3306
dbhost="localhost"
sqlcom="set global slow_query_log=0; select sleep(1); set global slow_query_log=1;"
showSlowCom="show variables like '%slow_query_log_file%'"
myline=0;
realyline=0;
delday=7 

mail_t='user1@comp.com;user2@comp.com;'
mail_f='dba@comp.com'
mail_p='mailpass'
mail_s='mail.comp.com'

if [ ! -d "$SLOWLOG_BAKPATH"   ]; then 
 mkdir -p $SLOWLOG_BAKPATH
fi 

if [ ! -d "$TOOL_PATH"   ]; then 
 mkdir -p $TOOL_PATH
fi 

count_ip=$(/sbin/ifconfig | grep inet  | grep Bcast | awk -F":" '{print $2}' | awk '{print $1}'  | wc -l)
if [ $count_ip -eq 1 ]; then
        IP=$(/sbin/ifconfig | grep inet  | grep Bcast | awk -F":" '{print $2}' | awk '{print $1}' )
else
        IP=$(/sbin/ifconfig | grep inet  | grep Bcast | awk -F":" '{print $2}' | awk '{print $1}'  | awk 'NR==1')
fi

if [[ ! -f "${SLOWLOG_PATH}/${SLOWLOG_FILE}" || ! -s "${SLOWLOG_PATH}/${SLOWLOG_FILE}" ]];then
    echo $(date +%Y"."%m"."%d" "%k":"%M":"%S):"文件不存在或为空":${SLOWLOG_PATH}/${SLOWLOG_FILE} | tee -a ${BAKFILE_LOG}  
	${MYSQLCOM} -u${dbuser} -p${dbpass} -P${dbport} -h${dbhost} -e "${sqlcom}"   
	echo $(date +%Y"."%m"."%d" "%k":"%M":"%S):"执行命令：${MYSQLCOM} -e ${sqlcom}" | tee -a ${BAKFILE_LOG}
    exit
fi

##$(cat ${SLOWLOG_PATH}/${SLOWLOG_FILE} | wc -l) -ne 0 
#if [[ ! -s "${SLOWLOG_PATH}/${SLOWLOG_FILE}" ]];then
#    echo $(date +%Y"."%m"."%d" "%k":"%M":"%S):"空文件":${SLOWLOG_PATH}/${SLOWLOG_FILE} | tee -a ${BAKFILE_LOG} 
#    exit
#fi

function backupSlowFile(){
echo $(date +%Y"."%m"."%d" "%k":"%M":"%S):"开始切分慢日志文件":${SLOWLOG_PATH}/${SLOWLOG_FILE} | tee -a ${BAKFILE_LOG} 
echo $(date +%Y"."%m"."%d" "%k":"%M":"%S):"开始查找切分的行数,截止时间戳:"$MyTimestap | tee -a ${BAKFILE_LOG} 
MyTimestap=`grep -n 'SET timestamp=14*'  ${SLOWLOG_PATH}/${SLOWLOG_FILE} |awk -F '=' ' {print $2} ' | awk -F ';' '$1=='$MyTimestap'||$1>'$MyTimestap' {print $1 }' | head -1 `
if  [[ ${MyTimestap}'X' = 'X' ]];then
	echo $(date +%Y"."%m"."%d" "%k":"%M":"%S):"没有匹配到当天最小时间戳" | tee -a ${BAKFILE_LOG} 
	mv ${SLOWLOG_PATH}/${SLOWLOG_FILE}  ${SLOWLOG_BAKPATH}/${SLOWLOG_BAKFILE}
	echo $(date +%Y"."%m"."%d" "%k":"%M":"%S):"备份整个日志文件" | tee -a ${BAKFILE_LOG}	
	${MYSQLCOM} -u${dbuser} -p${dbpass} -P${dbport} -h${dbhost} -e "${sqlcom}"   
	echo $(date +%Y"."%m"."%d" "%k":"%M":"%S):"执行命令：${MYSQLCOM} -e ${sqlcom}" | tee -a ${BAKFILE_LOG}
else		
	KEYWORD='SET timestamp='$MyTimestap
	myline=`grep -n  "${KEYWORD}"  ${SLOWLOG_PATH}/${SLOWLOG_FILE} | head -1 |awk -F ':' '{print $1}'`	
fi;		 	


##在系统慢日志极少，定时任务执行时间距离零点较久，这种循环的效率比较低
#for (( ; ; )) 
#do
#	KEYWORD='SET timestamp='$MyTimestap
	#echo "KEYWORD:"$KEYWORD
#	myline=`grep -n  "${KEYWORD}"  ${SLOWLOG_PATH}/${SLOWLOG_FILE} | head -1 |awk -F ':' '{print $1}'`	
#	if  [[ ${myline}'X' = 'X' && $MyTimestap<$CurrentTimestap ]];then
#		MyTimestap=`expr $MyTimestap + 1`
#	else		
#		break
#	fi;		 	
#done

if (( ${myline}>10 ));then
	realyline=`expr $myline - 5`
	echo $(date +%Y"."%m"."%d" "%k":"%M":"%S):"切分的行数查找结束，行数为："${realyline} | tee -a ${BAKFILE_LOG} 
	##产生备份文件
	cat  ${SLOWLOG_PATH}/${SLOWLOG_FILE} | head -${realyline} > ${SLOWLOG_BAKPATH}/${SLOWLOG_BAKFILE} 
	echo $(date +%Y"."%m"."%d" "%k":"%M":"%S):"产生慢日志备份文件："${SLOWLOG_BAKPATH}/${SLOWLOG_BAKFILE} | tee -a ${BAKFILE_LOG} 
	if [ -w "${SLOWLOG_PATH}/${SLOWLOG_FILE}" ]; then 
		sed -i '1,'${realyline}'d' ${SLOWLOG_PATH}/${SLOWLOG_FILE} 	
		echo $(date +%Y"."%m"."%d" "%k":"%M":"%S):"删除源文件完成" | tee -a ${BAKFILE_LOG} 
		${MYSQLCOM} -u${dbuser} -p${dbpass} -P${dbport} -h${dbhost} -e "${sqlcom}"   
		echo $(date +%Y"."%m"."%d" "%k":"%M":"%S):"执行命令：${MYSQLCOM} -e ${sqlcom}" | tee -a ${BAKFILE_LOG}
	fi;
fi;
}


function statiscSlowFile(){
	if [ -f "${SLOWLOG_BAKPATH}/${SLOWLOG_BAKFILE}" ]; then
		echo $(date +%Y"."%m"."%d" "%k":"%M":"%S):"慢日志分析开始":${SLOWLOG_BAKPATH}/${SLOWLOG_BAKFILE} | tee -a ${BAKFILE_LOG} 
		$DIGESTCOM ${SLOWLOG_BAKPATH}/${SLOWLOG_BAKFILE} > ${STATISC_FILE}
		echo $(date +%Y"."%m"."%d" "%k":"%M":"%S):"慢日志分析结束":${SLOWLOG_BAKPATH}/${SLOWLOG_BAKFILE} | tee -a ${BAKFILE_LOG}
		gzip ${SLOWLOG_BAKPATH}/${SLOWLOG_BAKFILE} 
                echo $(date +%Y"."%m"."%d" "%k":"%M":"%S):"gzip压缩原始慢日志":${SLOWLOG_BAKPATH}/${SLOWLOG_BAKFILE}.gz | tee -a ${BAKFILE_LOG}	 
	fi ;
	##删除历史文件
	find ${SLOWLOG_BAKPATH} -mtime +${delday} -exec rm -rf {} \;	
	echo $(date +%Y"."%m"."%d" "%k":"%M":"%S):"删除目录${delday}天前的数据，目录为":${SLOWLOG_BAKPATH} | tee -a ${BAKFILE_LOG} 
	##删除无意义的警告信息
	sed -i '/Using a password on the command line interface can be insecure/d' ${BAKFILE_ERROTLOG}	
}


##将分析日志保存到远程服务器上
## pt-query-digest  --limit 20 --history h='172.26.152.7',u=dba_remote,p=dba_remote,D=log,t=query_history --create-review-table  /var/lib/mysql/mysql-slow.log

##调用函数
time backupSlowFile 2>>${BAKFILE_ERROTLOG}
time statiscSlowFile 2>>${BAKFILE_ERROTLOG}


if [[ $(cat ${STATISC_FILE} | wc -l) -ne 0 ]];then
	${TOOL_PATH}/sendEmail -f ${mail_f} -t ${mail_t} -s ${mail_s} -a ${STATISC_FILE} -u "slowlog statisc" -xu ${mail_f} \
		-xp ${mail_p} -m " Host IP: ${IP} \nPlease check it!"  2>>${BAKFILE_ERROTLOG} | tee -a ${BAKFILE_LOG} 
fi




 
