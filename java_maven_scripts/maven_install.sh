#!/bin/bash

WORKDIR=$(cd $(dirname ${0});pwd)

VERSION='3.8.5'
MAVEN_ARCHIVE_NAME="apache-maven-${VERSION}-bin.tar.gz"
INSTALL_DIR='/usr/local'
LOCAL_REPO_NAME='repository'

MAVEN_ARCHIVE_PATH="${WORKDIR}/${MAVEN_ARCHIVE_NAME}"
ERROR_LOG_FILE='/tmp/'"$(echo $(basename ${0}) |sed 's/\..*$//g')"'_'"$(date +"%F_%T")"'.log'

# echo "${MAVEN_ARCHIVE_NAME%-bin*}"


source "${WORKDIR}/tools"


exist_check() {
    if which mvn &>/dev/null; then
        return 0
    fi
    return 1
}


if [ "${1}" != '--maven-f' ]; then
    if exist_check; then
        log_output 'error' "maven 已经安装. 如需覆盖安装使用 --maven-f 参数"
        exit 1
    fi
else
    log_output 'warn' "maven 已经存在, 将进行覆盖安装 !"
fi

log_output 'step.' "正在解压 ${MAVEN_ARCHIVE_NAME}"
if ! tar -xvf "${MAVEN_ARCHIVE_PATH}" -C "${INSTALL_DIR}" >/dev/null 2>>"${ERROR_LOG_FILE}"; then
    log_output 'error_file' "解压失败"
fi
log_output 'ok' "解压完成"
maven_install_path=$(find ${INSTALL_DIR} -maxdepth 1 -type d -iname "*maven*${VERSION}*")
local_repo_path="${maven_install_path}/${LOCAL_REPO_NAME}"
mkdir -p "${local_repo_path}"
chmod 777 "${local_repo_path}"
log_output 'step.' "正在配置环境变量"
{
tee -a /etc/profile <<-EOF
export MAVEN_HOME=${maven_install_path}
export PATH=\$PATH:\$MAVEN_HOME/bin
EOF
} >/dev/null
log_output 'ok' "环境变量配置完成"
log_output 'step.' "正在修改 settings.xml 配置文件"
eval "cat <<EOF
$(<./settings.xml)
EOF" >"${maven_install_path}/conf/settings.xml"
log_output 'ok' "配置文件修改完成"
log_output 'end' "maven-${VERSION} 部署完成. 请手动加载环境变量 /etc/profile"