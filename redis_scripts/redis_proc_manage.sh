#! /bin/bash

REDIS_PORT_ARRAY=($@)
# echo $REDIS_PORT
REDIS_RUN_USER='redis'
REDIS_DIR='/redis_data'
REDIS_PID_FILE='redis.pid'
REDIS_CONFIG_FILE='redis.conf'
REDIS_DEFAULT_PORT='6379'
ERROR_LOG_FILE='/tmp/'"$(echo $(basename ${0}) |sed 's/\..*$//g')"'_'"$(date +"%F_%T")"'.log'

log_output() {
    # 参数 1 : 日志类型
    # 参数 2 : 日志内容
    LOG_DATE=$(date +"%F_%T")
    LOG_TYPE=$(echo "${1}" |tr '[A-Z]' '[a-z]')
    case ${LOG_TYPE} in
        'error')
            # 错误日志
            echo -ne "[${LOG_DATE}]  [\033[1;5;31mERROR\033[0m]\t ${2}\n"
            # printf "[%s]  [\033[1;5;31mERROR\033[0m]\t %s\n" "${LOG_DATE}" "${2}"
        ;;
        'info')
            # 信息日志
            echo -ne "[${LOG_DATE}]  [\033[1;36mINFO\033[0m]\t ${2}\n"
            # printf "[%s]  [\033[1;36mINFO\033[0m]\t %s\n" "${LOG_DATE}" "${2}"
        ;;
        'warn')
            # 警告日志
            echo -ne "[${LOG_DATE}]  [\033[1;33mWARN\033[0m]\t ${2}\n"
            # printf "[%s]  [\033[1;33mWARN\033[0m]\t %s\n" "${LOG_DATE}" "${2}"
        ;;
        'ok')
            # 成功、完成日志
            echo -ne "[${LOG_DATE}]  [\033[1;32mOK\033[0m]\t ${2}\n"
            # printf "[%s]  [\033[1;32mOK\033[0m]\t %s\n" "${LOG_DATE}" "${2}"
        ;;
        'step')
            # 步骤日志
            echo -ne "[${LOG_DATE}]  [\033[1;37m>>>>>\033[0m]\t ${2}\n"
            # printf "[%s]  [\033[1;37m>>>>>\033[0m]\t %s\n" "${LOG_DATE}" "${2}"
        ;;
        'end')
            # 结束日志
            echo -ne "[${LOG_DATE}]  [\033[1;37mEND\033[0m]\n"
            # printf "[%s]  [\033[1;37mEND\033[0m]\n" "${LOG_DATE}"
        ;;
        'debug')
            # debug 日志
            echo -ne "[${LOG_DATE}]  [\033[46;5;1mDEBUG\033[0m]\t ${2}\n"
            # printf "[%s]  [\033[46;5;1mDEBUG\033[0m]\t %s\n" "${LOG_DATE}" "${2}"
        ;;
        *)
            # 未定义日志
            echo -ne "[${LOG_DATE}]  [\033[1;37mUNKNOWN\033[0m]\t ${2}\n"
            # printf "[%s]  [\033[1;37mUNKNOWN\033[0m]\t %s\n" "${LOG_DATE}" "${2}"
        ;;
    esac
}

stop() {
    port=${1}
    log_output 'step' "正在停止 ${port} 端口实例"
    # log_output 'debug' "端口 = ${port}"
    REDIS_PID_FILE_PATH="${REDIS_DIR}"'/'"${port}"'/'"${REDIS_PID_FILE}"
    # log_output 'debug' "PID文件路径 = ${REDIS_PID_FILE_PATH}"
    if [ -f "${REDIS_PID_FILE_PATH}" ]; then
        count=0
        while true; do
            [ -f "${REDIS_PID_FILE_PATH}" ] && kill $(cat ${REDIS_PID_FILE_PATH}) && sleep 0.5 || break
            count=$(( count + 1 ))
            [[ $count = 10 ]] && kill -9 $(cat ${REDIS_PID_FILE_PATH})
            if ! [ -f ${REDIS_PID_FILE_PATH} ]; then
                log_output 'ok' "成功停止 ${port} 端口实例"
                break
            fi
        done
    else
        while true; do
            redis_pid=$(netstat -tlnp 2>/dev/null |grep -w "${port}" |awk -F '/' 'NR==1{print $1}' |awk '{print $NF}')
            if [ "${redis_pid}" != '' ]; then
                kill "${redis_pid}"
                is_kill=1
                sleep 0.5
            else
                [[ $is_kill = 1 ]] && log_output 'ok' "成功停止 ${port} 端口实例" || log_output 'warn' "${port} 端口实例未运行"
                break
            fi
        done
    fi
    # return 0
}

start() {
    port=${1}
    log_output 'step' "正在启动 ${port} 端口实例"
    REDIS_CONFIG_FILE_PATH="${REDIS_DIR}"'/'"${port}"'/'"${REDIS_CONFIG_FILE}"
    REDIS_PID_FILE_PATH="${REDIS_DIR}"'/'"${port}"'/'"${REDIS_PID_FILE}"
    if [ -f "${REDIS_CONFIG_FILE_PATH}" ]; then
        su - -s /bin/bash -c "redis-server ${REDIS_CONFIG_FILE_PATH}" ${REDIS_RUN_USER} 2> ${ERROR_LOG_FILE}
        if [ "$?" != '0' ]; then
            log_output 'error' "${port} 端口实例启动失败, 请人工干预. 错误日志存储在 : ${ERROR_LOG_FILE}"
            return 1
        fi
        sleep 0.5
        log_output 'ok' "${port} 端口实例启动成功, PID : $(cat "${REDIS_PID_FILE_PATH}")"
        return 0
    fi
    log_output 'error' "没有找到 ${port} 端口实例的配置文件"
}

status() {
    port=${1}
    REDIS_PID_FILE_PATH="${REDIS_DIR}"'/'"${port}"'/'"${REDIS_PID_FILE}"
    redis_pid=$(netstat -tlnp 2>/dev/null |grep -w "${port}" |awk -F '/' 'NR==1{print $1}' |awk '{print $NF}')
    if [ -f "${REDIS_PID_FILE_PATH}" ] || [ "${redis_pid}" != '' ]; then
        log_output 'info' "${port} 端口实例正在运行 (\033[1;32mActive\033[0m)"
        return
    fi
    log_output 'info' "${port} 端口实例未运行 (\033[1;31mInActive\033[0m)"
}

ARRAY_LEN=${#REDIS_PORT_ARRAY[@]}
if [[ ${ARRAY_LEN} = 0 ]]; then
    log_output 'error' '至少需指定最后一个参数为 stop、start 或 restart'
    exit 1
fi

if [[ ${ARRAY_LEN} = 1 ]]; then
    if ! [[ ${REDIS_PORT_ARRAY[0]} =~ start|stop|restart|status ]]; then
        log_output 'error' '至少需指定最后一个参数为 stop、start 或 restart'
        exit 1
    fi
    REDIS_PORT_ARRAY=($REDIS_DEFAULT_PORT ${REDIS_PORT_ARRAY[0]})
    ARRAY_LEN=2
fi

# log_output 'debug' "参数列表 = ${REDIS_PORT_ARRAY[*]}"
log_output 'debug' "端口列表 = $( for index in $(seq 0 $(( ${ARRAY_LEN} - 2 )));do echo -ne "${REDIS_PORT_ARRAY[index]} ";done )"

OPERATION=${REDIS_PORT_ARRAY[${ARRAY_LEN} - 1]}
log_output 'debug' "操作 = ${OPERATION}"

for port in "${REDIS_PORT_ARRAY[@]}"; do
    if [ "${port}" != '' ] && ! [[ "${port}" =~ [^0-9] ]]; then
        case "${OPERATION}" in 
            'stop')
                stop "${port}"
                # log_output 'debug' "stop is ${port}"
            ;;
            'start')
                start "${port}"
                # log_output 'debug' "start is ${port}"
            ;;
            'restart')
                stop "${port}"
                start "${port}"
                # log_output 'debug' "restart is ${port}"
            ;;
            'status')
                status "${port}"
                # log_output 'debug' "status is ${port}"
            ;;
            *)
                log_output 'error' "\"${OPERATION}\" 不是一个有效的操作"
                exit 1
            ;;
        esac
        continue
    fi
    [[ "${port}" =~ start|stop|resatrt|status ]] || log_output 'error' "${port} 不是一个正确的端口"
    # stop "${port}"
done