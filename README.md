# Spark on ACK 最佳实践和基准测试

[Apache Spark](https://spark.apache.org/) 是一种专门为大规模数据处理而设计的快速且通用的计算引擎，并已经广泛应用于各行各业的大数据处理场景中。

[阿里云容器服务 Kubernetes 版](https://help.aliyun.com/zh/ack/)（Container Service for Kubernetes，简称容器服务 ACK）提供高性能可伸缩的容器应用管理服务，支持企业级 Kubernetes 容器化应用的生命周期管理。

本文将介绍在容器服务 ACK 集群中运行 Spark 工作负载的最佳实践和基准测试结果。

## 为什么要在 Kubernetes 上运行 Spark 作业？

Spark 自 2.3 版本开始支持将作业提交至 Kubernetes 集群中，详情参见 [[SPARK-18278]](https://issues.apache.org/jira/browse/SPARK-18278)。在此之前，Spark 支持的集群管理器只有 Apache Hadoop Yarn、Apache Mesos 以及 Spark 自身实现的一个集群管理器 。

<!-- TODO: Kubernetes 的发展 -->

在 Kubernetes 上运行 Spark 工作负载有以下优点：

- **标准化和可移植性**：通过把 Spark 应用及其依赖打包成容器镜像，享受容器的各种优点，很容易的解决 Hadoop 版本不匹配和兼容性问题。还可以给容器镜像打上标签控制版本，这样如果需要测试不同版本的Spark或者依赖项的话，选择对应的版本做到了。
- **资源按需供给**：Spark 可以按需申请资源，例如申请 10 个 Executor，每个 Executor 分配 8 个 CPU core 和 32GB 内存，避免资源浪费。
- **认证和鉴权**：由于 Driver pod 负责创建多个 Executor pods，可以利用 Kubernetes 的 ServiceAccount 和 RBAC 资源（Role、ClusterRole 等）做权限控制，从而保证集群的安全性。
- **支持多租户**：可利用 Kubernetes 的命名空间机制（Namespace）和资源配额机制（ResourceQuota）做用户粒度资源隔离和资源分配，并利用 Kubernetes 的节点选择机制（NodeSelector）保证 Spark 工作负载可以获得专用的资源。
- **复用 Kubernetes 生态**：重用 Kubernetes 生态的各种组件，例如 Prometheus 监控、日志等。通过把 Spark 工作负载部署在已有的 Kubernetes 集群中，能够快速开始工作，大大降低运维成本。
- **Spark 多版本支持**：在传统的部署方式下，客户端使用的 Spark 版本必须和集群中使用的 Spark 版本一致。而在 Kubernetes 环境下，用户可以自定义 Spark 作业所使用的容器镜像，从而可以实现在一个 Kubernetes 集群中同时运行多个版本的 Spark 作业。
- **工作流编排**：把 Spark 和管理数据生命周期的应用运行在同一个集群中，可以使用业界流行的工作流编排解决方案（例如 [Apache Airflow](https://airflow.apache.org/) 和 [Argo Workflow]([https://](https://argoproj.github.io/argo-workflows/))）构建端到端的解决方案，并能很容易的复制到其他区域部署，甚至是在私有化环境中部署。

## 如何在 Kubernetes 上运行 Spark 作业？

在 Spark 中，作业通常由一个 Driver 进程和若干个 Executor 进程构成。在 Kubernetes 中，Pod 是集群中最小的可部署单元和执行单元。

将 Spark 作业运行在 Kubernetes 上的大致想法就是在单独的 Pod 中分别运行 Driver 进程和 Executor 进程。从 Spark Core 代码实现上来看，其最主要的组件是 `KubernetesClusterSchedulerBackend`，它是 `CoarseGrainedSchedulerBackend` 的一个子类，通过调用 Kubernetes API 创建和删除 Pod 来启动和停止 Spark 作业。

向 Kubernetes 集群提交 Spark 作业常见的有两种方式，一是使用 Spark 中自带的 `spark-submit` 脚本来提交作业，二是使用 [Spark Operator](https://github.com/kubeflow/spark-operator) 提交作业，下面将分别介绍这两种提交方式。

### spark-submit

客户端可以直接使用 `spark-submit` 命令提交 Spark 作业到 Kubernetes 集群中。

首先，我们需要给 Spark 作业中的 Driver pod 创建一个服务账号（ServiceAccount）并对其授予一定的权限，否则 Driver pod 会由于权限不足无法创建出 Executor pods，从而导致作业执行失败。

```yaml
# spark-rbac.yaml

apiVersion: v1
kind: ServiceAccount
metadata:
  name: spark

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: spark-role
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - services
  - configmaps
  verbs:
  - "*"

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: spark-rolebinding
subjects:
- kind: ServiceAccount
  name: spark
  namespace: default
roleRef:
  kind: Role
  name: spark-role
  apiGroup: rbac.authorization.k8s.io
```

将上述 RBAC 资源清单文件保存为 `spark-rbac.yaml`，并执行如下命令创建相应的资源：

```shell
$ kubectl apply -f spark-rbac.yaml
serviceaccount/spark created
role.rbac.authorization.k8s.io/spark-role created
rolebinding.rbac.authorization.k8s.io/spark-rolebinding created
```

然后，我们需要获取 Kubernetes 集群的 API Server 的访问 URL：

```shell
KUBERNETES_API_SERVER_URL=`kubectl cluster-info | grep "Kubernetes control plane" | egrep -o "https://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+"`
```

最后， 调用 `spark-submit` 脚本提交 Spark 作业：

```shell
# Spark 镜像
SPARK_IMAGE=apache/spark:3.5.0

# 提交作业
${SPARK_HOME}/bin/spark-submit \
    --master k8s://${KUBERNETES_API_SERVER_URL} \
    --deploy-mode cluster \
    --name spark-pi \
    --class org.apache.spark.examples.SparkPi \
    --conf spark.executor.instances=2 \
    --conf spark.kubernetes.container.image=${SPARK_IMAGE} \
    --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
    local:///opt/spark/examples/jars/spark-examples_2.12-3.5.0.jar
```

### Spark Operator

Kubernetes 中的 [Operator 模式](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/) 允许用户在不修改 Kubernetes 自身代码的情况下，通过为一个或多个自定义资源（Custom Resource，CR）关联控制器（Controller），从而扩展集群的能力。

使用 Operator 可以实现非常多的功能，例如自动化部署应用和管理应用的生命周期。[Spark Operator](https://github.com/kubeflow/spark-operator) 定义了 `SparkApplication` 和 `ScheduledSparkApplication` 两种 CRD（CustomResourceDefinition）并为它们实现了相应的控制器，用户只需要编写相应的清单文件，就可以像管理 Kubernetes 中内置的资源一样去管理 Spark 作业。

例如，用户在集群中部署好 Spark Operator 之后，可以编写如下作业清单文件：

```yaml
# spark-pi.yaml

apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-pi
  namespace: default
spec:
  type: Scala
  mode: cluster
  image: apache/spark:3.5.0
  mainClass: org.apache.spark.examples.SparkPi
  mainApplicationFile: local:///opt/spark/examples/jars/spark-examples_2.12-3.5.0.jar
  sparkVersion: "3.5.0"
  driver:
    cores: 1
    coreLimit: 1200m
    memory: 512m
    serviceAccount: spark
  executor:
    cores: 1
    instances: 1
    memory: 512m
```

上述清单文件定义了一个 SparkApplication 对象，其中定义了 Spark 作业所需的参数，Driver/Executor Pod 的资源配置等，将其保存为 `spark-pi.yaml`，然后可以执行如下操作：

```shell
# 提交作业
kubectl apply -f spark-pi.yaml

# 查看作业
kubectl get sparkapplication spark-pi

# 删除作业
kubectl delete -f spark-pi.yaml
```

关于使用 Spark Operator 提交作业的更多细节，请参考 [Spark Operator 用户文档](https://github.com/kubeflow/spark-operator/blob/master/docs/user-guide.md)。

## 快速开始

关于如何在 ACK 集群中运行 Spark 工作负载，请参考[快速开始](docs/quick-start.md)。

## 问题与挑战

## 性能优化

为了提高在 Kubernetes 运行工作负载时的性能和易用性，并降低成本，阿里云 EMR 和 ACK 团队做了很多优化工作，主要有以下这些：

- [Spark Operator 优化](docs/performance/spark-operator.md)
- [Spark 优化](docs/performance/emr-spark.md)
- [Shuffle 优化](https://developer.aliyun.com/article/772329)
- [OSS 优化](docs/performance/oss.md)
- [分布式缓存优化](docs/performance/jindofs.md)
- [Serverless Spark](docs/performance/serverless-spark/index.md)

## 最佳实践

- [使用 EMR Spark 运行 Spark工作负载](./docs/bestpractice/emrspark.md)
- [使用 EMR Spark + Remote Shuffle Service 运行 Spark 工作负载](./docs/bestpractice/emrspark-ess.md)
- [使用 EMR Spark + JindoFS 运行 Spark 工作负载](./docs/bestpractice/emrspark-jindofs.md)
- [使用 EMR Spark + JindoFS + Remote Shuffle Service 运行Spark工作负载](./docs/bestpractice/emrspark-ess-jindofs.md)

## 基准测试

### 关于 TPC-DS 基准测试

[TPC-DS](http://www.tpc.org/tpcds/) 由第三方社区创建和维护，是事实上的做性能压测，协助确定解决方案的工业标准。这个测试集包含对大数据集的统计、报表生成、联机查询、数据挖掘等复杂应用，测试用的数据和值是有倾斜的，与真实数据一致。可以说 TPC-DS 是与真实场景非常接近的一个测试集，也是难度较大的一个测试集。

TPC-DS 基准测试有以下几个主要特点：

- 遵循 SQL 2003 的语法标准，SQL 案例比较复杂；
- 分析的数据量大，并且测试案例是在回答真实的商业问题；
- 测试案例中包含各种业务模型(如分析报告型，迭代式的联机分析型，数据挖掘型等)；
- 几乎所有的测试案例都有很高的 IO 负载和 CPU 计算需求。

TPC-DS 基准测试总包含 99 条压测查询，其中有 4 条查询包含 2 个变体（14、23、24、39），另外还有一个 `s_max` 查询进行全量扫描和最大的一些表的聚合，因此一共是 104 条查询语句，这些查询覆盖了 SQL 2003 语法的大部分标准。

由于上述原因，本文将采用 TPC-DS 基准测试来评测 Spark 在 ACK 上的性能。

### Apache Spark v.s. EMR Spark

阿里云 EMR Spark 基于开源的 Apache Spark 做了大量优化，下面将在同一 ACK 集群环境中分别使用 Apache Spark 和 EMR Spark 运行相同的规模的 TPC-DS 基准测试，基准测试的配置和结果请参考 [Apache Spark v.s. EMR Spark](docs/benchmark/apache-spark-vs-emr-spark.md)。

### Spark on ECS v.s. on ACK

Spark 作业可以以非容器化的方式直接运行在 ECS 中，也可以以容器化的方式运行在 ACK 集群中，下面将在相同数量和相同规格的 ECS 集群和 ACK 集群中分别运行相同规模的 TPC-DS 基准测试，以对比容器化和非容器化环境下的性能差异，基准测试的配置和结果请参考 [Spark on ECS v.s. on ACK](docs/benchmark/spark-on-ecs-vs-on-ack/index.md)。
