package com.aliyun.ack.spark.tpcds

import scala.util.Try

import com.databricks.spark.sql.perf.tpcds.{TPCDS, TPCDSTables}
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._
import org.apache.spark.sql.functions.col
import org.apache.log4j.{Level, LogManager}
import org.apache.spark.sql.types.DoubleType
import scopt.OParser

case class BenchmarkConfig(
    tpcdsDataPath: String = "",
    outputPath: String = "",
    dsdgenPath: String = "/opt/tpcds-kit/tools",
    format: String = "parquet",
    scaleFactor: Int = 1,
    iterations: Int = 1,
    optimizeQueries: Boolean = false,
    queries: String = "",
    onlyWarn: Boolean = false
)

object Benchmark {

  def main(args: Array[String]): Unit = {
    val builder = OParser.builder[BenchmarkConfig]

    val parser = {
      import builder._
      OParser.sequence(
        programName("Benchmark"),
        opt[String]("data")
          .required()
          .valueName("<path>")
          .action((x, c) => c.copy(tpcdsDataPath = x))
          .text("path of tpcds data"),
        opt[String]("result")
          .required()
          .valueName("<path>")
          .action((x, c) => c.copy(outputPath = x))
          .text("path of benchmark result"),
        opt[String]("dsdgen")
          .optional()
          .valueName("<path>")
          .action((x, c) => c.copy(dsdgenPath = x))
          .text("path of tpcds-kit tools"),
        opt[String]("format")
          .valueName("<format>")
          .action((x, c) => c.copy(format = x))
          .text("data format"),
        opt[Int]("scale-factor")
          .optional()
          .valueName("<sf>")
          .action((x, c) => c.copy(scaleFactor = x))
          .text("scale factor of tpcds data (in GB)"),
        opt[Int]("iterations")
          .optional()
          .action((x, c) => c.copy(iterations = x))
          .text("number of iterations"),
        opt[Unit]("optimize-queries")
          .optional()
          .action((_, c) => c.copy(optimizeQueries = true))
          .text("whether to optimize queries"),
        opt[String]("queries")
          .optional()
          .action((x, c) => c.copy(queries = x))
          .text("queries to execute(empty means all queries)"),
        opt[Unit]("only-warn")
          .optional()
          .action((_, c) => c.copy(onlyWarn = true))
          .text("set logging level to warning")
      )
    }

    val option = OParser.parse(parser, args, BenchmarkConfig())
    if (option.isEmpty) {
      System.exit(1)
    }
    val config = option.get.asInstanceOf[BenchmarkConfig]
    val databaseName = "tpcds_db"
    val timeout = 24 * 60 * 60

    println(s"DATA DIR is ${config.tpcdsDataPath}")

    val spark = SparkSession.builder
      .appName(s"TPCDS SQL Benchmark ${config.scaleFactor} GB")
      .getOrCreate()

    if (config.onlyWarn) {
      println(s"Only WARN")
      LogManager.getLogger("org").setLevel(Level.WARN)
    }

    val tables = new TPCDSTables(
      spark.sqlContext,
      dsdgenDir = config.dsdgenPath,
      scaleFactor = config.scaleFactor.toString,
      useDoubleForDecimal = false,
      useStringForDate = false
    )

    if (config.optimizeQueries) {
      Try {
        spark.sql(s"create database $databaseName")
      }
      tables.createExternalTables(
        config.tpcdsDataPath,
        config.format,
        databaseName,
        overwrite = true,
        discoverPartitions = true
      )
      tables.analyzeTables(databaseName, analyzeColumns = true)
      spark.conf.set("spark.sql.cbo.enabled", "true")
    } else {
      tables.createTemporaryTables(config.tpcdsDataPath, config.format)
    }

    val tpcds = new TPCDS(spark.sqlContext)

    var query_filter: Seq[String] = Seq()
    if (!config.queries.isEmpty) {
      println(s"Running only queries: ${config.queries}")
      query_filter = config.queries.split(",").toSeq
    }

    val filtered_queries = query_filter match {
      case Seq() => tpcds.tpcds2_4Queries
      case _ => tpcds.tpcds2_4Queries.filter(q => query_filter.contains(q.name))
    }

    // Start experiment
    val experiment = tpcds.runExperiment(
      filtered_queries,
      iterations = config.iterations,
      resultLocation = config.outputPath,
      forkThread = true
    )

    experiment.waitForFinish(timeout)

    // Collect general results
    val resultPath = experiment.resultPath
    println(s"Reading result at ${resultPath}")
    val specificResultTable = spark.read.json(resultPath)
    specificResultTable.show()

    // Summarize results
    val result = specificResultTable
      .withColumn("result", explode(col("results")))
      .withColumn("executionSeconds", col("result.executionTime") / 1000)
      .withColumn("queryName", col("result.name"))
    result.select("iteration", "queryName", "executionSeconds").show()

    val aggResults = result
      .groupBy("queryName")
      .agg(
        min("executionSeconds").cast(DoubleType).as("MinRuntimeInSeconds"),
        max("executionSeconds").cast(DoubleType).as("MaxRuntimeInSeconds"),
        mean("executionSeconds").cast(DoubleType).as("MeanRuntimeInSeconds"),
        stddev_pop("executionSeconds")
          .cast(DoubleType)
          .as("StandardDeviationInSeconds")
      )
      .orderBy("queryName")

    aggResults
      .repartition(1)
      .write
      .csv(s"${resultPath}/summary.csv")

    aggResults.show(105)

    spark.stop()
  }
}
