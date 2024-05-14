# 快速开始

本篇文档将介绍如何使用 Spark Operator 提交 Spark 作业至 ACK 集群中。

## 概述

[Spark Operator](https://github.com/kubeflow/spark-operator) 是一个 [Kubernetes operator](https://kubernetes.io/docs/concepts/extend-kubernetes/operator)，用于向 Kubernetes 集群提交 Spark 作业并管理作业的整个生命周期。

## 前提条件

- 已创建 [ACK Pro 集群](https://help.aliyun.com/zh/ack/ack-managed-and-ack-dedicated/user-guide/create-an-ack-managed-cluster-2) 或已创建 [ACK Serverless 集群](https://help.aliyun.com/zh/ack/ack-managed-and-ack-dedicated/user-guide/create-an-ack-managed-cluster-2)。

## 步骤一：部署 Spark Operator

目前 ACK 应用市场中提供了两个版本的 Spark Operator：

- [ack-spark-operator](https://cs.console.aliyun.com/#/next/app-catalog/ack/incubator/ack-spark-operator) 使用的 Spark 版本为 2.x，适用于运行 2.x 版本的 Spark 作业。
- [ack-spark-operator3.0](https://cs.console.aliyun.com/#/next/app-catalog/ack/incubator/ack-spark-operator3.0) 使用的 Spark 版本为 3.x，适用于运行 3.x 版本的 Spark 作业。

下面以 `ack-spark-operator3.0` 为例，介绍如何通过容器服务控制台或 Helm 进行部署。

### 通过容器服务控制台部署

1. 登录[容器服务管理控制台](https://cs.console.aliyun.com)，在左侧导航栏选择**市场** > **应用市场**。
2. 在**应用市场**页面，搜索 `ack-spark-operator3.0`，然后单击该应用。
3. 在**应用详情**页面，单击右上角的**一键部署**，然后按照页面提示进行部署。
4. 在**基本信息**页面，填写目标集群、命名空间和发布名称后，单击**下一步**。
5. 在**参数配置**页面，选择 Chart 版本，将参数配置完成后，单击**确定**。

完整的参数配置说明可以在**应用详情页面**查看。

### 通过 Helm 部署

添加阿里云容器服务 Helm 仓库并更新仓库索引：

```shell
helm repo add aliyunhub https://aliacs-k8s-ap-southeast-1.oss-ap-southeast-1.aliyuncs.com/app/charts-incubator

helm repo update
```

执行如下命令以在 `spark-operator` 命名空间中部署 `ack-spark-operator3.0`，如果命名空间 `spark-operator` 不存在，则创建该命令空间：

```shell
helm install ack-spark-operator3.0 aliyunhub/ack-spark-operator3.0 \
    --namespace spark-operator \
    --create-namespace \
    --set image.repository=registry-cn-beijing.ack.aliyuncs.com/acs/spark-operator
```

注：

- 如需修改配置项，可以添加多个格式形如 `--set key1=value1,key2=value2` 的参数，例如添加 `--set webhook.enable=true` 参数以启用 webhook 功能：

  ```shell
  helm install ack-spark-operator3.0 aliyunhub/ack-spark-operator3.0 \
      --namespace spark-operator \
      --create-namespace \
      --set image.repository=registry-cn-beijing.ack.aliyuncs.com/acs/spark-operator \
      --set webhook.enable=true
  ```

- 可以通过内网 VPC 加速 `spark-operator` 镜像拉取，例如您的 ACK 集群位于北京地域，则可以使用镜像 `registry-cn-beijing-vpc.ack.aliyuncs.com/acs/spark-operator`，其他地域请将 `cn-beijing` 替换成相应的地域代码即可。

## 步骤二：提交示例作业

创建如下示例清单文件并保存为 `spark-pi.yaml`：

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-pi
  namespace: spark-operator
spec:
  type: Scala
  mode: cluster
  image: apache/spark:3.5.0
  imagePullPolicy: Always
  mainClass: org.apache.spark.examples.SparkPi
  mainApplicationFile: local:///opt/spark/examples/jars/spark-examples_2.12-3.5.0.jar
  arguments:
  - "1000"
  sparkVersion: "3.5.0"
  restartPolicy:
    type: Never
  driver:
    cores: 1
    coreLimit: "1200m"
    memory: "512m"
    labels:
      version: "3.5.0"
    serviceAccount: ack-spark-operator3.0-spark
  executor:
    instances: 1
    cores: 1
    coreLimit: "1200m"
    memory: "512m"
    labels:
      version: "3.5.0"
```

执行如下命令以提交 Spark 作业：

```shell
$ kubectl create -f spark-pi.yaml
sparkapplication.sparkoperator.k8s.io/spark-pi created
```

## 步骤三：查看作业运行状态

执行如下命令以查看 Spark 作业运行状态：

```shell
kubectl get -n spark-operator sparkapplication spark-pi
```

查看 Spark 作业对应的 Pod 状态：

```shell
# 查看作业 Pod 状态
kubectl get -n spark-operator pod
```

查看 Spark driver pod 的日志：

```shell
kubectl logs -n spark-operator spark-pi-driver
```

## 步骤三：访问 Spark Web UI

如果在部署 Spark Operator 时将 `uiService.enable` 参数设置为 `true`，则在提交 Spark 作业之后，会为其创建相应的 Service 资源用于暴露其 Web UI，执行如下命令可以将该 Service 的 `4040` 端口转发到本地：

```shell
kubectl port-forward -n spark-operator services/spark-pi-ui-svc 4040
```

如果在部署是没有将 `uiService.enable` 参数设置为 `true`，则可以执行如下命令以直接将 driver pod 的 `4040` 端口转发到本地：

```shell
kubectl port-forward -n spark-operator pods/spark-pi-driver 4040
```

端口转发成功后访问 [http://localhost:4040](http://localhost:4040) 即可查看 Spark Web UI。

注：

- Spark Web UI 只能在 Spark driver pod 处于运行状态时才可以访问，因此当作业运行结束之后，该 Web UI 将不再可用。
