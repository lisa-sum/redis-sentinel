package main

import (
	"context"
	"fmt"
	"github.com/redis/go-redis/v9"
)

// 参考 https://redis.uptrace.dev/guide/go-redis-sentinel.html#redis-server-client
func main() {
	// 默认方式, 稳定:
	// client := redis.NewFailoverClient(&redis.FailoverOptions{
	// 	MasterName:    "master",
	// 	SentinelAddrs: []string{"192.168.2.155:26379", "192.168.2.158:26379", "192.168.2.152:26379"},
	// 	Password:      "263393", // 如果有密码，请填写
	// 	DB:            0,
	// })

	// 从 v8 开始，您可以使用实验性 NewFailoverClusterClient 命令将只读命令路由到从节点
	client := redis.NewFailoverClusterClient(&redis.FailoverOptions{
		MasterName:     "master1",
		SentinelAddrs:  []string{"192.168.2.155:26379", "192.168.2.158:26379", "192.168.2.152:26379"},
		Password:       "263393", // 如果有密码，请填写
		DB:             0,
		RouteByLatency: true, // 将只读命令路由到从节点
		RouteRandomly:  true, // 将只读命令路由到从节点
	})

	// 设置一个键值对
	err := client.Set(context.Background(), "example_key", "example_value", 0).Err()
	if err != nil {
		panic(err)
	}

	// 获取键值对
	val, err := client.Get(context.Background(), "example_key").Result()
	if err != nil {
		panic(err)
	}
	fmt.Println("example_key", val)

	// 关闭连接
	// if err := client.Close(); err != nil {
	// 	panic(err)
	// }
}
