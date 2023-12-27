#!/bin/sh
set -x  # 开启跟踪

# 判断REDIS_HOME和REDIS_PASSWORD和MASTER_IP是否同时存在
if [ -z "$REDIS_PASSWORD" ] || [ -z "$REDIS_HOME" ] || [ -z "$REDIS_PORT" ]; then
  echo "请定义 REDIS_PASSWORD 和 MASTER_IP 和 REDIS_HOME变量!"
  echo 以下变量的输出如果为空则没有定义, 请定义变量后再运行脚本
  echo REDIS_PASSWORD的值是: "$REDIS_PASSWORD"
  echo MASTER_IP的值是: "$MASTER_IP"
  echo REDIS_HOME的值是: "$REDIS_HOME"
  exit 1
fi

# 配置redis.conf
echo "正在配置redis需要的目录"
mkdir -p /home/redis
mkdir -p /home/redis/data
mkdir -p /home/redis/conf
mkdir -p /home/redis/logs

cat > $REDIS_HOME/conf/redis.conf << EOF
# 87行，修改监听地址为0.0.0.0
bind 0.0.0.0

# 111行，将本机访问保护模式设置no
protected-mode no

# 138行，Redis默认的监听端口
port $REDIS_PORT

# 309行，设置为守护进程，后台启动
daemonize yes

# 341行，指定 PID 文件
pidfile /var/run/redis.pid

# 354行，指定日志文件
logfile "$REDIS_HOME/logs/redis.log"

# Redis 实例的数据目录和工作目录
dir $REDIS_HOME

# 创建用户master1, 并设置密码, 并授权所有权限, 除了-flushdb -flushall -config
user master1 on >263393 allcommands -flushdb -flushall -config ~* allchannels
# 禁用默认账号
user default off -@all

# master是否有密码保护(使用了requirepass配置)
# 可以告诉副本之前进行身份验证启动复制同步进程，
# 否则主进程拒绝副本请求

masterauth $REDIS_PASSWORD

# 1037行，可选，设置redis密码
requirepass $REDIS_PASSWORD

# 1380行，开启AOF
appendonly yes

# redis为编译安装时, 需要编写进程持久化时, 需要设置supervised参数, 可选值为systemd, upstart, auto, no
supervised systemd

# 在主节点检测到它不再能够将其写入传输到指定数量的副本时停止接受写入
# 如果有一个节点的redis异常时, 可能会继续将数据写入旧主服务器。此数据将永远丢失，因为当分区愈合时，主服务器将被重新配置为新主服务器的副本，从而丢弃其数据集
# 使用以下 Redis 复制功能缓解此问题，该功能允许在主节点检测到它不再能够将其写入传输到指定数量的副本时停止接受写入
# 通过此优化，如果从节点全部不可用，主服务器将停止接受写入。根据你的实践需求进行权衡
# min-replicas-to-write 1
# min-replicas-max-lag 10
EOF

# 编写redis.service守护进程文件
cat > /etc/systemd/system/redis.service << EOF
[Unit]
Description=Redis Status
After=network.target

[Service]
# Type=simple
Type=forking
User=root
Group=root
ExecStart=/usr/local/bin/redis-server $REDIS_HOME/conf/redis.conf
# ExecStartPost=/bin/sh -c "echo $MAINPID > /var/run/redis.pid"
ExecStop=/usr/local/bin/redis-cli -a $REDIS_PASSWORD -p $REDIS_PORT shutdown
Restart=no

[Install]
WantedBy=multi-user.target
EOF

# 重新加载service
sudo systemctl daemon-reload

sleep 1

# 重启redis读取最新修改的配置文件
systemctl start redis.service
systemctl enable redis

set +x  # 出错退出

# rm -rf 01-master-replication.sh && vi ./01-master-replication.sh
# chmod +x 01-master-replication.sh && ./01-master-replication.sh
# /usr/local/bin/redis-server /home/redis/conf/redis.conf
# tail -n 50 logs/redis.log
