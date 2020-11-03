Spark on Kubernetes Operator帮助用户在Kubernetes上像其他工作负载一样用通用的方式运行Spark Application，为了让Spark能更好的运行在Kubernetes中，我们对Spark Operator也做了一些优化工作。

- 相比社区版Spark Operator实现中的阻塞串行调度，ACK版本支持非阻塞并行调度，调度性能可达350 Pods/s，能够快速把Spark作业调度到节点上。
- 增强Spark Kernel对Kubernetes原生能力的支持，如Tolerations、Labels、Node Name。
- Spark Kernel支持dynamic allocation，资源利用率可提升30%。
- 支持设置Spark Job使用自定义调度器。