#! /bin/bash

ERLANG_RMP_PATH='./erlang-23.2.7-1.el7.x86_64.rpm'
RABBITMQ_RPM_PATH='./rabbitmq-server-3.8.20-1.el7.noarch.rpm'
DELAYED_MESSAGE_EXCHANGE_PLUGIN_PATH='rabbitmq_delayed_message_exchange-3.8.17.8f537ac.ez'
VERSION='3.8.20'

RABBITMQ_BASEDIR="/usr/lib/rabbitmq/lib/rabbitmq_server-${VERSION}/plugins/"
ERROR_LOG_FILE='/tmp/'"$(echo $(basename ${0}) |sed 's/\..*$//g')"'_'"$(date +"%F_%T")"'.log'
RABBITMQ_USER='rabbitmq-admin'
RABBITMQ_PWD='rabbitmq.123'


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
        '*')
            # 未定义日志
            echo -ne "[${LOG_DATE}]  [\033[1;37mUNKNOWN\033[0m]\t ${2}\n"
            # printf "[%s]  [\033[1;37mUNKNOWN\033[0m]\t %s\n" "${LOG_DATE}" "${2}"
        ;;
    esac
}

install() {
    if ! ([ -f ${ERLANG_RMP_PATH} ] && [ -f ${RABBITMQ_RPM_PATH} ]); then
        log_output 'error' "主要安装包缺失"
        exit 1
    fi

    log_output 'step' "开始安装 erlang"
    yum -y localinstall ${ERLANG_RMP_PATH} >/dev/null 2>>"${ERROR_LOG_FILE}"
    # rpm -q erlang &>/dev/null 
    if [ "$?" != '0' ]; then
        log_output 'error' "Erlang 安装失败, 需要人工干预. 错误日志位于 : ${ERROR_LOG_FILE}"
        exit 1
    fi
    log_output 'ok' "Erlang 安装成功"

    log_output 'step' "开始安装 rabbitmq-server"
    yum -y localinstall ${RABBITMQ_RPM_PATH} >/dev/null 2>>"${ERROR_LOG_FILE}"
    # rpm -q rabbitmq-server &>/dev/null
    if [ "$?" != '0' ]; then
        log_output 'error' "Rabbitmq-server 安装失败, 需要人工干预. 错误日志位于 : ${ERROR_LOG_FILE}"
        exit 1
    fi
    log_output 'ok' "Rabbitmq-server 安装成功"

    log_output 'step' "正在启动 Rabbitmq-server"
    systemctl --now enable rabbitmq-server >/dev/null 2>>${ERROR_LOG_FILE}
    if [ "$?" != '0' ]; then
        log_output 'error' "Rabbitmq-server 启动失败, 需要人工干预. 错误日志位于 : ${ERROR_LOG_FILE}"
        exit 1
    fi
    log_output 'ok' "Rabbitmq-server 启动成功"
    sleep 1

    log_output 'step' "开始创建用户"
    rabbitmqctl add_user "${RABBITMQ_USER}" "${RABBITMQ_PWD}" >/dev/null 2>${ERROR_LOG_FILE}
    if [ "$?" != '0' ]; then
        log_output 'error' "创建用户步骤出错. 错误日志位于 : ${ERROR_LOG_FILE}"
        exit 1
    fi
    rabbitmqctl set_user_tags "${RABBITMQ_USER}" administrator >/dev/null 2>${ERROR_LOG_FILE}
    if [ "$?" != '0' ]; then
        log_output 'error' "用户角色配置步骤出错. 错误日志位于 : ${ERROR_LOG_FILE}"
        exit 1
    fi
    rabbitmqctl set_permissions -p / "${RABBITMQ_USER}" ".*" ".*" ".*" >/dev/null 2>${ERROR_LOG_FILE}
    if [ "$?" != '0' ]; then
        log_output 'error' "用户授权步骤出错. 错误日志位于 : ${ERROR_LOG_FILE}"
        exit 1
    fi
    log_output 'ok' "rabbitmq 用户 \"${RABBITMQ_USER}\" 创建成功"
}

rpm -q rabbitmq-server &>/dev/null
if [ "$?" != 0 ]; then
    install
else
    log_output 'warn' "rabbitmq-server 已经存在"
fi

for args in "$@"; do
    # log_output 'debug' "参数 = ${args}"
    case ${args} in 
        'web')
            log_output 'step' "正在启用 rabbitmq_management 插件"
            rabbitmq-plugins enable rabbitmq_management >/dev/null 2>>${ERROR_LOG_FILE}
            if [ "$?" != '0' ]; then
                log_output 'error' "rabbitmq_management 插件启用失败, 错误日志位于 : ${ERROR_LOG_FILE}"
                continue
            fi
            log_output 'ok' "rabbitmq_management 插件启用成功"
        ;;
        'delayed_message')
            log_output 'step' "正在启用 rabbitmq_delayed_message_exchange 插件"
            cp ${DELAYED_MESSAGE_EXCHANGE_PLUGIN_PATH} ${RABBITMQ_BASEDIR}
            rabbitmq-plugins enable rabbitmq_delayed_message_exchange >/dev/null 2>>${ERROR_LOG_FILE}
            if [ "$?" != '0' ]; then
                log_output 'error' "rabbitmq_delayed_message_exchange 插件启用失败, 错误日志位于 : ${ERROR_LOG_FILE}"
                continue
            fi
            log_output 'ok' "rabbitmq_delayed_message_exchange 插件启用成功"
        ;;
        *)
            log_output 'error' "未知参数 ${args}"
            exit 1
        ;;
    esac
done
