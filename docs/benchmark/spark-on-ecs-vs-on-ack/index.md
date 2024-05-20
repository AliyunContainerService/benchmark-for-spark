# Spark on ACK 基准测试之对比 on ECS 和 ACK

本文将在同一规模的 ECS 和 ACK 集群中分别运行 Scale Factor 为 3072 的 TPC-DS 基准测试。

## 基准测试环境

本文使用的基准测试环境如下：

| **集群类型** | ACK 专业版                                     |
| ------------ | ---------------------------------------------- |
| **K8s 版本** | 1.26.3-aliyun.1                                |
| **地域**     | 华北2（北京）                                  |
| **实例规格** | ecs.g8y.8xlarge（32 vCPU + 128 GB）            |
| **节点数量** | 1 master 节点 + 6 worker 节点                  |
| **操作系统** | Alibaba Cloud Linux 3.2104 LTS 64位 ARM版      |
| **本地存储** | 每个 worker 节点挂载 6 块 300 GB ESSD PL1 云盘 |

注：

- master 节点仅用于调度 driver pod，不调度 worker pod。
- worker 节点用于调度 executor pod。

## 基准测试过程

1. 创建基准测试环境，详情请参见[搭建基准测试环境](../setup-env/index.md)；
2. 生成测试数据，详情请参见[生成基准测试数据集](../../../charts/tpcds-data-generation/README.md)
3. 运行基准测试，详情请参见[运行 TPCDS 基准测试](../../../charts/tpcds-benchmark/README.md)

## 基准测试配置

在基准测试阶段，总共调度 60 个 executor pod，其中每个 worker 节点调度 10 个 executor pod，每个 executor pod 分配 3 个 cpu 核心和 12g 内存（9g 堆内内存 + 3g 堆外内存），因此每个节点的 cpu request 为 30，内存的 request 和 limit 均为 120g 。

## 基准测试结果参考

本次基准测试在相同数量和规格的 ECS 和 ACK 集群环境下运行规模为 3TB（SF=3072）的 TPCDS 基准测试，结果如下：

- Spark on ECS 环境下运行了 3 次，平均用时为 4786 秒；Spark on ACK 环境下运行了 5 次，平均用时为 4758.6 秒，相比于前者降低约 0.5%，鉴于查询时间存在一定的波动，可以认为两者查询性能几乎一致。
