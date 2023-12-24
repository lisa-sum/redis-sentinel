#!/bin/sh
set -x  # 开启跟踪

if [ -z $REDIS_HOME ] || [ -z "$MASTER_NAME" ] || [ -z "$MASTER_IP" ] || [ -z "$SLAVE_QUORUM" ] || [ -z "$REDIS_PORT" ] || [ -z "$REDIS_PASSWORD" ]; then
  echo "请定义 MASTER_NAME 和 MASTER_IP 和 SLAVE_NUMBER 和 REDIS_PORT 和 REDIS_PASSWORD变量!"
  echo 以下变量的输出如果为空则没有定义, 请定义变量后再运行脚本
  echo REDIS_HOME的值是: "$REDIS_HOME"
  echo MASTER_NAME的值是: "$MASTER_NAME"
  echo MASTER_IP的值是: "$MASTER_IP"
  echo SLAVE_NUMBER的值是: "$SLAVE_QUORUM"
  echo REDIS_PORT的值是: "$REDIS_PORT"
  echo REDIS_PASSWORD的值是: "$REDIS_PASSWORD"
  exit 1
fi

# 进入redis目录
echo "进入redis目录"
cd "$REDIS_HOME" || exit

# 拷贝sentinel.conf
echo "拷贝sentinel.conf"
cp /home/redis/redis-stable/sentinel.conf conf/

# 修改sentinel.conf
echo "修改sentinel.conf"
cat > /home/redis/conf/sentinel.conf  << EOF
# 关闭保护模式
protected-mode no

port $SENTINEL_PORT

# 指定sentinel为后台启动
daemonize yes

# 指定 PID 文件
pidfile /var/run/redis-sentinel.pid

# 指定日志文件
logfile "/home/redis/logs/sentinel.log"

# 如果指定了用户名，那么就需要指定密码
# sentinel auth-user <master-name> <username>
sentinel auth-user $MASTER_NAME $REDIS_PASSWORD

# 语法: sentinel auth-pass <master-name> <password>
# 如果指定了密码，那么就需要指定auth-pass
sentinel auth-pass $MASTER_NAME $REDIS_PASSWORD

# 告诉 Redis 监视的主节点IP,端口,从节点数量
# $MASTER_NAME: 主节点的名字
# $MASTER_HOST: 主节点的IP
# $SLAVE_QUORUM: 仲裁值. 仲裁值是需要无法访问主服务器这一事实达成一致的哨兵数量，以便真正将主服务器标记为失败，并在可能的情况下最终启动故障转移过程,
# 仅用于检测故障。为了实际执行故障转移，需要将其中一个哨兵选为故障转移的领导者，并被授权继续。这只有在大多数 Sentinel 进程的投票下才会发生
# 例如，如果有5个Sentinel哨兵进程，并且给定主进程的仲裁设置为值 2，则会发生以下情况：
# - 如果两个哨兵同时同意无法访问主节点，则两个哨兵中的一个将尝试启动故障转移。
# - 如果总共至少有三个哨兵可访问，则故障转移将获得授权并实际启动。
# 实际上，这意味着在故障期间，如果大多数 Sentinel 进程无法通信（即少数分区中没有故障转移），则 Sentinel 永远不会启动故障转
sentinel monitor $MASTER_NAME $MASTER_HOST $SLAVE_QUORUM

# 判定服务器down掉的时间周期，默认30000毫秒（30秒）
# 是 Sentinel 开始认为它已关闭时，实例不应访问的时间（以毫秒为单位）（要么不回复我们的 PING，要么回复错误）
sentinel down-after-milliseconds $MASTER_NAME 3000

# 同一个sentinel对同一个master两次failover之间的间隔时间（180秒）
sentinel failover-timeout $MASTER_NAME 180000

# 设置在故障转移后可重新配置为使用新主服务器的副本数。数字越小，完成故障转移过程所需的时间就越长，但是，如果将副本配置为提供旧数据，则可能不希望所有副本同时与主副本重新同步。虽然复制过程对于副本来说基本上是非阻塞的，但有时它会停止从主服务器加载批量数据。您可能希望通过将此选项设置为值 1 来确保一次只能访问一个副本。
# 语法: sentinel parallel-syncs <master-name> <num-slaves>
sentinel parallel-syncs $MASTER_NAME 5
EOF

# 启动哨兵
echo "启动哨兵"
redis-sentinel /home/redis/conf/sentinel.conf &

# 查看哨兵信息
echo "查看哨兵信息"
redis-cli -h "$MASTER_IP" -a "$REDIS_PASSWORD" -p "$SENTINEL_PORT" info Sentinel

set +x  # 出错退出

# rm -rf sentinel.sh  && vi ./sentinel.sh
# chmod +x sentinel.sh && ./sentinel.sh
# cat /home/redis/conf/sentinel.conf
# redis-cli -h
