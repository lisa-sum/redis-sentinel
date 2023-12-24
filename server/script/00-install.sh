#!/bin/sh

set -x  # 开启跟踪

echo "正在配置redis需要的目录"
mkdir -p /home/redis
mkdir -p /home/redis/data
mkdir -p /home/redis/conf
mkdir -p /home/redis/logs

echo "进入redis目录"
cd /home/redis

echo "下载redis"
wget https://download.redis.io/redis-stable.tar.gz

echo "解压redis"
tar -xzvf redis-stable.tar.gz

echo "进入redis目录"

cd redis-stable

echo "编译redis"
sudo make install

set +x  # 关闭跟踪
