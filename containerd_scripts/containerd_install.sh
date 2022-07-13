#!/bin/bash

WORKDIR=$(cd $(dirname ${0});pwd)

CONTAINERD_ARCHIVE_NAME="containerd-1.6.6-linux-amd64.tar.gz"
CRICTL_ARCHIVE_NAME="crictl-v1.24.1-linux-amd64.tar.gz"
NERDCTL_ARCHIVE_NANE="nerdctl-0.21.0-linux-amd64.tar.gz"
CNI_ARCHIVE_NAME="cni-plugins-linux-amd64-v1.1.1.tgz"
RUNC_NAME="runc.amd64"
CONTAINERD_ARCHIVE_PATH="${WORKDIR}/${CONTAINERD_ARCHIVE_NAME}"
CRICTL_ARCHIVE_PATH="${WORKDIR}/${CRICTL_ARCHIVE_NAME}"
NERDCTL_ARCHIVE_PATH="${WORKDIR}/${NERDCTL_ARCHIVE_NANE}"
CNI_ARCHIVE_PATH="${WORKDIR}/${CNI_ARCHIVE_NAME}"
RUNC_PATH="${WORKDIR}/${RUNC_NAME}"

# 本地私有仓库配置
LOCAL_REG_SCHEME="http"
LOCAL_REG_DNAME='172.5.1.109'
LOCAL_REG_PORT=''
LOCAL_REG_USER='admin'
LOCAL_REG_PASSWORD='harbor.123'
LOCAL_REG_SKIP_CERTCHECK='true'


INSTALL_DIR='/usr/local'
ERROR_LOG_FILE='/tmp/'"$(echo $(basename ${0}) |sed 's/\..*$//g')"'_'"$(date +"%F_%T")"'.log'

FORCE=0
INSTALL_NERDCTL=1
INSTALL_CRICTL=1
LOCAL_REG=0

# 使用 if 判断参数是否定义时使用
# OPT_ARRAY=(
#     '-f'
#     '--nerdctl'
#     '--no-crictl'
# )

set -eu

find /tmp -iname "$(echo $(basename ${0}) |sed 's/\..*$//g')*.log" -exec rm -rf {} \;

source "${WORKDIR}/tools"

for opt in "$@"; do
    # 使用 if 判断参数是否定义
    # if ! [[ "${OPT_ARRAY[*]}" =~ "${opt}" ]]; then
    #     log_output 'error' "${opt} 选项未定义"
    #     exit 1
    # fi
    case ${opt} in
        '-f')
            FORCE=1
        ;;
        '--no-nerdctl')
            INSTALL_NERDCTL=0
        ;;
        '--no-crictl')
            INSTALL_CRICTL=0
        ;;
        '--localreg')
            LOCAL_REG=1
        ;;
        *)
            echo "${opt} 选项未定义"
            # log_output 'error' "${opt} 选项未定义"
            exit 1
        ;;
    esac
done
# echo "-f : ${FORCE}"
# echo "--nerdctl : ${INSTALL_NERDCTL}"
# echo "--crictl  : ${INSTALL_CRICTL}"

if [ "${FORCE}" != '1' ] && exist_check "containerd"; then
    log_output 'error' "containerd 已经安装. 如需覆盖安装使用 -f 选项"
    exit 1
fi

log_output 'step.' "正在部署 containerd"
tar -xvf "${CONTAINERD_ARCHIVE_PATH}" -C "${INSTALL_DIR}" >/dev/null 2>>"${ERROR_LOG_FILE}"
log_output 'ok' "containerd 部署成功"
log_output 'step' "正在创建默认配置文件"
{
tee /usr/lib/systemd/system/containerd.service <<-'EOF'
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF
} >/dev/null
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml 2>>"${ERROR_LOG_FILE}"
log_output 'ok' "默认配置文件创建成功，位置 : /etc/containerd/config.toml"
log_output 'step' "正在修改配置文件"
sed -e "s#k8s.gcr.io#registry.cn-hangzhou.aliyuncs.com/google_containers#g" \
    -e 's#SystemdCgroup\ =\ false#SystemdCgroup\ =\ true#g' \
    -e '/registry.mirrors\]/a\ \ \ \ \ \ \ \ [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]\n\ \ \ \ \ \ \ \ \ \ endpoint = [\n\ \ \ \ \ \ \ \ \ \ \ \ "https://docker.mirrors.ustc.edu.cn/",\n\ \ \ \ \ \ \ \ \ \ \ \ "http://hub-mirror.c.163.com"\n\ \ \ \ \ \ \ \ \ \ ]' \
    -i /etc/containerd/config.toml >/dev/null 2>>"${ERROR_LOG_FILE}"
log_output 'ok' "配置文件修改成功"

log_output 'step.' "正在部署 runc "
\cp "${RUNC_PATH}" /usr/local/sbin/runc >/dev/null 2>>"${ERROR_LOG_FILE}"
chmod 755 /usr/local/sbin/runc
log_output 'ok' "runc 部署成功"

log_output 'step.' "正在部署 cni 网络插件"
mkdir -p /opt/cni/bin
tar -xvf "${CNI_ARCHIVE_PATH}" -C /opt/cni/bin >/dev/null 2>>"${ERROR_LOG_FILE}"
log_output 'ok' "cni 网络插件部署成功"

if [ "${INSTALL_CRICTL}" = '1' ]; then
    log_output 'step.' "正在部署 crictl"
    tar -xvf "${CRICTL_ARCHIVE_PATH}" -C /usr/local/bin >/dev/null 2>>"${ERROR_LOG_FILE}"
    log_output 'ok' "crictl 部署成功"
fi
log_output 'step' "创建 crictl 配置文件"
{
tee /etc/crictl.yaml <<-'EOF'
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
} >/dev/null

if [ "${INSTALL_NERDCTL}" = '1' ]; then
    log_output 'step.' "正在部署 nerdctl"
    tar -xvf "${NERDCTL_ARCHIVE_PATH}" -C /usr/local/bin/ >/dev/null 2>>"${ERROR_LOG_FILE}"
    log_output 'ok' "nerdctl 部署成功"
fi

systemctl --now enable containerd

log_output 'end' "containerd 部署成功"
