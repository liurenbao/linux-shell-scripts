#!/bin/bash

WORKDIR=$(cd $(dirname ${0});pwd)

DOCKER_VERSION='latest'
REPO_FILE_URL='http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo'
DOCKER_COMPOSE_NAME='docker-compose-Linux-x86_64'
BIN_INSTALL_DIR='/usr/local/bin'

# ERROR_LOG_FILE='/tmp/'"$(echo $(basename ${0}) |sed 's/\..*$//g')"'_'"$(date +"%F_%T")"'.log'

FORCE=0

set -eu
find /tmp -iname "$(echo $(basename ${0}) |sed 's/\..*$//g')*.log" -exec rm -rf {} \;
source "${WORKDIR}/tools"

for opt in "$@"; do
    case ${opt} in
        '-f')
            FORCE=1
        ;;
        *)
            log_output 'error' "${opt} 选项未定义"
            exit 1
        ;;
    esac
done

if [ "${FORCE}" != '1' ] && exist_check "docker"; then
    log_output 'error' "docker 已经安装. 如需覆盖安装使用 -f 选项"
    exit 1
fi

log_output 'step.' "正在配置 docker yum 仓库"
wget -P /etc/yum.repos.d/ "${REPO_FILE_URL}" 1>/dev/null
log_output 'ok' "docker yum 仓库配置成功"
log_output 'step.' "正在安装 docker"
if [ "${DOCKER_VERSION}" = "latest" ]; then
    yum install -y docker-ce docker-ce-cli containerd.io 1>/dev/null
else
    yum install -y docker-ce-${DOCKER_VERSION} docker-ce-cli-${DOCKER_VERSION} containerd.io 1>/dev/null
fi
log_output 'ok' "docker 安装成功"
log_output 'step.' "正在安装 docker-compose"
\cp ${WORKDIR}/${DOCKER_COMPOSE_NAME} ${BIN_INSTALL_DIR}/docker-compose 1>/dev/null
chmod a+x ${BIN_INSTALL_DIR}/docker-compose
log_output 'step.' "配置镜像加速"
mkdir -p /etc/docker
{
tee /etc/docker/daemon.json <<EOF
{
    "registry-mirrors":[
        "http://hub-mirror.c.163.com"
    ]
}
EOF
} >/dev/null
log_output 'ok' "镜像加速配置成功"
log_output 'step.' "正在启动 docker"
systemctl --now enable docker 1>/dev/null
log_output 'ok' "docker 启动成功"
