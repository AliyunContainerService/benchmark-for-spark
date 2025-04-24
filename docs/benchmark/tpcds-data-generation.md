# TPC-DS 测试数据集生成

本文说明如何生成 TPC-DS 基准测试所需要用到的数据集。

## 前提条件

- 已经在本地机器安装 [Git](https://git-scm.com/)、[Docker](https://www.docker.com/)、[kubectl](https://kubernetes.io/docs/reference/kubectl/) 和 [Helm 3](https://helm.sh/) 等工具。
- 已经在本地机器安装 ossutil 工具，详情请参见[安装 ossutil](https://help.aliyun.com/zh/oss/developer-reference/install-ossutil);
- 已经搭建基准测试环境，详情参见[搭建 Spark on ACK 基准测试环境](setup.md)；

## 提交数据集生成作业

1. 执行如下命令，设置数据生成作业参数：

    ```shell
    # 规模因子
    SCALE_FACTOR=3072

    # 分区数量
    NUM_PARTITIONS=640
    ```

2. 执行如下命令，提交数据生成作业：

    ```shell
    helm install tpcds-data-generation charts/tpcds-data-generation \
        --namespace spark \
        --create-namespace \
        --set image.registry=${IMAGE_REGISTRY} \
        --set image.repository=${IMAGE_REPOSITORY} \
        --set image.tag=${IMAGE_TAG} \
        --set oss.bucket=${OSS_BUCKET} \
        --set oss.endpoint=${OSS_ENDPOINT} \
        --set benchmark.scaleFactor=${SCALE_FACTOR} \
        --set benchmark.numPartitions=${NUM_PARTITIONS}
    ```

3. 执行如下命令，实时查看 Spark 作业状态：

    ```shell
    kubectl get -n spark -w sparkapplication tpcds-data-generation-${SCALE_FACTOR}gb
    ```

4. 执行如下命令，实时查看 Driver 日志输出：

    ```shell
    kubectl logs -n spark -f tpcds-data-generation-${SCALE_FACTOR}gb-driver
    ```

## 查看数据集

当作业执行完成之后，执行如下命令，查看生成的数据集目录结构：

```shell
ossutil ls -d oss://${OSS_BUCKET}/spark/data/tpcds/${SCALE_FACTOR}gb/
```

预期输出：

```text
oss://example-bucket/spark/data/tpcds/SF=3072/
oss://example-bucket/spark/data/tpcds/SF=3072/call_center/
oss://example-bucket/spark/data/tpcds/SF=3072/catalog_page/
oss://example-bucket/spark/data/tpcds/SF=3072/catalog_returns/
oss://example-bucket/spark/data/tpcds/SF=3072/catalog_sales/
oss://example-bucket/spark/data/tpcds/SF=3072/customer/
oss://example-bucket/spark/data/tpcds/SF=3072/customer_address/
oss://example-bucket/spark/data/tpcds/SF=3072/customer_demographics/
oss://example-bucket/spark/data/tpcds/SF=3072/date_dim/
oss://example-bucket/spark/data/tpcds/SF=3072/household_demographics/
oss://example-bucket/spark/data/tpcds/SF=3072/income_band/
oss://example-bucket/spark/data/tpcds/SF=3072/inventory/
oss://example-bucket/spark/data/tpcds/SF=3072/item/
oss://example-bucket/spark/data/tpcds/SF=3072/promotion/
oss://example-bucket/spark/data/tpcds/SF=3072/reason/
oss://example-bucket/spark/data/tpcds/SF=3072/ship_mode/
oss://example-bucket/spark/data/tpcds/SF=3072/store/
oss://example-bucket/spark/data/tpcds/SF=3072/store_returns/
oss://example-bucket/spark/data/tpcds/SF=3072/store_sales/
oss://example-bucket/spark/data/tpcds/SF=3072/time_dim/
oss://example-bucket/spark/data/tpcds/SF=3072/warehouse/
oss://example-bucket/spark/data/tpcds/SF=3072/web_page/
oss://example-bucket/spark/data/tpcds/SF=3072/web_returns/
oss://example-bucket/spark/data/tpcds/SF=3072/web_sales/
oss://example-bucket/spark/data/tpcds/SF=3072/web_site/
Object and Directory Number is: 25

0.446278(s) elapsed
```
