#! /bin/bash

BASE_DIR=$(cd $(dirname ${0});pwd)

VERSION='2.1.0'
NACOS_ARCHIVE_NAME="nacos-server-${VERSION}.tar.gz"
NACOS_ARCHIVE_PATH="${BASE_DIR}/${NACOS_ARCHIVE_NAME}"
INSTALL_DIR='/usr/local'
ERROR_LOG_FILE='/tmp/'"$(echo $(basename ${0}) |sed 's/\..*$//g')"'_'"$(date +"%F_%T")"'.log'

MYSQL_HOST='172.5.1.100'
MYSQL_PORT='3306'
MYSQL_USERNAME='mysql'
MYSQL_PASSWORD='mysql.123'

source "${BASE_DIR}/tools"

log_output 'step.' "正在解压 ${NACOS_ARCHIVE_NAME}"
if ! tar -xvf "${NACOS_ARCHIVE_PATH}" -C "${INSTALL_DIR}" >/dev/null 2>>"${ERROR_LOG_FILE}"; then
    log_output 'error_file' "解压失败"
    exit 1
fi
log_output 'ok' "解压完成"
nacos_install_path="${INSTALL_DIR}/nacos"

if [ "${1}" = '--cluster' ]; then
    log_output 'step.' "正在配置集群数据库"
    chmod +x "${BASE_DIR}/mysql"
    chmod +x "${BASE_DIR}/mysqldump"
    if ! "${BASE_DIR}/mysql" -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} -e 'use nacos_config;' >/dev/null 2>>"${ERROR_LOG_FILE}"; then
        # log_output 'warn' "数据库已存在, 旧库备份到 ${BASE_DIR}/nacos_config-old-backup.sql"
        # if ! "${BASE_DIR}/mysqldump" -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} nacos_config >"${BASE_DIR}/nacos_config-old-backup.sql" 2>>"${ERROR_LOG_FILE}"; then
        #         log_output 'error_file' "旧数据库导出失败"
        #         exit 1
        # fi
        # if ! "${BASE_DIR}/mysql" -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} -e 'drop database nacos_config;' >/dev/null 2>>"${ERROR_LOG_FILE}"; then
        #         log_output 'error_file' "旧数据库删除失败"
        #         exit 1
        # fi
        log_output 'step.' "正在导入数据"
        if ! "${BASE_DIR}/mysql" -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} -e 'create database nacos_config;' >/dev/null 2>>"${ERROR_LOG_FILE}"; then
            log_output 'error_file' "创建 nacos_config 数据库失败"
            exit 1
        fi
        if ! "${BASE_DIR}/mysql" -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} nacos_config <${nacos_install_path}/conf/nacos-mysql.sql >/dev/null 2>>"${ERROR_LOG_FILE}"; then
            log_output 'error_file' "数据导入失败"
            exit 1
        fi
        log_output 'ok' '数据库导入完成'
    fi
fi
log_output 'step.' "正在更改配置文件"
if [ "${1}" = '--cluster' ]; then
    if ! \cp -a "${BASE_DIR}/cluster.conf" "${nacos_install_path}/conf" >/dev/null 2>>"${ERROR_LOG_FILE}"; then
        log_output 'error_file' "集群配置修改失败"
        exit 1
    fi
    log_output 'ok' "集群配置修改完成"
    \cp -a "${BASE_DIR}/application.properties" "${nacos_install_path}/conf/application.properties"
    sed -e "s/-{{MYSQL_HOST}}-/${MYSQL_HOST}/g" \
        -e "s/-{{MYSQL_PORT}}-/${MYSQL_PORT}/g" \
        -e "s/-{{MYSQL_USERNAME}}-/${MYSQL_USERNAME}/g" \
        -e "s/-{{MYSQL_PASSWORD}}-/${MYSQL_PASSWORD}/g" \
        -i.bak "${nacos_install_path}/conf/application.properties"
fi
# if ! \cp -a "${BASE_DIR}/startup-2.1.0.sh" ${nacos_install_path}/bin/startup.sh >/dev/null 2>>"${ERROR_LOG_FILE}"; then
if ! \cp -a "${BASE_DIR}/startup-2.1.0.sh" ${nacos_install_path}/bin/startup.sh >/dev/null 2>>"${ERROR_LOG_FILE}"; then
    log_output 'error_file' "启动脚本修改失败"
    exit 1
fi
chmod +x "${nacos_install_path}/bin/startup.sh"
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
    "${nacos_install_path}/bin/startup.sh" &>>"${ERROR_LOG_FILE}"
    # log_output 'warn' "集群模式请手动启动"
else
    "${nacos_install_path}/bin/startup.sh" -m standalone &>>"${ERROR_LOG_FILE}"
fi
[ "$?" != '0' ] && log_output 'error_file' "启动失败" && exit 1
sleep 2
pid=$(ps -aux |grep 'java.*naco[s]' |awk 'NR==1{print $2}')
if [ "${pid}" != '' ] && [ "$(echo $pid |tr -d [0-9])" = '' ]; then
    log_output 'ok' "启动成功. PID : ${pid}"
else
    log_output 'error' "无法确定启动状态"
fi
log_output 'end' "nacos-${VERSION} 部署完成"
