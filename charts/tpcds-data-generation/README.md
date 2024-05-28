# TPC-DS 数据集生成

## 前置条件

- Git
- Docker
- sbt
- kubectl
- Helm

## 构建并上传容器镜像

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

## 搭建基准测试环境

关于如何搭建基准测试环境，请参考[基准测试环境搭建](../../docs/benchmark/setup-env/index.md)。

## 配置测试数据集参数

修改 `values.yaml` 文件，配置测试数据集生成参数：

⚠️ 注意事项：

- 由于配置文件中包含了阿里云的 accessKeyId 和 accessKeySecret 等信息，因此请注意不要将配置文件上传至 GitHub 等公共仓库，从而导致重要信息泄露。

## 提交数据集生成作业

提交数据生成作业：

```shell
helm install tpcds-data-generation . \
    --values values.yaml
```

查看数据生成作业状态：

```shell
kubectl get sparkapplication tpcds-data-generation -o wide
```

删除数据生成作业：

```shell
helm uninstall tpcds-data-generation
```

## 查看生成的数据集

生成的基准测试数据集会上传至 OSS 中，路径格式为 `oss://{{ .Values.oss.bucket }}/spark/tpcds/output/{{ .Values.benchmark.scaleFactor }}gb`，例如配置了 OSS bucket 名称为 `spark-on-ack-benchmark`，scale factor 为 3072，则上传路径为 `oss://spark-on-ack-benchmark/spark/tpcds/output/3072gb`。
