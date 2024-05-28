package com.aliyun.ack.spark.tpcds

import scala.util.Try

import com.databricks.spark.sql.perf.tpcds.TPCDSTables
import org.apache.log4j.{Level, LogManager}
import org.apache.spark.sql.SparkSession
import scopt.OParser

case class DataGenerationConfig(
    outputPath: String = "",
    dsdgenPath: String = "/opt/tpcds-kit/tools",
    format: String = "parquet",
    scaleFactor: Int = 1,
    patitionTable: Boolean = false,
    numPartitions: Int = 1,
    coalesced: Boolean = false,
    onlyWarn: Boolean = false
)

object DataGeneration {

  def main(args: Array[String]): Unit = {

    val builder = OParser.builder[DataGenerationConfig]

    val parser = {
      import builder._
      OParser.sequence(
        programName("DataGeneration"),
        opt[String]("output")
          .required()
          .valueName("<path>")
          .action((x, c) => c.copy(outputPath = x))
          .text("output path of tpcds data"),
        opt[String]("dsdgen")
          .optional()
          .valueName("<path>")
          .action((x, c) => c.copy(dsdgenPath = x))
          .text("path of tpcds-kit tools"),
        opt[String]("format")
          .optional()
          .valueName("<format>")
          .action((x, c) => c.copy(format = x))
          .text("data format"),
        opt[Int]("scale-factor")
          .optional()
          .valueName("<sf>")
          .action((x, c) => c.copy(scaleFactor = x))
          .text("scale factor of tpcds data (in GB)"),
        opt[Unit]("create-partitions")
          .action((_, c) => c.copy(patitionTable = true))
          .optional()
          .text("whether to optimize queries"),
        opt[Int]("num-partitions")
          .optional()
          .action((x, c) => c.copy(numPartitions = x))
          .text("number of partitions"),
        opt[Unit]("coalesced")
          .optional()
          .action((_, c) => c.copy(coalesced = true))
          .text(
            "whether to shuffle to get partitions coalesced into single files"
          ),
        opt[Unit]("only-warn")
          .optional()
          .action((_, c) => c.copy(onlyWarn = true))
          .text("set logging level to warning")
      )
    }

    val option = OParser.parse(parser, args, DataGenerationConfig())
    if (option.isEmpty) {
      System.exit(1)
    }
    val config = option.get.asInstanceOf[DataGenerationConfig]

    println(s"DATA DIR is ${config.outputPath}")
    println(s"Tools dsdgen executable located in ${config.dsdgenPath}")
    println(s"Scale factor is ${config.scaleFactor} GB")

    val spark = SparkSession.builder
      .appName(s"TPCDS Generate Data ${config.scaleFactor} GB")
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

    println(s"Generating TPCDS data")

    tables.genData(
      location = config.outputPath,
      format = config.format,
      overwrite = true, // overwrite the data that is already there
      partitionTables =
        config.patitionTable, // create the partitioned fact tables
      clusterByPartitionColumns =
        config.coalesced, // shuffle to get partitions coalesced into single files.
      filterOutNullPartitionValues =
        false, // true to filter out the partition with NULL key value
      tableFilter = "", // "" means generate all tables
      numPartitions =
        config.numPartitions // how many dsdgen partitions to run - number of input tasks.
    )

    println(s"Data generated at ${config.outputPath}")

    spark.stop()
  }
}
