## 为什么要在Kubernetes上运行Spark

从spark 2.3版本开始，我们可以在Kubernetes上运行和管理Spark资源。在此之前，只能在Hadoop Yarn、Apache Mesos或独立集群上运行Spark。在Kubernetes上运行Spark应用有以下优点：

- 通过把Spark应用和依赖项打包成容器，享受容器的各种优点，很容易的解决Hadoop版本不匹配和兼容性问题。还可以给容器镜像打上标签控制版本，这样如果需要测试不同版本的Spark或者依赖项的话，选择对应的版本做到了。

- 重用Kubernetes生态的各种组件，比如监控、日志。把Spark工作负载部署在已有的的Kubernetes基础设施中，能够快速开始工作，大大减少了运维成本。
- 支持多租户，可利用Kubernetes的namespace和ResourceQuota做用户粒度的资源调度，利用Kubernetes的节点选择机制保证Spark工作负载得到专用的资源。另外，由于driver pods创建executor pods，我们可以用Kubernetes service account控制权限，利用Role或者Cluster Role定义细粒度访问权限，安全的运行工作负载，避免受其他工作负载影响。

- 把Spark和管理数据生命周期的应用运行在同一个集群中，可以使用单个编排机制构建端到端生命周期的解决方案，并能很容易的复制到其他区域部署，甚至是在私有化环境部署。

阿里云容器服务Kubernetes版（简称 ACK）提供高性能可伸缩的容器应用管理能力，支持企业级容器化应用的全生命周期管理。整合阿里云虚拟化、存储、网络和安全能力，打造云端最佳容器化应用运行环境，我们将介绍在在ACK上运行Spark工作负载的最佳实践和benchmark结果。

## Spark on Kubernetes Operator

[Spark on Kubernetes Operator](https://github.com/AliyunContainerService/spark-on-k8s-operator)帮助用户在Kubernetes上像其他工作负载一样用通用的方式运行Spark Application，它使用Kubernetes custom resources来配置、运行Spark Application，并展现其状态，需要Spark 2.3及以上的版本来支持Kubernetes调度。

## TPC-DS Benchmark

[TPC-DS](http://www.tpc.org/tpcds/)由第三方社区创建和维护，是事实上的做性能压测，协助确定解决方案的工业标准。这个测试集包含对大数据集的统计、报表生成、联机查询、数据挖掘等复杂应用，测试用的数据和值是有倾斜的，与真实数据一致。可以说TPC-DS是与真实场景非常接近的一个测试集，也是难度较大的一个测试集。

TPC-DS包含104个query，覆盖了SQL 2003的大部分标准，有99条压测query，其中的4条query各有2个变体（14,23,24,39），最后还有一个“s_max”query进行全量扫描和最大的一些表的聚合。

这个基准测试有以下几个主要特点：

- 遵循SQL 2003的语法标准，SQL案例比较复杂；
- 分析的数据量大，并且测试案例是在回答真实的商业问题；
- 测试案例中包含各种业务模型(如分析报告型，迭代式的联机分析型，数据挖掘型等)；
- 几乎所有的测试案例都有很高的IO负载和CPU计算需求。

这里我们采用TPC-DS来评测Spark在ACK上的性能。

## 快速开始

我们从在ACK上搭建环境，并运行社区版Spark和分布式缓存框架Alluxio开始，介绍如何在ACK运行Spark工作负载，详情请参考[快速开始](docs/quickstart/benchmark_env.md)。

## 性能优化

- [Spark Operator优化](docs/performance/spark-operator.md)
- [Spark优化](docs/performance/emr-spark.md)
- [Shuffle优化](docs/performance/remote-shuffle-service.md)
- [分布式缓存优化](docs/performance/jindofs.md)

## 最佳实践

- [使用EMR Spark运行Spark工作负载](./docs/bestpractice/emrspark.md)
- [使用EMR Spark + Remote Shuffle Service运行Spark工作负载](./docs/bestpractice/emrspark-ess.md)
- [使用EMR Spark + JindoFS运行Spark工作负载](./docs/bestpractice/emrspark-jindofs.md)
- [使用EMR Spark + JindoFS + Remote Shuffle Service运行Spark工作负载](./docs/bestpractice/emrspark-ess-jindofs.md)

## 鸣谢
本项目参考了[eks-spark-benchmark](https://github.com/aws-samples/eks-spark-benchmark)，感谢其优秀的工作。