#!/bin/sh
set -x  # 开启跟踪

#查看redis-server进程号：
lsof -i:"$REDIS_PORT" -t

#杀死 Master 节点上redis-server的进程号
kill -9 "$(lsof -i:"$REDIS_PORT" -t)"			#Master节点上redis-server的进程号

cat /home/redis/logs/sentinel.log

set +x  # 关闭跟踪
