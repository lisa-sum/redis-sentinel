#!/bin/sh

mkdir -p /home/redis
mkdir -p /home/redis/data
mkdir -p /home/redis/conf
mkdir -p /home/redis/logs

cd /home/redis

wget https://download.redis.io/redis-stable.tar.gz

tar -xzvf redis-stable.tar.gz

cd redis-stable

sudo make install

redis-server
