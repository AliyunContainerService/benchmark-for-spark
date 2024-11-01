ThisBuild / organization := "com.aliyun.ack"
ThisBuild / version := "0.1"
ThisBuild / scalaVersion := "2.12.20"

val sparkVersion = "3.5.3"

lazy val benchmark = (project in file("."))
  .settings(
    name := "spark-tpcds-benchmark",
    libraryDependencies ++= Seq(
      "org.apache.spark" %% "spark-core" % sparkVersion % "provided",
      "org.apache.spark" %% "spark-sql" % sparkVersion % "provided",
      "com.github.scopt" %% "scopt" % "4.1.0"
    ),
    javacOptions ++= Seq("-source", "1.8", "-target", "1.8")
  )
