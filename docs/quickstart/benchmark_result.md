1. [测试环境搭建](benchmark_env.md)
2. [测试代码开发](benchmark_code.md)
3. [Spark on ACK测试](benchmark_steps.md)
4. [测试结果分析](benchmark_result.md)
5. [问题排查定位](debugging_guide.md)

## 压测环境 

### 硬件配置

- **ACK集群说明**

| 集群类型        | ACK标准专有集群                                        |
| -------------- | ---------------------------------------------------- |
| ECS实例         | ECS规格：ecs.d1ne.6xlarge<br>Aliyun Linux 2.1903<br>CPU: 24核，内存：96G<br>数据盘：5500G HDD x 12 |
| Worker Node个数 | 20                                                  |



### 软件配置

- **软件版本**

spark version: 2.4.5

alluxio version: 2.3.0

- **Spark配置说明**

| spark.driver.cores         | 5     |
| -------------------------- | ----- |
| spark.driver.memory (MB)   | 20480 |
| spark.executor.cores       | 7     |
| spark.executor.memory (MB) | 20480 |
| spark.executor.instances   | 20    |

## 压测结果

### Spark是否启用Alluxio对比

![tpcds_per_query.jpeg](docs/img/tpcds_per_query.jpeg)

query任务总耗时



|                  | total（Min） |
| ---------------- | ---------- |
| Spark with OSS       | 180       |
| Spark with Alluxio Cold | 145       |
| Spark with Alluxio Warm | 137       |



![spark_vs_alluxio.jpg](docs/img/spark_vs_alluxio.jpg)