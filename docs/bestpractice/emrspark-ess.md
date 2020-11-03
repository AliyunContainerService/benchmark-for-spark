本文介绍如何在ACK上运行Spark作业，并使用EMR Spark Core和Remote Shuffle Service优化性能。

### 前提条件
- ACK标准集群，节点规格选用ecs.d1ne.6xlarge大数据型，共20个Worker节点。
- 阿里云OSS，并创建一个bucket，用来替换YAML文件中的OSS配置。
- 利用TPC-DS生成10TB数据，存储在阿里云OSS上，详情参考[生成数据](./generate-data.md)。

### 环境准备
- **Worker节点挂载磁盘**

  ecs.d1ne.6xlarge型实例默认自带12块5500G HDD数据盘，这些数据盘需要挂载后才能使用，挂载方式如下

  ```shell
  wget https://shilei-tpc-ds.oss-cn-beijing.aliyuncs.com/tools/mount.tgz
  tar -xzvf mount.tgz
  cd mount/
  ./mount
  # SSH password: 此时输入SSH密码后，开始自动执行磁盘挂载
  ```

- **安装ack-spark-operator**

  通过安装ack-spark-operator组件，您可以使用ACK Spark Operator简化提交作业的操作。

     1). 登录容器服务管理控制台。

     2). 在控制台左侧导航栏中，选择**市场 > 应用目录**。

     3). 在**应用目录**页面，找到并单击**ack-spark-operator**。

     4). 在**应用目录 - ack-spark-operator**页面右侧，单击**创建**。

- **安装ack-spark-history-server**（可选）

  ACK Spark History Server通过记录Spark执行任务过程中的日志和事件信息，并提供UI界面，帮助排查问题。 

     在创建**ack-spark-history-server**组件时，您需在**参数**页签配置OSS相关的信息，用于存储Spark历史数据。

     1). 登录容器服务管理控制台。

     2). 在控制台左侧导航栏中，选择**市场 > 应用目录**。

     3). 在**应用目录**页面，找到并单击**ack-spark-history-server**。

     4). 在**应用目录 -** **ack-spark-history-server**页面右侧，单击**创建**。

- **部署remote-shuffle-service**

  remote-shuffle-service可通过钉钉群联系我们，获取安装方式。


### 提交Spark作业

```yaml
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: SparkApplication
metadata:
  name: tpcds-benchmark-emrspark-ess-10t
  namespace: default
spec:
  type: Scala
  mode: cluster
  image: "<EMR-Spark-Image>" # 可通过钉钉群联系我们获取
  imagePullPolicy: Always
  mainClass: com.databricks.spark.sql.perf.tpcds.TPCDS_Standalone
  mainApplicationFile: "oss://<YOUR-BUCKET>/jars/spark-sql-perf-assembly-0.5.0-SNAPSHOT.jar"
  arguments:
    - "--dataset_location"
    - "oss://<YOUR-BUCKET>/datasets/"
    - "--output_location"
    - "oss://<YOUR-BUCKET>/outputs/ack-pr-10t-emr-with-ess"
    - "--iterations"
    - "1"
    - "--shuffle_partitions"
    - "1000"
    - "--scale_factor"
    - "10000"
    - "--regenerate_dataset"
    - "false"
    - "--regenerate_metadata"
    - "false"
    - "--only_generate_data_and_meta"
    - "false"
    - "--format"
    - "parquet"
    - "--query_exclude_list"
    - "q14a,q14b,q67"
  sparkVersion: 2.4.5
  restartPolicy:
    type: Never
  hadoopConf:
    "fs.oss.impl": "org.apache.hadoop.fs.aliyun.oss.AliyunOSSFileSystem"
    "fs.oss.endpoint": "<YOUR-OSS-ENDPOINT>"
    "fs.oss.accessKeyId": "<YOUR-ACCESS-KEY-ID>"
    "fs.oss.accessKeySecret": "<YOUR-ACCESS-KEY-SECRET>"
    hive.metastore.uris: thrift://service-hive-metastore.default:9083
    hive.metastore.client.socket.timeout: 600s
  sparkConf:
    spark.eventLog.enabled: "true"
    spark.eventLog.dir: "oss://<YOUR-BUCKET>/spark/eventlogs"
    spark.driver.extraJavaOptions: "-XX:-PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps"
    spark.driver.maxResultSize: 40g
    spark.executor.extraJavaOptions: "-XX:MaxDirectMemorySize=6g -XX:-PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps"
    spark.locality.wait.node: "0"
    spark.locality.wait.process: "0"
    spark.locality.wait.rack: "0"
    spark.locality.wait: "0"
    spark.memory.fraction: "0.8"
    spark.memory.offHeap.enabled: "false"
    spark.memory.offHeap.size: "17179869184"
    spark.sql.adaptive.bloomFilterJoin.enabled: "false"
    spark.sql.adaptive.enabled: "false"
    spark.sql.analyze.column.async.delay: "200"
    spark.sql.auto.reused.cte.enabled: "true"
    spark.sql.broadcastTimeout: "3600"
    spark.sql.columnVector.offheap.enabled: "false"
    spark.sql.crossJoin.enabled: "true"
    spark.sql.delete.optimizeInSubquery: "true"
    spark.sql.dynamic.runtime.filter.bbf.enabled: "false"
    spark.sql.dynamic.runtime.filter.enabled: "true"
    spark.sql.dynamic.runtime.filter.exact.enabled: "true"
    spark.sql.dynamic.runtime.filter.table.size.lower.limit: "1069547520"
    spark.sql.dynamic.runtime.filter.table.size.upper.limit: "5368709120"
    spark.sql.files.openCostInBytes: "34108864"
    spark.sql.inMemoryColumnarStorage.compressed: "true"
    spark.sql.join.preferNativeJoin: "false"
    spark.sql.native.codecache: "true"
    spark.sql.native.codegen.wholeStage: "false"
    spark.sql.native.nativewrite: "false"
    spark.sql.pkfk.optimize.enable: "true"
    spark.sql.pkfk.riJoinElimination: "true"
    spark.sql.shuffle.partitions: "1000"
    spark.sql.simplifyDecimal.enabled: "true"
    spark.sql.sources.parallelPartitionDiscovery.parallelism: "432"
    spark.sql.sources.parallelPartitionDiscovery.threshold: "32"
    spark.shuffle.reduceLocality.enabled: "false"
    spark.shuffle.service.enabled: "true"
    spark.dynamicAllocation.enabled: "false"
    spark.shuffle.manager: org.apache.spark.shuffle.ess.EssShuffleManager
    spark.ess.master.host: emr-rss-master.spark-rss
    spark.ess.master.port: "9099"
    spark.ess.push.data.buffer.size: 64k
    spark.ess.push.data.max.inflight: "2048"
    spark.ess.rpc.io.clientThreads: "8"
    spark.ess.rpc.io.serverThreads: "8"
    spark.ess.data.io.clientThreads: "8"
    spark.ess.data.io.numConnectionsPerPeer: "8"
  driver:
    cores: 15
    coreLimit: 15000m
    memory: 50g
    labels:
      version: 2.4.5
    serviceAccount: spark
    env:
      - name: TZ
        value: "Asia/Shanghai"
  executor:
    cores: 4
    coreLimit: 6000m
    instances: 20
    memory: 24g
    memoryOverhead: 10g
    deleteOnTermination: false
    labels:
      version: 2.4.5
    env:
      - name: TZ
        value: "Asia/Shanghai"
```
完整YAML文件可参考[tpcds-benchmark-with-emrspark-ess](../../kubernetes/emr/tpcds-benchmark-with-emrspark-ess.yaml)，其中spec.mainApplicationFile中的jar包
可通过这里[下载](../../kubernetes/emr/jar/spark-sql-perf-assembly-0.5.0-SNAPSHOT.jar)，放在自己的OSS中。