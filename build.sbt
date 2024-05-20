ThisBuild / organization := "com.aliyun.ack"
ThisBuild / version := "0.1"
ThisBuild / scalaVersion := "2.12.18"

val sparkVersion = "3.3.2"

lazy val benchmark = (project in file("."))
  .settings(
    name := "spark-tpcds-benchmark",
    libraryDependencies ++= Seq(
      "org.apache.spark" %% "spark-core" % sparkVersion % "provided",
      "org.apache.spark" %% "spark-sql" % sparkVersion % "provided",
      "com.github.scopt" %% "scopt" % "4.1.0",
      "com.aliyun.dfs" % "aliyun-sdk-dfs" % "1.0.3",
      "com.aliyun.oss" % "aliyun-sdk-oss" % "3.4.1",
      "org.jdom" % "jdom" % "1.1"
    ),
    javacOptions ++= Seq("-source", "1.8", "-target", "1.8")
  )
