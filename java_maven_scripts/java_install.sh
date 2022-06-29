#!/bin/bash

WORKDIR=$(cd $(dirname ${0});pwd)

VERSION='8u211'
JDK_ARCHIVE_NAME="jdk-${VERSION}-linux-x64.tar.gz"
JDK_ARCHIVE_PATH="${WORKDIR}/${JDK_ARCHIVE_NAME}"
INSTALL_DIR='/usr/local'
ERROR_LOG_FILE='/tmp/'"$(echo $(basename ${0}) |sed 's/\..*$//g')"'_'"$(date +"%F_%T")"'.log'


source "${WORKDIR}/tools"


exist_check() {
    if which java &>/dev/null; then
        return 0
    fi
    return 1
}


if [ "${1}" != '-f' ]; then
    if exist_check; then
        log_output 'error' "java 已经安装. 如需覆盖安装使用 -f 参数"
        exit 1
    fi
else
    log_output 'warn' "java 已经存在, 将进行覆盖安装 !"
fi
log_output 'step.' "正在解压 ${JDK_ARCHIVE_NAME}"
if ! tar -xvf "${JDK_ARCHIVE_PATH}" -C "${INSTALL_DIR}" >/dev/null 2>>"${ERROR_LOG_FILE}"; then
    log_output 'error_file' "解压失败"
    exit 1
fi
log_output 'ok' "解压完成"
jdk_path=$(find ${INSTALL_DIR} -maxdepth 1 -type d -iname "*${VERSION#*u}*" |head -1)
log_output 'step.' "正在配置环境变量"
{
tee -a /etc/profile <<-EOF
export JAVA_HOME=${jdk_path}
export CLASSPATH=\$JAVA_HOME/lib
export PATH=\$PATH:\$JAVA_HOME/bin
EOF
} >/dev/null
log_output 'ok' "环境变量配置完成"
log_output 'step.' "正在创建软链接"
if ! ln -sf "${jdk_path}"/bin/* /usr/bin/ >/dev/null 2>>"${ERROR_LOG_FILE}"; then
    echo
    log_output 'error_file' "软连接创建失败"
    exit 1
fi
log_output 'ok' "软链接创建完成"
log_output 'end' "jdk-${VERSION} 部署完成"
