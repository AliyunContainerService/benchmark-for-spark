本项目包含在ACK上运行Spark工作负载的最佳实践和benchmark结果。

## 为什么要在Kubernetes上运行Spark

从spark 2.3版本开始，我们可以在Kubernetes上运行和管理Spark资源。在此之前，只能在Hadoop Yarn、Apache Mesos或独立集群上运行Spark。在Kubernetes上运行Spark应用有以下优点：

- 通过把Spark应用和依赖项打包成容器，享受容器的各种优点，很容易的解决Hadoop版本不匹配和兼容性问题。还可以给容器镜像打上标签控制版本，这样如果需要测试不同版本的Spark或者依赖项的话，选择对应的版本做到了。

- 重用Kubernetes生态的各种组件，比如监控、日志。把Spark工作负载部署在已有的的Kubernetes基础设施中，能够快速开始工作，大大减少了运维成本。
- 支持多租户，可利用Kubernetes的namespace和ResourceQuota做用户粒度的资源调度，利用Kubernetes的节点选择机制保证Spark工作负载得到专用的资源。另外，由于driver pods创建executor pods，我们可以用Kubernetes service account控制权限，利用Role或者Cluster Role定义细粒度访问权限，安全的运行工作负载，避免受其他工作负载影响。

- 把Spark和管理数据生命周期的应用运行在同一个集群中，可以使用单个编排机制构建端到端生命周期的解决方案，并能很容易的复制到其他区域部署，甚至是在私有化环境部署。


## Spark on Kubernetes Operator

[Spark on Kubernetes Operator](https://github.com/AliyunContainerService/spark-on-k8s-operator)帮助用户在Kubernetes上像其他工作负载一样用通用的方式运行Spark Application，它使用Kubernetes custom resources来配置、运行Spark Application，并展现其状态，需要Spark 2.3及以上的版本来支持Kubernetes调度。


## Alluxio

[Alluxio](https://www.alluxio.io/)是一个面向基于云的数据分析和人工智能的开源的数据编排技术。 它为数据驱动型应用和存储系统构建了桥梁, 将数据从存储层移动到距离数据驱动型应用更近的位置从而能够更容易被访问。 这还使得应用程序能够通过一个公共接口连接到许多存储系统。 Alluxio内存至上的层次化架构使得数据的访问速度能比现有方案快几个数量级。

在大数据生态系统中，Alluxio 位于数据驱动框架或应用（如 Apache Spark、Presto、Tensorflow、Apache Flink 等）和各种持久化存储系统（如 Amazon S3、Google Cloud Storage、Alibaba OSS 等）之间。 Alluxio 统一了存储在这些不同存储系统中的数据，为其上层数据驱动型应用提供统一的客户端 API 和全局命名空间。

![alluxio-overview.jpg](https://intranetproxy.alipay.com/skylark/lark/0/2020/jpeg/6888/1595841315289-3362a5a7-ade0-4ba0-8f23-1bfdb054bd91.jpeg?x-oss-process=image%2Fresize%2Cw_1500)

我们将会采用Alluxio通过缓存的方式加速Spark访问持久化存储系统中的数据。


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

在ACK上搭建环境并运行Spark TPC-DS benchmark的教程请参考[快速开始](docs/quickstart/benchmark_env.md)。

## 性能优化

- [Kubernetes集群优化](docs/performance/kubernetes.md)
- [Spark Operator优化](docs/performance/operator.md)
- [Spark优化](docs/performance/emr-spark.md)
- [Shuffle优化](docs/performance/shuffle.md)
- [分布式缓存优化](docs/performance/alluxio.md)
- [调度优化](docs/performance/scheduler.md)