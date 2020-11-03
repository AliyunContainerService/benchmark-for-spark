本文介绍如何在ACK上运行Spark作业，并使用EMR Spark Core和JindoFS分布式缓存优化性能。

### 前提条件
- ACK标准集群，节点规格选用ecs.d1ne.6xlarge大数据型，共20个Worker节点。
- 阿里云OSS，并创建一个bucket，用来替换YAML文件中的OSS配置。
- 利用TPC-DS生成1TB数据，存储在阿里云OSS上，详情参考[生成数据](./generate-data.md)。

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

- **安装JindoFS**

  通过安装jindofs组件，您可以使用JindoFS的缓存加速服务，提升OSS读取速度，缓解带宽压力。

     1).登录[容器服务管理控制台](https://cs.console.aliyun.com/)。

     2).在控制台左侧导航栏中，选择***\*市场\** > \**应用目录\****。

     3).在**应用目录**页面，找到并单击jindofs

     4).在**应用目录 - jindofs** 页面右侧，选择对应的ACK集群并单击**创建**。

     注: 需要根据ACK集群的环境，修改对应jindofs的参数（如AccessKey、以及mount的磁盘路径），完整参数示例如下：

  ```yaml
  # Default values for JindoFS.
  # This is a YAML-formatted file.
  # Declare variables to be passed into your templates.
  
  
  image: registry-vpc.cn-beijing.aliyuncs.com/jindofs/smartdata
  imageTag: "2.7.4"
  imagePullPolicy: Always
  
  fuseImage: registry-vpc.cn-beijing.aliyuncs.com/jindofs/jindo-fuse
  fuseImageTag: "2.7.4"
  
  user: 0
  group: 0
  fsGroup: 0
  
  useHostNetwork: true
  useHostPID: true
  
  properties:
    logDir: /mnt/diskb/bigboot/log
  
  master:
    replicaCount: 1
    resources:
      limits:
        cpu: "8"
        memory: "32G" # increase memory corresponding to filelet(blocklet) cache size
      requests:
        cpu: "1"
        memory: "1G"
    nodeSelector:
      beta.kubernetes.io/instance-type: ecs.d2s.10xlarge
    properties:
      namespace.rpc.port: 8101
      namespace.meta-dir: /mnt/diskb/bigboot/server
      namespace.filelet.cache.size: 100000
      namespace.blocklet.cache.size: 1000000
      namespace.backend.type: rocksdb
      jfs.namespaces: default
      jfs.namespaces.default.mode :  cache
      jfs.namespaces.default.oss.uri: YOUR-OSS-URI
      jfs.namespaces.default.oss.access.key: YOUR-ACCESS-KEY-ID
      jfs.namespaces.default.oss.access.secret: YOUR-ACCESS-KEY-SECRET
  
  worker:
    resources:
      limits:
        cpu: "8"
        memory: "32G" # increase memory corresponding to the number of concurrent reading/writing files
      requests:
        cpu: "1"
        memory: "1G"
    nodeSelector:
      beta.kubernetes.io/instance-type: ecs.d2s.10xlarge
    properties:
      storage.rpc.port: 6101
      storage.data-dirs: /mnt/diskc/bigboot,/mnt/diskd/bigboot,/mnt/diske/bigboot,/mnt/diskf/bigboot,/mnt/diskg/bigboot,/mnt/diskh/bigboot,/mnt/diski/bigboot,/mnt/diskj/bigboot,/mnt/diskk/bigboot,/mnt/diskl/bigboot,/mnt/diskm/bigboot
      storage.temp-data-dirs: /mnt/diskb/bigboot/tmp
      storage.watermark.high.ratio: 0.4
      storage.watermark.low.ratio: 0.2
      storage.data-dirs.capacities: 2000g,2000g,2000g,2000g,2000g,2000g,2000g,2000g,2000g,2000g,2000g
      storage.meta-dir: /mnt/diskb/bigboot/bignode
  
  fuse:
    args:
    hostPath: /mnt/jfs
    properties:
      client.storage.rpc.port: 6101
      client.oss.retry: 5
      client.oss.upload.threads: 4
      client.oss.upload.queue.size: 5
      client.oss.upload.max.parallelism: 16
      client.oss.timeout.millisecond: 30000
      client.oss.connection.timeout.millisecond: 3000
  
  mounts:
    master:
      - /mnt/diskb
    workersAndClients:
      - /mnt/diskb
      - /mnt/diskc
      - /mnt/diskd
      - /mnt/diske
      - /mnt/diskf
      - /mnt/diskg
      - /mnt/diskh
      - /mnt/diski
      - /mnt/diskj
      - /mnt/diskk
      - /mnt/diskl
      - /mnt/diskm
  ```

  

### 提交Spark作业

```yaml
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: SparkApplication
metadata:
  name: tpcds-benchmark-emrspark-ess-1t
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
    spark.local.dir: /mnt/diskb/spark-data,/mnt/diskc/spark-data,/mnt/diskd/spark-data,/mnt/diske/spark-data,/mnt/diskf/spark-data,/mnt/diskg/spark-data,/mnt/diskh/spark-data,/mnt/diski/spark-data,/mnt/diskj/spark-data,/mnt/diskk/spark-data,/mnt/diskl/spark-data,/mnt/diskm/spark-data
    spark.shuffle.manager: org.apache.spark.shuffle.sort.SortShuffleManager
  volumes:
    - name: diskb
      hostPath:
        path: /mnt/diskb
        type: Directory
    - name: diskc
      hostPath:
        path: /mnt/diskc
        type: Directory
    - name: diskd
      hostPath:
        path: /mnt/diskd
        type: Directory
    - name: diske
      hostPath:
        path: /mnt/diske
        type: Directory
    - name: diskf
      hostPath:
        path: /mnt/diskf
        type: Directory
    - name: diskg
      hostPath:
        path: /mnt/diskg
        type: Directory
    - name: diskh
      hostPath:
        path: /mnt/diskh
        type: Directory
    - name: diski
      hostPath:
        path: /mnt/diski
        type: Directory
    - name: diskj
      hostPath:
        path: /mnt/diskj
        type: Directory
    - name: diskk
      hostPath:
        path: /mnt/diskk
        type: Directory
    - name: diskl
      hostPath:
        path: /mnt/diskl
        type: Directory
    - name: diskm
      hostPath:
        path: /mnt/diskm
        type: Directory
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
    volumeMounts:
      - mountPath: /mnt/diskb
        name: diskb
      - mountPath: /mnt/diskc
        name: diskc
      - mountPath: /mnt/diskd
        name: diskd
      - mountPath: /mnt/diske
        name: diske
      - mountPath: /mnt/diskf
        name: diskf
      - mountPath: /mnt/diskg
        name: diskg
      - mountPath: /mnt/diskh
        name: diskh
      - mountPath: /mnt/diski
        name: diski
      - mountPath: /mnt/diskj
        name: diskj
      - mountPath: /mnt/diskk
        name: diskk
      - mountPath: /mnt/diskl
        name: diskl
      - mountPath: /mnt/diskm
        name: diskm
```
完整YAML文件可参考[tpcds-benchmark-with-emrspark-jindofs](../../kubernetes/emr/tpcds-benchmark-with-emrspark-jindofs.yaml)，其中spec.mainApplicationFile中的jar包
可通过这里[下载](../../kubernetes/emr/jar/spark-sql-perf-assembly-0.5.0-SNAPSHOT.jar)，放在自己的OSS中。

