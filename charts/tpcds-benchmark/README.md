# Spark on ACK TPC-DS 基准测试

## 前置条件

- Git
- Docker
- sbt
- kubectl
- Helm

## 搭建基准测试环境

关于如何搭建基准测试环境，请参考[基准测试环境搭建](../../docs/benchmark/setup-env/index.md)。

## 编译基准测试代码

```shell
# 克隆代码仓库
git clone https://github.com/AliyunContainerService/benchmark-for-spark.git

# 清除编译缓存
sbt clean

# 编译
sbt assembly --mem 2048 -J-XX:ReservedCodeCacheSize=1g
```

## 构建并上传基准测试容器镜像

切换到本基准测试目录下，使用 `docker buildx` 构建容器镜像并上传至指定仓库：

```shell
# 构建容器镜像并推送至镜像仓库
docker buildx build \
    --output=type=registry \
    --push \
    --platform=linux/amd64,linux/arm64 \
    --tag=registry.cn-beijing.aliyuncs.com/poc/spark-tpcds-benchmark:3.3.2 \
    --build-arg=SPARK_IMAGE=apache/spark:v3.3.2 \
    --file=charts/tpcds-benchmark/Dockerfile \
    .
```

注：

- 请在 `--tag` 参数中将镜像仓库替换成您自己的镜像仓库；
- 可以通过 `--build-arg=SPARK_IMAGE=apache/spark:3.3.2` 的方式指定使用的 Spark 基础基础镜像。

## 配置基准测试参数

修改 `values.yaml` 文件，配置基准测试参数：

```yaml
image:
  # -- Image repository
  repository: registry.cn-beijing.aliyuncs.com/poc/spark-tpcds-benchmark
  # -- Image tag
  tag: 3.3.2
  # -- Image pull policy
  pullPolicy: IfNotPresent
  # -- Image pull secrets
  pullSecrets: []
  # - name: pull-secret

aliyun:
  # -- Aliyun accessKeyId
  accessKeyId: ""
  # -- Aliyun accessKeySecret
  accessKeySecret: ""

oss:
  # -- OSS bucket
  bucket: spark-on-ack-benchmark
  # -- OSS endpoint
  endpoint: oss-cn-beijing-internal.aliyuncs.com

benchmark:
  # -- Scale factor
  scaleFactor: 3072
  # -- Number of iterations
  numIterations:  1
  # -- Whether to optimize queries
  optimizeQueries: false
  # -- Filter queries, will run all if empty
  queries: []
  # - q70-v2.4
  # - q82-v2.4
  # - q64-v2.4
```

⚠️ 注意事项：

- 由于配置文件中包含了阿里云的 accessKeyId 和 accessKeySecret 等信息，因此请注意不要将配置文件上传至 GitHub 等公共仓库，从而导致重要信息泄露。

## 运行基准测试

提交基准测试作业：

```shell
helm install tpcds-benchmark . \
    --values values.yaml
```

查看基准测试作业状态：

```shell
kubectl get sparkapplication tpcds-benchmark -o wide
```

删除基准测试作业：

```shell
helm uninstall tpcds-benchmark
```

## 查看基准测试结果

查看 Driver Pod 日志：

```shell
kubectl logs -n spark-operator tpcds-benchmark-driver
```

基准测试结果会上传至 OSS 中，路径格式为 `oss://{{ .Values.oss.bucket }}/spark/tpcds/output/{{ .Values.benchmark.scaleFactor }}gb`，例如配置了 OSS bucket 名称为 `spark-on-ack-benchmark`，scale factor 为 3072，则上传路径为 `oss://spark-on-ack-benchmark/spark/tpcds/output/3072gb`。
