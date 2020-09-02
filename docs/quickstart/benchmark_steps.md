1. [测试环境搭建](docs/quickstart/benchmark_env.md)
2. [测试代码开发](docs/quickstart/benchmark_code.md)
3. [Spark on ACK测试](docs/quickstart/benchmark_steps.md)
4. [测试结果分析](docs/quickstart/benchmark_result.md)
5. [问题排查定位](docs/quickstart/debugging_guide.md)

## 测试说明

先生成1TB数据，然后分别测试Spark直接从OSS读取数据，和通过Alluxio冷、热缓存做加速的三种情况。



## 测试步骤

### 1）生成1TB数据

通过执行DataGeneration.scala生成1TB数据，并存在oss上，后面的spark sql查询任务会用到这些数据。

tpcds-data-generator.yaml

```yaml
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: SparkApplication
metadata:
  name: tpcds-data-generation
  namespace: default
spec:
  type: Scala
  image: registry.cn-beijing.aliyuncs.com/yukong/ack-spark-benchmark:1.0.0
  sparkVersion: 2.4.5
  mainClass: com.aliyun.spark.benchmark.tpcds.DataGeneration
  mainApplicationFile: "local:///opt/spark/jars/ack-spark-benchmark-assembly-0.1.jar"
  mode: cluster
  arguments:
    # TPC-DS data localtion
    - "oss://cloudnativeai/spark/data/tpc-ds-data/1000g"
    # Path to kit in the docker image
    - "/tmp/tpcds-kit/tools"
    # Data Format
    - "parquet"
    # Scale factor (in GB)
    - "100000"
    # Generate data num partitions
    - "100"
    # Create the partitioned fact tables
    - "false"
    # Shuffle to get partitions coalesced into single files.
    - "false"
    # Logging set to WARN
    - "true"
  hadoopConf:
    # OSS
    "fs.oss.impl": "org.apache.hadoop.fs.aliyun.oss.AliyunOSSFileSystem"
    "fs.oss.endpoint": "oss-cn-beijing-internal.aliyuncs.com"
    "fs.oss.accessKeyId": "YOUR-ACCESS-KEY-ID"
    "fs.oss.accessKeySecret": "YOUR-ACCESS-KEY-SECRET"
  sparkConf:
    "spark.kubernetes.allocation.batch.size": "100"
    "spark.sql.adaptive.enabled": "true"
    "spark.eventLog.enabled": "true"
    "spark.eventLog.dir": "oss://cloudnativeai/spark/spark-events"
  driver:
    cores: 6
    memory: "20480m"
    serviceAccount: spark
  executor:
    instances: 20
    cores: 8
    memory: "61440m"
    memoryOverhead: 2g
  restartPolicy:
    type: Never
```

执行命令，开始生成数据

```shell
kubectl apply -f tpcds-data-generator.yaml
```

### 2）Benchmark任务

查询任务分三次，第一次直接用spark读取oss上的1TB数据，执行benchmark；第二次利用alluxio做分布式缓存，oss上的数据会先加载到alluxio中，spark从alluxio中读取缓存数据做benchmark；第三次修改第二次任务中的oss结果存放路径，此时Alluxio中的缓存数据还在，重新运行benchmark。通过这三次任务对比，可以看到使用alluxio缓存加速后，有较大的性能提升。

#### Benchmark

tpcds-benchmark.yaml

```yaml
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: SparkApplication
metadata:
  name: tpcds-benchmark-sql
  namespace: default
spec:
  type: Scala
  mode: cluster
  image: registry.cn-beijing.aliyuncs.com/yukong/ack-spark-benchmark:1.0.0
  imagePullPolicy: Always
  sparkVersion: 2.4.5
  mainClass: com.aliyun.spark.benchmark.tpcds.BenchmarkSQL
  mainApplicationFile: "local:///opt/spark/jars/ack-spark-benchmark-assembly-0.1.jar"
  arguments:
    # TPC-DS data localtion
    - "oss://cloudnativeai/spark/data/tpc-ds-data/1000g"
    # results location
    - "oss://cloudnativeai/spark/result/tpcds-benchmark-result-1000g"
    # Path to kit in the docker image
    - "/tmp/tpcds-kit/tools"
    # Data Format
    - "parquet"
    # Scale factor (in GB)
    - "1000"
    # Number of iterations
    - "1"
    # Optimize queries
    - "false"
    # Filter queries, will run all if empty - "q70-v2.4,q82-v2.4,q64-v2.4"
    - "q72-v2.4"
    # Logging set to WARN
    - "true"
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  restartPolicy:
    type: Never
  timeToLiveSeconds: 86400
  hadoopConf:
    # OSS
    "fs.oss.impl": "org.apache.hadoop.fs.aliyun.oss.AliyunOSSFileSystem"
    "fs.oss.endpoint": "oss-cn-beijing-internal.aliyuncs.com"
    "fs.oss.accessKeyId": "YOUR-ACCESS-KEY-ID"
    "fs.oss.accessKeySecret": "YOUR-ACCESS-KEY-SECRET"
  sparkConf:
    "spark.kubernetes.allocation.batch.size": "100"
    "spark.sql.adaptive.enabled": "true"
    "spark.eventLog.enabled": "true"
    "spark.eventLog.dir": "oss://cloudnativeai/spark/spark-events"
  volumes:
    - name: "spark-local-dir-1"
      hostPath:
        path: "/mnt/disk1"
        type: Directory
    - name: "spark-local-dir-2"
      hostPath:
        path: "/mnt/disk2"
        type: Directory
    - name: "spark-local-dir-3"
      hostPath:
        path: "/mnt/disk3"
        type: Directory
    - name: "spark-local-dir-4"
      hostPath:
        path: "/mnt/disk4"
        type: Directory
    - name: "spark-local-dir-5"
      hostPath:
        path: "/mnt/disk5"
        type: Directory
    - name: "spark-local-dir-6"
      hostPath:
        path: "/mnt/disk6"
        type: Directory
    - name: "spark-local-dir-7"
      hostPath:
        path: "/mnt/disk7"
        type: Directory
    - name: "spark-local-dir-8"
      hostPath:
        path: "/mnt/disk8"
        type: Directory
    - name: "spark-local-dir-9"
      hostPath:
        path: "/mnt/disk9"
        type: Directory
    - name: "spark-local-dir-10"
      hostPath:
        path: "/mnt/disk10"
        type: Directory
    - name: "spark-local-dir-11"
      hostPath:
        path: "/mnt/disk11"
        type: Directory
    - name: "spark-local-dir-12"
      hostPath:
        path: "/mnt/disk12"
        type: Directory
  driver:
    cores: 5
    memory: "20480m"
    labels:
      version: 2.4.5
      spark-app: spark-tpcds
      role: driver
    serviceAccount: spark
  executor:
    cores: 7
    instances: 20
    memory: "20480m"
    memoryOverhead: "8g"
    labels:
      version: 2.4.5
      role: executor
    volumeMounts:
      - name: "spark-local-dir-1"
        mountPath: "/mnt/disk1"
      - name: "spark-local-dir-2"
        mountPath: "/mnt/disk2"
      - name: "spark-local-dir-3"
        mountPath: "/mnt/disk3"
      - name: "spark-local-dir-4"
        mountPath: "/mnt/disk4"
      - name: "spark-local-dir-5"
        mountPath: "/mnt/disk5"
      - name: "spark-local-dir-6"
        mountPath: "/mnt/disk6"
      - name: "spark-local-dir-7"
        mountPath: "/mnt/disk7"
      - name: "spark-local-dir-8"
        mountPath: "/mnt/disk8"
      - name: "spark-local-dir-9"
        mountPath: "/mnt/disk9"
      - name: "spark-local-dir-10"
        mountPath: "/mnt/disk10"
      - name: "spark-local-dir-11"
        mountPath: "/mnt/disk11"
      - name: "spark-local-dir-12"
        mountPath: "/mnt/disk12"
```



执行以下命令，开始benchmark任务

```shell
kubectl apply -f tpcds-benchmark.yaml
```



#### Benchmark with alluxio cold

tpcds-benchmark-with-alluxio.yaml

```yaml
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: SparkApplication
metadata:
  name: tpcds-benchmark-sql
  namespace: default
spec:
  type: Scala
  mode: cluster
  image: registry.cn-beijing.aliyuncs.com/yukong/ack-spark-benchmark:1.0.0
  imagePullPolicy: Always
  sparkVersion: 2.4.5
  mainClass: com.aliyun.spark.benchmark.tpcds.BenchmarkSQL
  mainApplicationFile: "local:///opt/spark/jars/ack-spark-benchmark-assembly-0.1.jar"
  arguments:
    # TPC-DS data localtion
    - "alluxio://alluxio-master-0.alluxio.svc.cluster.local:19998/spark/data/tpc-ds-data/1000g"
    # results location
    - "oss://cloudnativeai/spark/result/tpcds-benchmark-result-1000g-alluxio"
    # Path to kit in the docker image
    - "/tmp/tpcds-kit/tools"
    # Data Format
    - "parquet"
    # Scale factor (in GB)
    - "1000"
    # Number of iterations
    - "1"
    # Optimize queries
    - "false"
    # Filter queries, will run all if empty - "q70-v2.4,q82-v2.4,q64-v2.4"
    - ""
    # Logging set to WARN
    - "true"
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  restartPolicy:
    type: Never
  timeToLiveSeconds: 86400
  hadoopConf:
    # OSS
    "fs.oss.impl": "org.apache.hadoop.fs.aliyun.oss.AliyunOSSFileSystem"
    "fs.oss.endpoint": "oss-cn-beijing-internal.aliyuncs.com"
    "fs.oss.accessKeyId": "YOUR-ACCESS-KEY-ID"
    "fs.oss.accessKeySecret": "YOUR-ACCESS-KEY-SECRET"
  sparkConf:
    "spark.driver.extraLibraryPath": "/opt/spark/lib/native"
    "spark.executor.extraLibraryPath": "/opt/spark/lib/native"
    "spark.scheduler.listenerbus.eventqueue.capacity": "10000"
    "spark.kubernetes.allocation.batch.size": "200"
    "spark.eventLog.enabled": "true"
    "spark.eventLog.dir": "oss://cloudnativeai/spark/spark-events"
    "spark.sql.dynamicPartitionPruning.enabled": "true"
    #CBO
    "spark.sql.cbo.enabled": "true"
    "spark.sql.cbo.joinReorder.enabled": "true"
    "spark.sql.cbo.joinReorder.dp.star.filter": "false"
    "spark.sql.cbo.joinReorder.dp.threshold": "12"
    "spark.sql.cbo.outerJoinReorder.enabled": "true"
    #AE
    "spark.sql.adaptive.enabled": "true"
    "spark.sql.adaptive.maxNumPostShufflePartitions": "400"
    "spark.sql.adaptive.minNumPostShufflePartitions": "50"
    "spark.sql.adaptive.join.enabled": "true"
    "spark.sql.autoBroadcastJoinThreshold": "134217728"
    "spark.sql.adaptive.skewedJoin.enabled": "false"
    #RF
    "spark.sql.dynamic.runtime.filter.enabled": "true"
    "spark.sql.dynamic.runtime.filter.bbf.enabled": "false"
    "spark.sql.dynamic.runtime.filter.table.size.lower.limit": "1069547520"
    "spark.sql.dynamic.runtime.filter.table.size.upper.limit": "5368709120"
    #shuffle without AE
    "spark.sql.shuffle.partitions": "400"
    #Other
    "spark.sql.uncorrelated.scalar.subquery.preexecution.enabled": "true"
    "spark.sql.emr.fileindex.enabled": "false"
    "spark.sql.intersect.groupby.placement": "true"
    "spark.sql.extract.common.conjunct.filter": "true"
    "spark.sql.infer.filter.from.joincondition": "true"
    # dynamic
#    "spark.dynamicAllocation.enabled": "true"
#    "spark.dynamicAllocation.minExecutors": "0"
#    "spark.dynamicAllocation.maxExecutors": "200"
#    "spark.dynamicAllocation.executorIdleTimeout": "3m"
#    "spark.dynamicAllocation.schedulerBacklogTimeout": "1s"
#    "spark.shuffle.service.enabled": "true"
#     java
#    spark.executor.extraJavaOptions: "-XX:MaxDirectMemorySize=32g -XX:-PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps"
#    spark.driver.extraJavaOptions: "-XX:-PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps"
#    spark.memory.fraction: "0.8"
  volumes:
    - name: "spark-local-dir-1"
      hostPath:
        path: "/mnt/disk1"
        type: Directory
    - name: "spark-local-dir-2"
      hostPath:
        path: "/mnt/disk2"
        type: Directory
    - name: "spark-local-dir-3"
      hostPath:
        path: "/mnt/disk3"
        type: Directory
    - name: "spark-local-dir-4"
      hostPath:
        path: "/mnt/disk4"
        type: Directory
    - name: "spark-local-dir-5"
      hostPath:
        path: "/mnt/disk5"
        type: Directory
    - name: "spark-local-dir-6"
      hostPath:
        path: "/mnt/disk6"
        type: Directory
    - name: "spark-local-dir-7"
      hostPath:
        path: "/mnt/disk7"
        type: Directory
    - name: "spark-local-dir-8"
      hostPath:
        path: "/mnt/disk8"
        type: Directory
    - name: "spark-local-dir-9"
      hostPath:
        path: "/mnt/disk9"
        type: Directory
    - name: "spark-local-dir-10"
      hostPath:
        path: "/mnt/disk10"
        type: Directory
    - name: "spark-local-dir-11"
      hostPath:
        path: "/mnt/disk11"
        type: Directory
    - name: "spark-local-dir-12"
      hostPath:
        path: "/mnt/disk12"
        type: Directory
  driver:
    cores: 5
    memory: "20480m"
    labels:
      version: 2.4.5
      spark-app: spark-tpcds
      role: driver
    serviceAccount: spark
  executor:
    cores: 7
    instances: 20
    memory: "20480m"
    memoryOverhead: "8g"
    labels:
      version: 2.4.5
      role: executor
    volumeMounts:
      - name: "spark-local-dir-1"
        mountPath: "/mnt/disk1"
      - name: "spark-local-dir-2"
        mountPath: "/mnt/disk2"
      - name: "spark-local-dir-3"
        mountPath: "/mnt/disk3"
      - name: "spark-local-dir-4"
        mountPath: "/mnt/disk4"
      - name: "spark-local-dir-5"
        mountPath: "/mnt/disk5"
      - name: "spark-local-dir-6"
        mountPath: "/mnt/disk6"
      - name: "spark-local-dir-7"
        mountPath: "/mnt/disk7"
      - name: "spark-local-dir-8"
        mountPath: "/mnt/disk8"
      - name: "spark-local-dir-9"
        mountPath: "/mnt/disk9"
      - name: "spark-local-dir-10"
        mountPath: "/mnt/disk10"
      - name: "spark-local-dir-11"
        mountPath: "/mnt/disk11"
      - name: "spark-local-dir-12"
        mountPath: "/mnt/disk12"
```

执行以下命令，开始通过alluxio缓存加速的benchmark任务

```shell
kubectl apply -f tpcds-benchmark-with-alluxio.yaml
```

#### Benchmark with alluxio warm

alluio在第一次执行时，会从oss读取数据，缓存在alluxio中，所以会比较慢。在第一次alluxio缓存加速benchmark测试完后，可以再测试几次对比下效果。