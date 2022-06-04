#! /bin/bash

pid_count=$(ps -aux |grep -w '^haproxy' |grep -vEc "${0}|grep")
if [ "${pid_count}" != '0' ]; then
    exit 0
fi
port_count=$(ss -tlnp |grep -wc 'haproxy')
if [ "${port_count}" != '0' ]; then
    exit 0
fi
exit 1