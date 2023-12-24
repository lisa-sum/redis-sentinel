# Redis 主从复制(读写分离)和哨兵模式(Sentinel mode)的服务端安装与客户端使用

## 概念
- master: 主节点, 用于写入数据
- slave: 从节点, 用于读取数据
- 主从复制, 也叫读写分离. 主节点负责写,从节点负责读, 从节点可以有多个, 从节点可以有从节点, 但是不能循环, 从节点可以有主节点, 但是不能循环
主节点会将数据同步到从节点, 从节点会定时向主节点发送心跳, 如果主节点没有响应, 从节点会自动切换为主节点, 从节点可以配置为只读, 也可以配置为可写
- 主备切换,也叫哨兵模式. 主节点宕机, 从节点会自动切换为主节点, 但是会丢失数据, 所以需要配置主备切换, 从节点会将数据同步到备节点, 备节点会定时向从节点发送心跳, 如果从节点没有响应, 备节点会自动切换为主节点, 从节点可以配置为只读, 也可以配置为可写

## [安装](https://redis.io/docs/install/install-redis/)

### 二进制安装的注意项
如果需要设置为自启动后台运行需要编写service配置文件, 需要修改redis.conf文件, 配置以下参数:
- daemonize 改为daemonize yes
- pidfile 改为pidfile $REDIS_HOME/redis.pid
- supervised 值为systemd, upstart, auto, 选择当前系统管理的软件包

service配置文件需要配置以下参数: 
- Service.ExecStart=redis-server $REDIS_HOME/conf/redis.conf: 启动redis服务
- Service.ExecStop=redis-cli -p $PORT shutdown: 退出之前使用 SHUTDOWN 命令将数据保存在磁盘上
- Service.Type=notify: 设置服务的启动方式, 推荐设置为`notify`,启动结束后会发出通知信号，然后 systemd 再启动其他服务

`/etc/systemd/system/redis.service`示例:
```
[Unit]
# 简单描述服务
Description=Redis Status
# 描述服务类别，表示本服务需要在network服务启动后在启动
After=network.target

[Service]
# 设置服务的启动方式
Type=notify

# 指定服务的工作目录
WorkingDirector=/usr/local/bin/

# 杀死进程的方式
KillMode=control-group

# 启动服务的命令
ExecStart=redis-server $REDIS_HOME/conf/redis.conf

# 服务启动后的执行命令, 该命令会在ExecStart命令执行后执行
ExecStartPost=/bin/sh -c "echo $MAINPID > /var/run/redis_6379.pid"

# PID文件的位置
PIDFile=/var/run/redis_6379.pid

# 服务停止的命令: 通过redis-cli工具连接到redis服务并执行shutdown命令
ExecStop=redis-cli -p $PORT shutdown

# 服务退出后的重启策略, on-abnormal表示非正常退出时重启,on-failure表示失败时重启
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### [源码安装](https://redis.io/docs/install/install-redis/install-redis-from-source/)
运行install.sh, 该shell只适用与apt包管理器, 本shell需要安装一个pkgconf依赖包, 如果是yum包管理器, 需要自己安装依赖包

apt:
```shell
apt install pkgconf -y
```

然后运行
```shell
chmod +x install.sh
./install.sh
```

## 主从复制(读写分离)配置

### 主节点配置
定义`REDIS_HOME`变量为你自己的redis安装目录,该目录必须提前创建. 后续安装和配置都在此目录下执行
定义`REDIS_PASSWORD`变量为你自己的redis的密码,生产环境中, 推荐设置为高强调密码, 降低弱密码风险
定义`REDIS_PORT`变量为你自己的redis的端口, 生产环境中, 推荐设置为非默认端口, 降低直接扫描到该默认端口的风险
```shell
export REDIS_HOME="/home/redis"
export REDIS_PASSWORD="123456"
export REDIS_PORT="6379"
```

### 从节点配置
定义`MASTER_IP`变量为master节点ip和端口
定义`REDIS_PASSWORD`变量为你自己的redis的密码,生产环境中, 推荐设置为高强调密码, 降低弱密码风险
定义`REDIS_PORT`变量为你自己的redis的端口, 生产环境中, 推荐设置为非默认端口, 降低直接扫描到该默认端口的风险
```shell
export MASTER_IP="192.168.2.152 6379"
export REDIS_PASSWORD="123456"
export REDIS_PORT="6379"
```

### 验证
1. 全部节点都配置完成后, 需要验证是否配置成功, 需要在每个节点上执行以下命令:

`redis-cli -h <HOST> -p <PORT> -a <PASSWORD>` 连接redis, 例如:

```shell
redis-cli -p $REDIS_PORT -a $REDIS_PASSWORD PING
```
如果返回`PONG`表示连接成功

2. 验证主从复制
   1. 在主节点上执行`redis-cli info replication`命令, 查看主节点信息, 例如:
      ```shell
      redis-cli -p 6379 -a $REDIS_PASSWORD info replication
      ```
   2. 在主节点进行写操作, 例如:
      ```shell
      redis-cli -p 6379 -a $REDIS_PASSWORD set name "zhangsan"
      ```
   3. 在从节点上验证是否同步成功, 例如:
      ```shell
      redis-cli -p 6379 -a $REDIS_PASSWORD get name
      ```

## 哨兵模式
介绍: 哨兵(sentinel)是一个分布式系统，用于对主从结构中的每台服务器进行监控，当出现故障时通过投票机制选择新的Master，并将所有Slave 连接到新的Master。所以整个运行哨兵的集群的数量不得少于3个节点。
核心: 在主从复制的基础上，哨兵引入了主节点的自动故障转移。
作用: 
- 监控：哨兵会不断地检查主节点和从节点是否运作正常。
- 自动故障转移：当主节点不能正常工作时，哨兵会开始自动故障转移操作，它会将失效主节点的其中一个从节点升级为新的主节点，并让其他从节点改为复制新的主节点。
- 通知：哨兵可以将故障转移的结果发送给客户端。

修改 Redis 哨兵模式的配置文件
```shell
cd /home/redis/
cp /home/redis/redis-stable/sentinel.conf conf/
vi conf/sentinel.conf
```

定义
REDIS_HOME= redis目录
MASTER_NAME master节点的名称
MASTER_IP master节点的ip和端口
SLAVE_NUMBER 已部署的从节点的数量
REDIS_PASSWORD redis的密码
REDIS_PORT redis的端口
注意, MASTER_NAME的值必须与其他节点不同,为了区别不同的节点
```shell
export REDIS_HOME="/home/redis"
export MASTER_NAME="master1" 
export REDIS_PASSWORD="263393"
export REDIS_PORT="6379"
export SENTINEL_PORT="26379"
export MASTER_IP="192.168.2.152"
export MASTER_HOST="$MASTER_IP $REDIS_PORT"
export SLAVE_QUORUM="2"
```

#### 从节点
MASTER_NAME 从节点的名称, 例如:
MASTER_NAME="slave1"
MASTER_NAME="slave2"
```shell
export REDIS_HOME="/home/redis"
export SLAVE_NAME="slave1"
export REDIS_PASSWORD="263393"
export REDIS_PORT="6379"
export SENTINEL_PORT="26379"
export MASTER_IP="192.168.2.152"
export MASTER_HOST="$MASTER_IP $REDIS_PORT"
export SLAVE_QUORUM="2"
```

## 常用命令
`redis-cli -h <HOST> -p <PORT> -a <PASSWORD>` 连接redis, 例如:
```shell
redis-cli -p 6379 -a 263393 PING
```

`lsof -i:<PORT>` 查看端口占用情况和PID, 例如:
```shell
lsof -i: 6379
```

`kill -9 <PID>` 杀死进程对应的PID, 例如:
```shell
kill -9 12336379
```

systemctl命令:
```shell
systemctl start redis # 启动服务
systemctl stop redis # 停止服务
systemctl restart redis # 重启服务
systemctl status redis # 查看服务状态
```

service的Restart参数有:
- no：服务意外终止时不会自动重启。
- on-success：只有在服务正常退出（退出码为0）的情况下才会自动重启。
- on-failure：只有在服务非正常退出（退出码不为0）的情况下才会自动重启。
- on-abnormal：只有在服务以异常的方式终止时才会自动重启。
- always：无论服务以何种方式终止，systemd 都会尝试自动重新启动服务。

## 客户端
1. 安装依赖
   ```shell
   go mod tidy
   ```
2. 运行
   ```shell
   go run main.go
   ````

## 排错
启动redis服务
```shell
/usr/local/bin/redis-server $REDIS_HOME/conf/redis.conf
```

查看日志
```shell
tail -f $REDIS_HOME/logs/redis.log
```

## 参考
1. [源码安装](https://redis.io/docs/install/install-redis/install-redis-from-source/)
2. [redis-cli](https://redis.io/docs/connect/cli)
3. [主从, 哨兵](https://juejin.cn/post/7286482043141128250?searchId=202312192232312659F3FB16F5043A0DE7)
4. [Linux systemd 配置文件](https://blog.csdn.net/lu_embedded/article/details/132424115)
