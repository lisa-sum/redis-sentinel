#!/bin/sh
set -x  # 开启跟踪

# 判断REDIS_HOME和REDIS_PASSWORD和MASTER_IP是否同时存在
if [ -z "$REDIS_PASSWORD" ] || [ -z "$MASTER_IP" ] || [ -z "$REDIS_HOME" ] || [ -z "$REDIS_PORT" ]; then
  echo "请定义 REDIS_PASSWORD 和 MASTER_IP 和 REDIS_HOME变量!"
  echo 以下变量的输出如果为空则没有定义, 请定义变量后再运行脚本
  echo REDIS_PASSWORD的值是: "$REDIS_PASSWORD"
  echo MASTER_IP的值是: "$MASTER_IP"
  echo REDIS_HOME的值是: "$REDIS_HOME"
  echo REDIS_PORT的值是: "$REDIS_PORT"
  exit 1
fi

# 配置redis.conf
echo "正在配置redis需要的目录"
mkdir -p /home/redis
mkdir -p /home/redis/data
mkdir -p /home/redis/conf
mkdir -p /home/redis/logs

cat > "$REDIS_HOME"/conf/redis.conf << EOF
#87行，修改监听地址为0.0.0.0
bind 0.0.0.0

#111行，将本机访问保护模式设置no
protected-mode no

#138行，Redis默认的监听端口
port $REDIS_PORT

#309行，设置为守护进程，后台启动
daemonize yes

#341行，指定 PID 文件
pidfile /run/redis/redis_6379.pid

#354行，指定日志文件
logfile "$REDIS_HOME/logs/redis.log"

#504行，指定持久化文件所在目录
dir $REDIS_HOME/data

# master是否有密码保护(使用了requirepass配置)
# 可以告诉副本之前进行身份验证启动复制同步进程，
# 否则主进程拒绝副本请求

masterauth $REDIS_PASSWORD

#1037行，可选，设置redis密码
requirepass $REDIS_PASSWORD

#1380行，开启AOF
appendonly yes

#528行，指定要同步的Master节点IP和端口
replicaof $MASTER_IP

#535行，可选，指定Master节点的密码，仅在Master节点设置了requirepass
masterauth $REDIS_PASSWORD

# redis为编译安装时, 需要编写进程持久化时, 需要设置supervised参数, 可选值为systemd, upstart, auto, no
supervised systemd
EOF

# 编写redis.service守护进程文件
cat > /etc/systemd/system/redis.service << EOF
[Unit]
Description=Redis Status
After=network.target

[Service]
Type=notify
KillMode=control-group
PIDFile=/var/run/redis_6379.pid
ExecStart=redis-server $REDIS_HOME/conf/redis.conf
ExecStartPost=/bin/sh -c "echo $MAINPID > /var/run/redis_6379.pid"
ExecReload=/bin/kill -USR2 $MAINPID && redis-server $REDIS_HOME/conf/redis.conf
ExecStop=redis-cli -a $REDIS_PASSWORD -p $REDIS_PORT shutdown
ExecStopPost=tail -n 10 logs/redis.log
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 重新加载service
sudo systemctl daemon-reload

# 重启redis读取最新修改的配置文件
systemctl restart redis.service

set +x  # 出错退出
