## 概念
- master: 主节点, 用于写入数据
- slave: 从节点, 用于读取数据

## 环境

| IP            | Linux发行版     | 角色  |
|---------------|--------------|-----|
| 192.168.2.152 | Ubuntu 22.04 | 主节点 |
| 192.168.2.155 | Ubuntu 22.04 | 从节点 |
| 192.168.2.158 | Ubuntu 22.04 | 从节点 |

## [部署](https://redis.io/docs/install/install-redis/)

> 二进制安装的注意项
如果需要设置为自启动后台运行需要编写service配置文件, 需要修改redis.conf文件, 配置以下参数:
- daemonize 改为daemonize yes
- pidfile 改为pidfile $REDIS_HOME/redis.pid
- supervised 值为systemd, upstart, auto, 选择当前系统管理的软件包

service配置文件需要配置以下参数: 
- Service.ExecStart=redis-server $REDIS_HOME/conf/redis.conf: 启动redis服务
- Service.ExecStop=redis-cli -p $PORT shutdown: 退出之前使用 SHUTDOWN 命令将数据保存在磁盘上

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
运行install.sh, 该shell只适用与apt包管理器, 本shell需要安装一个`pkgconf`依赖包, 如果是yum包管理器, 需要自己安装相关依赖包

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

完整的redis配置在conf目录中的rediis.default.conf, 取自官网, 根据你实际的需求进行修改, 本文档使用推荐的配置

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
#### 验证配置
全部节点都配置完成后, 需要验证是否配置成功, 需要在每个节点上执行以下命令:

`redis-cli -h <HOST> -p <PORT> -a <PASSWORD>` 连接redis, 例如:

```shell
redis-cli -p $REDIS_PORT -a $REDIS_PASSWORD PING
```
如果返回`PONG`表示连接成功

#### 验证主从复制
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

完整的redis配置在conf目录中的sentinel_default.conf, 取自官网, 根据你实际的需求进行修改, 本文档只使用了最小的可执行的的配置

修改 Redis 哨兵模式的配置文件
```shell
cd /home/redis/
cp /home/redis/redis-stable/sentinel.conf conf/
```

### 主节点配置
定义环境变量:
1. REDIS_HOME: redis目录
2. NODE_NAME: 节点的名称
3. REDIS_PASSWORD: redis的密码
4. REDIS_PORT: redis的端口, 默认6379
5. SENTINEL_PORT: 哨兵的端口, 默认26379
6. MASTER_IP: master节点的ip和端口
7. SLAVE_QUORUM: 已部署的从节点的数量, 本文档中为2个从节点, 所以为2
8. MASTER_HOST: master节点的ip和端口

> 注意, MASTER_NAME的值必须与其他节点不同,为了区别不同的节点

示例:
```shell
export REDIS_HOME="/home/redis"
export NODE_NAME="master1" 
export REDIS_PASSWORD="263393"
export REDIS_PORT="6379"
export SENTINEL_PORT="26379"
export MASTER_IP="192.168.2.152"
export MASTER_HOST="$MASTER_IP $REDIS_PORT"
export SLAVE_QUORUM="2"
```

#### 从节点配置
1. REDIS_HOME: redis目录
2. NODE_NAME: 节点的名称
3. REDIS_PASSWORD: redis的密码
4. REDIS_PORT: redis的端口, 默认6379
5. SENTINEL_PORT: 哨兵的端口, 默认26379
6. MASTER_IP: master节点的ip和端口
7. MASTER_HOST: master节点的ip和端口
8. SLAVE_QUORUM: 已部署的从节点的数量, 本文档中为2个从节点, 所以为2

> 注意, NODE_NAME的值必须与其他节点不同, 为了与其他节点区分

```shell
export REDIS_HOME="/home/redis"
export NODE_NAME="master1" 
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

## 安全性
### [ACL](https://redis.io/docs/management/security/acl/)

解析:
redis-cli
```
> ACL LIST
1) "user default on nopass ~* &* +@all"
```

每行中的前两个单词是“user”，后跟用户名。接下来的词是描述不同事物的 ACL 规则。
默认用户配置为活动 （on）、不需要密码 （nopass）、访问每个可能的密钥 （ ~* ） 和 Pub/Sub 通道 （ &* ），并能够调用所有可能的命令 （ +@all ）。

创建用户的语法:
1. ACL SETUSER 关键字
2. 用户名
3. on | off 启用或禁用用户
4.  用户密码
   1. nopass ：删除用户的所有设置密码，并将用户标记为不需要密码：这意味着每个密码都将针对此用户。如果此指令用于默认用户，则每个新连接都将立即使用默认用户进行身份验证，而无需任何显式 AUTH 命令。请注意，resetpass 指令将清除此条件
   2. `><password>` ：将此密码添加到用户的有效密码列表中。例如 >mypass ，将“mypass”添加到有效密码列表中。此指令清除 nopass 标志（请参阅后面）。每个用户都可以拥有任意数量的密码
   3. `<<password>` ：从有效密码列表中删除此密码。如果您尝试删除的密码实际上未设置，则会发出错误
   4. #<hash> ：将此 SHA-256 哈希值添加到用户的有效密码列表中。此哈希值将与为 ACL 用户输入的密码哈希值进行比较。这允许用户在文件中存储哈希值， acl.conf 而不是存储明文密码。仅接受 SHA-256 哈希值，因为密码哈希必须为 64 个字符，并且仅包含小写的十六进制字符
   5. !<hash> ：从有效密码列表中删除此哈希值。当您不知道哈希值指定的密码，但想要从用户中删除密码时，这很有用
   6. resetpass: 刷新允许的密码列表并删除 nopass 状态。resetpass 后，用户没有关联的密码，如果不添加一些密码（或稍后将其设置为 nopass），就无法进行身份验证
5. 允许和禁止的命令:
   1. +@module 允许模块
   2. -@module 禁止模块
   3. ~command 允许命令
   4. +command 允许命令, 例如`+config|get`
   5. -command 禁止命令, 将命令删除到用户可以调用的命令列表中。从 Redis 7.0 开始，它可以与阻塞子命令一起使用 | （例如“-config|set”）
   6. +@<category>: 添加该类别中要由用户调用的所有命令，有效类别为@admin、@set、@sortedset、...依此类推，通过调用命令 ACL CAT 查看完整列表。特殊类别 @all 表示所有命令，包括当前存在于服务器中的命令，以及将来将通过模块加载的命令
   7. -@<category> ：喜欢 +@<category> ，但从客户端可以调用的命令列表中删除命令
   8. allcommands ：+@all 的别名。请注意，这意味着能够执行通过模块系统加载的所有未来命令
   9. nocommands ：-@all 的别名。
6. 允许和禁止某些密钥和密钥权限
   1. ~<pattern> ：添加可作为命令的一部分提及的键模式。例如 ~* ，允许所有密钥。该模式是 glob 样式的模式，类似于 KEYS 的模式。可以指定多个模式
   2. %R~<pattern> ：（在 Redis 7.0 及更高版本中可用）添加指定的读取键模式。这的行为类似于常规密钥模式，但仅授予从与给定模式匹配的密钥中读取的权限。有关详细信息，请参阅密钥权限。
   3. %W~<pattern> ：（在 Redis 7.0 及更高版本中可用）添加指定的写入密钥模式。这的行为类似于常规密钥模式，但仅授予写入与给定模式匹配的密钥的权限。有关详细信息，请参阅密钥权限
   4. %RW~<pattern> ：（在 Redis 7.0 及更高版本中可用）的 ~<pattern> 别名。
   5. allkeys ：的别名 ~*
   6. resetkeys ：刷新允许的键模式列表。例如 ~foo:* ~bar:* resetkeys ~objects:* ，ACL 将只允许客户端访问与模式 objects:* 匹配的密钥
7. 允许和禁止发布/订阅频道
   1. &<pattern> ：（在 Redis 6.2 及更高版本中可用）添加用户可以访问的 Pub/Sub 频道的 glob 样式模式。可以指定多个通道模式。请注意，模式匹配仅针对 PUBLISH 和 SUBSCRIBE 提到的通道进行，而 PSUBSCRIBE 要求其通道模式与用户允许的通道模式之间的文字匹配
   2. allchannels ：&* 的别名 允许用户访问所有 Pub/Sub 频道的别名。
   3. resetchannels ：刷新允许的通道模式列表，如果用户的 Pub/Sub 客户端不再能够访问其各自的通道和/或通道模式，则断开这些客户端的连接
```shell
ACL SETUSER <用户名> [on | off] [nopass | resetpass] [~pattern [~pattern ...]] [+@module [+@module ...]] [-@module [-@module ...]] [~command [~command ...]] [+command [+command ...]] [-command [-command ...]]
```

配置账号密码:
```
sentinel sentinel-user $NODE_NAME
sentinel sentinel-pass $REDIS_PASSWORD
```

创建一个账号, 用于哨兵模式

```shell
redis-cli -h 192.168.2.152 -a "$REDIS_PASSWORD" -p "$SENTINEL_PORT"
```
> 以下操作都是在redis-cli中执行

示例1:  账号是master1,密码为263393, 规则是allchannels +@all
```shell
ACL SETUSER master1 ON >263393 allchannels +@all
```

示例2: 创建一个名为 "master1" 的用户，并启用该用户，密码为 "263393"。然后，该用户被允许执行所有命令（+@all），但被禁止执行属于危险分类（@dangerous）的命令（-@dangerous）
```shell
ACL SETUSER master1 on >263393 +@all -CONFIG -FLUSHDB -FLUSHALL
```

示例3: 创建一个名为 "master2" 的用户，并启用该用户，密码为 "263393"。然后，该用户被允许执行所有命令（+@all），但被禁止执行CONFIG -FLUSHDB -FLUSHALL命令
```shell
ACL SETUSER master2 on >263393 +@all -CONFIG -FLUSHDB -FLUSHALL

```

验证账号
```shell
auth master1 263393
```

关闭默认的账号
```shell
ACL SETUSER default off 
```

删除账号:
```shell
ACL DELUSER <username>
```

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
