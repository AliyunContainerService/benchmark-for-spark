EMR Spark是运行在阿里云平台上的大数据处理解决方案，在开源版Apache Spark的基础上做了大量性能、功能以及稳定性方面的改造，并且在和阿里云基础服务的适配上做了非常多的工作。主要有以下核心技术：

- 实现SparkSQL事务功能，支持update、delete语句。
- 实现PK、FK、NOT NULL等SQL Constraint，并应用在SQL优化中。
- 实现Relational Cache：SparkSQL的物化视图。
- 实现多租户高可用的SparkSQL JDBC Server。
- SparkSQL部分性能优化列表：
- 支持Runtime Filter。
- 使用Adaptive Execution，可在运行时调整作业行为。
- CBO Join Reorder进一步优化，支持遗传算法。
- Shuffle流程优化，构建异步非阻塞的Shuffle IO。