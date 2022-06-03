#!/bin/sh
# Usage : redis_install.sh <redis_port> [redis_port2] [redis_portN]

VERSION=6.2.6
REDIS_RUN_USER='redis'
REDIS_PORT_LIST=($@)
REDIS_AUTH_PWD='redis.123'
REDIS_DATA_PATH='/redis_data'
SRC_PATH='/opt/src'
FILE_PATH=$(dirname "$0")
ERR_LOG_FILE=/tmp/redis_install_scripts-$(date +"%F").log

# 内网地址网段，用于获取执行脚本的主机内网 IP 地址
IP_FIELD='172.5.1'
REDIS_BIND_IP=$(ifconfig |grep ${IP_FIELD} |head -1 |awk '{print $2}')

log_output() {
    # 参数 1 : 日志类型
    # 参数 2 : 日志内容
    LOG_DATE=$(date +"%F_%T")
    LOG_TYPE=$(echo ${1} |tr '[A-Z]' '[a-z]')
    case ${LOG_TYPE} in
        'error')
            # 错误日志
            printf "[%s] [\033[1;5;31mERROR\033[0m] %s\n" "${LOG_DATE}" "${2}"
        ;;
        'info')
            # 信息日志
            printf "[%s] [\033[1;36mINFO\033[0m] %s\n" "${LOG_DATE}" "${2}"
        ;;
        'warn')
            # 警告日志
            printf "[%s] [\033[1;33mWARN\033[0m] %s\n" "${LOG_DATE}" "${2}"
        ;;
        'ok')
            # 成功、完成日志
            printf "[%s] [\033[1;32mOK\033[0m] %s\n" "${LOG_DATE}" "${2}"
        ;;
        'step')
            # 步骤日志
            printf "[%s] [\033[1;37m>>>>>\033[0m] %s\n" "${LOG_DATE}" "${2}"
        ;;
        'end')
            # 结束日志
            printf "[%s] [\033[1;37mEND\033[0m]\n" "${LOG_DATE}"
        ;;
        '*')
            # 未定义日志
            printf "[%s] [\033[1;37mUNKNOWN\033[0m] %s\n" "${LOG_DATE}" "${2}"
        ;;
    esac
}

install_redis() {
    log_output 'step' "正在创建 redis 运行用户"
    id ${REDIS_RUN_USER} >/dev/null 2>&1 || useradd -M -s /sbin/nologin ${REDIS_RUN_USER}

    log_output 'step' "开始编译安装 redis"
    which redis-server >/dev/null 2>&1 && log_output 'info' "redis 已安装 : $(redis-server --version)" && return

    log_output 'step' "正在创建源码存放目录 : ${SRC_PATH}"
    [ -d "${SRC_PATH}/redis-${VERSION}" ] && mv ${SRC_PATH}/redis-${VERSION}{,_bak} || mkdir -p ${SRC_PATH}
    
    log_output 'step' "正在解压源码包 : ${FILE_PATH}/redis-${VERSION}.tar.gz"
    tar -xf "${FILE_PATH}/redis-${VERSION}.tar.gz" -C "${SRC_PATH}" >>/dev/null 2>"${ERR_LOG_FILE}"
    [ $? != '0' ] && log_output 'error' "解压失败，请检查压缩包完整性 (code:1)" && exit 1 
    
    log_output 'step' "正在编译安装 redis"
    cd ${SRC_PATH}/redis-${VERSION} && make >/dev/null 2>>"${ERR_LOG_FILE}" && make install >/dev/null 2>>"${ERR_LOG_FILE}"
    [ $? != 0 ] && log_output 'error' "编译安装 redis 失败, 需要人工干预 (code:2)" && exit 2
    log_output 'ok' "redis 编译安装完成"
}

example_create() {
    log_output 'step' "开始创建实例 : ${1}"
    if [ -d "${REDIS_DATA_PATH}/${1}" ];then
        log_output 'info' "实例 : ${1} 已存在, 已将其备份并重新创建"
        ps -aux |grep redis-server |grep ${1} |awk '{print $2}' |xargs kill -9 >>"${ERR_LOG_FILE}" 2>&1
        sleep 2
        if [ -d ${REDIS_DATA_PATH}/${1}_bak ] && [ ${REDIS_DATA_PATH}/${1} != '/' ];then
            rm -rf ${REDIS_DATA_PATH}/${1}_bak
        fi
        mv ${REDIS_DATA_PATH}/${1}{,_bak}
    fi
    mkdir -p "${REDIS_DATA_PATH}/${1}/logs"
    {
        printf 'daemonize yes\n'
        printf 'bind 127.0.0.1 %s\n' "${REDIS_BIND_IP}"
        printf 'port %s\n' "${1}"
        printf 'pidfile %s\n' "${REDIS_DATA_PATH}/${1}/redis.pid"
        printf 'logfile %s\n' "${REDIS_DATA_PATH}/${1}/logs/redis.log"
        printf 'dir %s\n' "${REDIS_DATA_PATH}/${1}"
        printf 'requirepass %s\n' "${REDIS_AUTH_PWD}"
        printf 'dbfilename redis.rdb\n'
        printf 'databases 16\n'
    } >${REDIS_DATA_PATH}/${1}/redis.conf
    chown -R ${REDIS_RUN_USER}.${REDIS_RUN_USER} ${REDIS_DATA_PATH}

    log_output 'step' "启动实例 : ${1}"
    sleep 2
    sudo su - -s /bin/bash -c "redis-server ${REDIS_DATA_PATH}/${1}/redis.conf" redis >>"${ERR_LOG_FILE}" 2>&1
    [ $? == 0 ] && sleep 1 && log_output 'ok' "实例 : ${1} 创建完成, 已启动. PID : $(cat ${REDIS_DATA_PATH}/${1}/redis.pid)" && return
    log_output 'warn' "实例 : ${1} 已创建, 但没有启动成功. 详细信息查阅日志 : ${ERR_LOG_FILE}"
}

# main 部分
> ${ERR_LOG_FILE}
install_redis
if [ $# != '0' ];then
    for index in $( seq 0 $(( ${#}-1 )) );do
        if [ -n "$(echo ${REDIS_PORT_LIST[$index]}|sed "s/[0-9]//g")" ];then
            log_output 'warn' "参数 : ${REDIS_PORT_LIST[$index]} 不是一个正确的端口号"
            continue
        fi
        example_create ${REDIS_PORT_LIST[$index]}
    done
else
    log_output 'warn' "没有指定 redis 端口，将使用默认端口 : 6379 创建实例"
    example_create 6379
fi
log_output 'end'