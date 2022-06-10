#! /bin/bash

BASE_DIR=$(cd $(dirname ${0});pwd)

VERSION='2.1.0'
NACOS_ARCHIVE_NAME="nacos-server-${VERSION}.tar.gz"
INSTALL_DIR='/usr/local'
ERROR_LOG_FILE='/tmp/'"$(echo $(basename ${0}) |sed 's/\..*$//g')"'_'"$(date +"%F_%T")"'.log'

source "tools"

log_output 'step.' "正在解压 ${NACOS_ARCHIVE_NAME}"
if ! tar -xvf "${NACOS_ARCHIVE_NAME}" -C "${INSTALL_DIR}" >/dev/null 2>>"${ERROR_LOG_FILE}"; then
    log_output 'error_file' "解压失败"
    exit 1
fi
log_output 'ok' "解压完成"
nacos_install_path="${INSTALL_DIR}/nacos"
log_output 'step.' "正在更改配置文件"
if [ "${1}" = '--cluster' ]; then
    if ! \cp -a cluster.conf ${nacos_install_path}/conf >/dev/null 2>>"${ERROR_LOG_FILE}"; then
        log_output 'error_file' "集群配置修改失败"
        exit 1
    fi
    log_output 'ok' "集群配置修改完成"
fi
if ! \cp -a startup-2.1.0.sh ${nacos_install_path}/bin/startup.sh >/dev/null 2>>${ERROR_LOG_FILE}; then
    log_output 'error_file' "启动脚本修改失败"
    exit 1
fi
log_output 'ok' "启动脚本修改成功"
log_output 'step.' "正在创建 nacos 用户"
if id nacos &>/dev/null; then
    log_output 'warn' "nacos 用户已存在, 将继续使用该用户运行 nacos"
else
    if ! useradd -M -s /sbin/nologin nacos >/dev/null 2>>"${ERROR_LOG_FILE}"; then
        log_output 'error_file' "nacos 用户创建失败"
        exit 1
    fi
    log_output 'ok' "nacos 用户创建完成"
fi
chown -R nacos.nacos ${nacos_install_path}
log_output 'step.' "正在启动 nacos"
if [ "${1}" = '--cluster' ]; then
    "${nacos_install_path}/bin/startup.sh" -p embedded &>"${ERROR_LOG_FILE}"
else
    "${nacos_install_path}/bin/startup.sh" -m standalone &>"${ERROR_LOG_FILE}"
fi
pid=$(ps -aux |grep 'java.*naco[s]' |awk 'NR==1{print $2}')
if [ "$(echo $pid |tr -d [0-9])" = '' ]; then
    log_output 'error' "无法确定启动状态"
else
    log_output 'ok' "启动成功. PID : ${pid}"
fi
log_output 'end' "nacos-${VERSION} 部署完成"















