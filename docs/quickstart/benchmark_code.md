1. [测试环境搭建](docs/quickstart/benchmark_env.md)
2. [测试代码开发](docs/quickstart/benchmark_code.md)
3. [Spark on ACK测试](docs/quickstart/benchmark_steps.md)
4. [测试结果分析](docs/quickstart/benchmark_result.md)
5. [问题排查定位](docs/quickstart/debugging_guide.md)

*说明：为了方便测试，已经提供了预制镜像（registry.cn-beijing.aliyuncs.com/yukong/ack-spark-benchmark:1.0.0），可以直接使用。*

### 准备工作

测试代码依赖databricks两个工具：一个是tpcds测试包，另一个是测试数据生成工具tpcds-kit。

#### 1）打包tpcds依赖jar

databricks的tpcds: https://github.com/databricks/spark-sql-perf

```shell
git clone https://github.com/databricks/spark-sql-perf.git
sbt package
```

得到jar包：spark-sql-perf_2.11-0.5.1-SNAPSHOT，作为测试项目的依赖。



#### 2）编译tpcds-kit

tpcds标准测试数据集生成工具: https://github.com/databricks/tpcds-kit

```shell
git clone https://github.com/davies/tpcds-kit.git
yum install gcc gcc-c++ bison flex cmake ncurses-devel
cd tpcds-kit/tools
cp Makefile.suite Makefile # 复制Makefile.suite为Makefile
make  
#验证
./dsqgen --help
```

编译后生成二进制可执行程序，本实验主要依赖两个：dsdgen（数据生成）和dsqgen（查询生成）

### 编写代码

#### 1）生成数据

DataGeneration.scala

```scala
package com.aliyun.spark.benchmark.tpcds

import com.databricks.spark.sql.perf.tpcds.TPCDSTables
import org.apache.log4j.{Level, LogManager}
import org.apache.spark.sql.SparkSession

import scala.util.Try

object DataGeneration {
  def main(args: Array[String]) {
    val tpcdsDataDir = args(0)
    val dsdgenDir = args(1)
    val format = Try(args(2).toString).getOrElse("parquet")
    val scaleFactor = Try(args(3).toString).getOrElse("1")
    val genPartitions = Try(args(4).toInt).getOrElse(100)
    val partitionTables = Try(args(5).toBoolean).getOrElse(false)
    val clusterByPartitionColumns = Try(args(6).toBoolean).getOrElse(false)
    val onlyWarn = Try(args(7).toBoolean).getOrElse(false)

    println(s"DATA DIR is $tpcdsDataDir")
    println(s"Tools dsdgen executable located in $dsdgenDir")
    println(s"Scale factor is $scaleFactor GB")

    val spark = SparkSession
      .builder
      .appName(s"TPCDS Generate Data $scaleFactor GB")
      .getOrCreate()

    if (onlyWarn) {
      println(s"Only WARN")
      LogManager.getLogger("org").setLevel(Level.WARN)
    }

    val tables = new TPCDSTables(spark.sqlContext,
      dsdgenDir = dsdgenDir,
      scaleFactor = scaleFactor,
      useDoubleForDecimal = false,
      useStringForDate = false)

    println(s"Generating TPCDS data")

    tables.genData(
      location = tpcdsDataDir,
      format = format,
      overwrite = true, // overwrite the data that is already there
      partitionTables = partitionTables,  // create the partitioned fact tables
      clusterByPartitionColumns = clusterByPartitionColumns, // shuffle to get partitions coalesced into single files.
      filterOutNullPartitionValues = false, // true to filter out the partition with NULL key value
      tableFilter = "", // "" means generate all tables
      numPartitions = genPartitions) // how many dsdgen partitions to run - number of input tasks.

    println(s"Data generated at $tpcdsDataDir")

    spark.stop()
  }
}
```

#### 2）查询数据

BenchmarkSQL.scala

```scala
package com.aliyun.spark.benchmark.tpcds

import com.databricks.spark.sql.perf.tpcds.{TPCDS, TPCDSTables}
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._
import org.apache.spark.sql.functions.col
import org.apache.log4j.{Level, LogManager}
import scala.util.Try

object BenchmarkSQL {
  def main(args: Array[String]) {
    val tpcdsDataDir = args(0)
    val resultLocation = args(1)
    val dsdgenDir = args(2)
    val format = Try(args(3).toString).getOrElse("parquet")
    val scaleFactor = Try(args(4).toString).getOrElse("1")
    val iterations = args(5).toInt
    val optimizeQueries = Try(args(6).toBoolean).getOrElse(false)
    val filterQueries = Try(args(7).toString).getOrElse("")
    val onlyWarn = Try(args(8).toBoolean).getOrElse(false)

    val databaseName = "tpcds_db"
    val timeout = 24*60*60

    println(s"DATA DIR is $tpcdsDataDir")

    val spark = SparkSession
      .builder
      .appName(s"TPCDS SQL Benchmark $scaleFactor GB")
      .getOrCreate()

    if (onlyWarn) {
      println(s"Only WARN")
      LogManager.getLogger("org").setLevel(Level.WARN)
    }

    val tables = new TPCDSTables(spark.sqlContext,
      dsdgenDir = dsdgenDir,
      scaleFactor = scaleFactor,
      useDoubleForDecimal = false,
      useStringForDate = false)

    if (optimizeQueries) {
      Try {
        spark.sql(s"create database $databaseName")
      }
      tables.createExternalTables(tpcdsDataDir, format, databaseName, overwrite = true, discoverPartitions = true)
      tables.analyzeTables(databaseName, analyzeColumns = true)
      spark.conf.set("spark.sql.cbo.enabled", "true")
    } else {
      tables.createTemporaryTables(tpcdsDataDir, format)
    }

    val tpcds = new TPCDS(spark.sqlContext)

    var query_filter : Seq[String] = Seq()
    if (!filterQueries.isEmpty) {
      println(s"Running only queries: $filterQueries")
      query_filter = filterQueries.split(",").toSeq
    }

    val filtered_queries = query_filter match {
      case Seq() => tpcds.tpcds2_4Queries
      case _ => tpcds.tpcds2_4Queries.filter(q => query_filter.contains(q.name))
    }

    // Start experiment
    val experiment = tpcds.runExperiment(
      filtered_queries,
      iterations = iterations,
      resultLocation = resultLocation,
      forkThread = true)

    experiment.waitForFinish(timeout)

    // Collect general results
    val resultPath = experiment.resultPath
    println(s"Reading result at $resultPath")
    val specificResultTable = spark.read.json(resultPath)
    specificResultTable.show()

    // Summarize results
    val result = specificResultTable
      .withColumn("result", explode(col("results")))
      .withColumn("executionSeconds", col("result.executionTime")/1000)
      .withColumn("queryName", col("result.name"))
    result.select("iteration", "queryName", "executionSeconds").show()
    println(s"Final results at $resultPath")

    val aggResults = result.groupBy("queryName").agg(
      callUDF("percentile", col("executionSeconds").cast("long"), lit(0.5)).as('medianRuntimeSeconds),
      callUDF("min", col("executionSeconds").cast("long")).as('minRuntimeSeconds),
      callUDF("max", col("executionSeconds").cast("long")).as('maxRuntimeSeconds)
    ).orderBy(col("queryName"))
    aggResults.repartition(1).write.csv(s"$resultPath/summary.csv")
    aggResults.show(105)

    spark.stop()
  }
}
```

### 镜像制作

测试代码编译成jar后，可以和依赖的其他jar包一起，制作成镜像供测试使用，Dockerfile如下：

```dockerfile
FROM registry.cn-hangzhou.aliyuncs.com/acs/spark:ack-2.4.5-f757ab6
RUN mkdir -p /opt/spark/jars
RUN mkdir -p /tmp/tpcds-kit
COPY ./target/scala-2.11/spark-tpcds-assembly-0.1.jar /opt/spark/jars/
COPY ./lib/*.jar /opt/spark/jars/
COPY ./tpcds-kit/tools.tar.gz /tmp/tpcds-kit/
RUN cd /tmp/tpcds-kit/ && tar -xzvf tools.tar.gz
```
