本文介绍如何在ACK上，使用EMR Spark和TPC-DS生成测试数据。

### 前提条件
- ACK标准集群，节点规格选用ecs.d1ne.6xlarge大数据型，共20个Worker节点。
- 阿里云OSS，并创建一个bucket，用来替换YAML文件中的OSS配置。

### 环境准备

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


### 提交Spark作业

```yaml
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: SparkApplication
metadata:
  name: tpcds-data-generation-10t
  namespace: default
spec:
  type: Scala
  mode: cluster
  image: registry.cn-beijing.aliyuncs.com/zf-spark/spark-2.4.5:for-tpc-ds-2
  imagePullPolicy: Always
  mainClass: com.databricks.spark.sql.perf.tpcds.TPCDS_Standalone
  mainApplicationFile: "oss://<YOUR-BUCKET>/jars/spark-sql-perf-assembly-0.5.0-SNAPSHOT.jar"
  arguments:
    - "--dataset_location"
    - "oss://<YOUR-BUCKET>/datasets/"
    - "--output_location"
    - "oss://<YOUR-BUCKET>/outputs/ack-pr-10t-emr"
    - "--iterations"
    - "1"
    - "--shuffle_partitions"
    - "1000"
    - "--scale_factor"
    - "10000" #指定生成数据大小，默认单位为GB
    - "--regenerate_dataset"
    - "true"
    - "--regenerate_metadata"
    - "true"
    - "--only_generate_data_and_meta"
    - "true"
    - "--format"
    - "parquet"
  sparkVersion: 2.4.5
  restartPolicy:
    type: Never
  sparkConf:
    spark.eventLog.enabled: "true"
    spark.eventLog.dir: "oss://<YOUR-BUCKET>/spark/eventlogs"
    spark.driver.extraJavaOptions: "-XX:-PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps"
    spark.driver.maxResultSize: 40g
    spark.executor.extraJavaOptions: "-XX:MaxDirectMemorySize=32g -XX:-PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps"
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
  driver:
    cores: 15
    coreLimit: 15000m
    memory: 30g
    labels:
      version: 2.4.5
    serviceAccount: spark
    env:
      - name: TZ
        value: "Asia/Shanghai"
  executor:
    cores: 8
    coreLimit: 8000m
    instances: 20
    memory: 24g
    labels:
      version: 2.4.5
    env:
      - name: TZ
        value: "Asia/Shanghai"
```
完整YAML文件可参考[tpcds-data-generation](../../kubernetes/emr/tpcds-data-generation.yaml)，其中spec.mainApplicationFile中的jar包
可通过这里[下载](../../kubernetes/emr/jar/spark-sql-perf-assembly-0.5.0-SNAPSHOT.jar)，放在自己的OSS中。