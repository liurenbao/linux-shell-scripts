#! /bin/bash

NGINX_VERSION='1.20.1'
NGINX_ARCHIVE_NAME="nginx-${NGINX_VERSION}.tar.gz"

NGINX_RUN_USER='www'
NGINX_INSTALL_DIR='/usr/local/nginx'
NGINX_CONFIG_DIR='/etc/nginx'
NGINX_LOG_DIR='/var/log/nginx'
NGINX_RUN_DIR='/var/run'
NGINX_DEFAULT_SERVER_CONFIG='default.conf'
NGINX_UNIT_SERVICE='nginx.service'

NGINX_CONFIG_FILE="${NGINX_CONFIG_DIR}/nginx.conf"
NGINX_OTHER_CONFIG_DIR="${NGINX_CONFIG_DIR}/conf.d"
NGINX_STREAM_CONFIG_DIR="${NGINX_CONFIG_DIR}/stream.d"
NGINX_PID_FILE="${NGINX_RUN_DIR}/nginx.pid"
NGINX_LOCK_FILE="${NGINX_RUN_DIR}/nginx.lock"

NGINX_WORK_PROC='auto'
NGINX_WORK_CONNECT='3072'

WORK_DIR=$(cd $(dirname ${0});pwd)
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
        'error_file')
            # 错误日志
            echo -ne "[${LOG_DATE}]  [\033[1;5;31mERROR\033[0m]\t ${2}, 日志文件位于 : ${ERROR_LOG_FILE}\n"
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
        'step.')
            # 步骤日志
            echo -ne "[${LOG_DATE}]  [\033[1;37m>>>>>\033[0m]\t ${2}......\n"
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


log_output 'step.' "正在安装依赖包"
yum install -y pcre-devel zlib-devel openssl-devel >/dev/null 2>>"${ERROR_LOG_FILE}"
[ "$?" != '0' ] && log_output 'error_file' "依赖包安装失败" && exit 1
log_output 'ok' "依赖包安装成功"

log_output 'step.' "正在创建 ${NGINX_RUN_USER} 用户"
if id ${NGINX_RUN_USER} &>/dev/null; then
    log_output 'warn' "${NGINX_RUN_USER} 用户已存在, 将继续使用 ${NGINX_RUN_USER} 用户配置 nginx"
else
    useradd -M -s /sbin/nologin ${NGINX_RUN_USER} >/dev/null 2>>"${ERROR_LOG_FILE}"
    [ "$?" != '0' ] && log_output 'error_file' "${NGINX_RUN_USER} 用户创建失败" && exit
    log_output 'ok' "用户 ${NGINX_RUN_USER} 创建成功"
fi

log_output 'step.' "正在解压 ${NGINX_ARCHIVE_NAME}"
tar -xvf "${WORK_DIR}/${NGINX_ARCHIVE_NAME}" >/dev/null 2>>${ERROR_LOG_FILE}
[ "$?" != '0' ] && log_output 'error_file' "解压失败" && exit 1
log_output 'ok' "解压成功"

log_output 'step.' "正在预编译"
cd ${NGINX_ARCHIVE_NAME%\.tar\.gz*} &>/dev/null || (log_output 'error' "进入 ${NGINX_ARCHIVE_NAME%\.tar\.gz*} 目录失败" && exit 1)
./configure \
--prefix=${NGINX_INSTALL_DIR} \
--modules-path=${NGINX_INSTALL_DIR}/modules \
--conf-path=${NGINX_CONFIG_FILE} \
--error-log-path=${NGINX_LOG_DIR}/error.log \
--http-log-path=${NGINX_LOG_DIR}/access.log \
--pid-path=${NGINX_PID_FILE} \
--lock-path=${NGINX_LOCK_FILE} \
--user=${NGINX_RUN_USER} \
--group=${NGINX_RUN_USER} \
--with-compat \
--with-threads \
--with-http_addition_module \
--with-http_auth_request_module \
--with-http_dav_module \
--with-http_flv_module \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_mp4_module \
--with-pcre \
--with-http_random_index_module \
--with-http_realip_module \
--with-http_secure_link_module \
--with-http_slice_module \
--with-http_ssl_module \
--with-http_stub_status_module \
--with-http_sub_module \
--with-http_v2_module \
--with-mail \
--with-mail_ssl_module \
--with-stream \
--with-stream_realip_module \
--with-stream_ssl_module \
--with-stream_ssl_preread_module >>"${ERROR_LOG_FILE}" 2>>"${ERROR_LOG_FILE}"
[ "$?" != '0' ] && log_output 'error_file' "预编译失败" && exit 1
log_output 'ok' "预编译成功"

log_output 'step.' "开始编译"
make -j "$(nproc)" >/dev/null 2>>"${ERROR_LOG_FILE}"
[ "$?" != '0' ] && log_output 'error_file' "编译失败" && exit 1
log_output 'ok' "编译成功"

log_output 'step.' "开始安装"
make install >/dev/null 2>>"${ERROR_LOG_FILE}"
[ "$?" != '0' ] && log_output 'error_file' "安装失败" && exit 1
log_output 'ok' "安装成功"

log_output 'step.' "正在整理相关文件"
cd "${WORK_DIR}" || (log_output 'error' "切换工作目录 ${WORK_DIR} 失败" && exit 1)
ln -sf /usr/local/nginx/sbin/nginx /usr/sbin/nginx
\mv /etc/nginx/nginx.conf{,.bak}
mkdir -p ${NGINX_OTHER_CONFIG_DIR}
mkdir -p ${NGINX_STREAM_CONFIG_DIR}
eval "cat <<EOF
$(<${WORK_DIR}/nginx.conf)
EOF" >"${NGINX_CONFIG_FILE}"
\cp -a "${NGINX_DEFAULT_SERVER_CONFIG}" "${NGINX_OTHER_CONFIG_DIR}"
echo "<h2>$(hostname) - $(ip a |grep -w "inet" |grep -wE 'eth0|eth1|ens.*' |sed -r -n -e '1 s/^[^0-9]+([0-9\.]+).*$/\1/g p')</h2>" \
    >${NGINX_INSTALL_DIR}/html/index-hostinfo.html
\cp -a "${NGINX_UNIT_SERVICE}" /etc/systemd/system
log_output 'ok' "文件整理完成"

log_output 'step.' "正在启动 nginx"
systemctl daemon-reload
systemctl --now enable nginx >/dev/null 2>>"${ERROR_LOG_FILE}"
[ "$?" != '0' ] && log_output 'error_file' "nginx 启动失败" && exit 1
log_output 'ok' "nginx 启动成功, PID : $(cat ${NGINX_PID_FILE})"
log_output 'end'
