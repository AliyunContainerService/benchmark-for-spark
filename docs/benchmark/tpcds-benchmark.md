# 运行 TPC-DS 基准测试

本文说明如何运行 TPC-DS 基准测试。

## 前提条件

- 已经在本地机器安装 [Git](https://git-scm.com/)、[Docker](https://www.docker.com/)、[kubectl](https://kubernetes.io/docs/reference/kubectl/) 和 [Helm 3](https://helm.sh/) 等工具；
- 已经在本地机器安装 ossutil 工具，详情请参见[安装 ossutil](https://help.aliyun.com/zh/oss/developer-reference/install-ossutil);
- 已经搭建基准测试环境，详情参见[搭建 Spark on ACK 基准测试环境](setup.md)；
- 已经生成 TPC-DS 基准测试数据集并上传至 OSS，详情请参见[生成 TPC-DS 测试数据集成](tpcds-data-generation.md)。

## 提交基准测试作业

1. 执行如下命令，设置基准测试作业参数：

    ```shell
    # 规模因子
    SCALE_FACTOR=3072
    ```

2. 执行如下命令，提交基准测试作业：

    ```shell
    helm install tpcds-benchmark charts/tpcds-benchmark \
        --namespace spark \
        --create-namespace \
        --set image.registry=${IMAGE_REGISTRY} \
        --set image.repository=${IMAGE_REPOSITORY} \
        --set image.tag=${IMAGE_TAG} \
        --set oss.bucket=${OSS_BUCKET} \
        --set oss.endpoint=${OSS_ENDPOINT} \
        --set benchmark.scaleFactor=${SCALE_FACTOR} \
        --set benchmark.numIterations=1
    ```

    可以添加更多形如 `--set key=value` 的参数指定基准测试的配置，支持的配置选项请参见 `charts/tpcds-benchmark/values.yaml`。

3. 执行如下命令，实时查看基准测试作业状态：

    ```shell
    kubectl get -n spark -w sparkapplication tpcds-benchmark-${SCALE_FACTOR}gb
    ```

4. 执行如下命令，实时查看 Driver Pod 日志输出：

    ```shell
    kubectl logs -n spark -f tpcds-benchmark-${SCALE_FACTOR}gb-driver
    ```

## 查看基准测试结果

1. 执行如下命令，查看基准测试输出：

    ```shell
    ossutil ls -s oss://${OSS_BUCKET}/spark/result/tpcds/${SCALE_FACTOR}gb/
    ```

    期望输出如下：

    ```shell
    oss://example-bucket/spark/result/tpcds/SF=3072/
    oss://example-bucket/spark/result/tpcds/SF=3072/timestamp=1716901969870/
    oss://example-bucket/spark/result/tpcds/SF=3072/timestamp=1716901969870/_SUCCESS
    oss://example-bucket/spark/result/tpcds/SF=3072/timestamp=1716901969870/part-00000-80c681de-ae8d-4449-b647-5e3d373edef1-c000.json
    oss://example-bucket/spark/result/tpcds/SF=3072/timestamp=1716901969870/summary.csv/
    oss://example-bucket/spark/result/tpcds/SF=3072/timestamp=1716901969870/summary.csv/_SUCCESS
    oss://example-bucket/spark/result/tpcds/SF=3072/timestamp=1716901969870/summary.csv/part-00000-5a5d1e4a-3fe0-43a1-8248-3259af4f10a7-c000.csv
    Object Number is: 7

    0.172532(s) elapsed
    ```

2. 执行如下命令，从 OSS 下载基准测试结果至本地并保存为 `result.csv`：

    ```shell
    ossutil cp oss://example-bucket/spark/result/tpcds/SF=3072/timestamp=1716901969870/summary.csv/part-00000-5a5d1e4a-3fe0-43a1-8248-3259af4f10a7-c000.csv result.csv
    ```

3. 执行如下命令，查看基准测试结果：

    ```shell
    cat result.csv
    ```

    期望输出如下（已省略部分内容）：

    ```shell
    q1-v2.4,13.169382888,13.169382888,13.169382888,0.0
    q10-v2.4,9.502788331,9.502788331,9.502788331,0.0
    q11-v2.4,57.161809588,57.161809588,57.161809588,0.0
    q12-v2.4,5.344221526999999,5.344221526999999,5.344221526999999,0.0
    q13-v2.4,16.183193874,16.183193874,16.183193874,0.0
    q14a-v2.4,121.433786224,121.433786224,121.433786224,0.0
    q14b-v2.4,112.871190193,112.871190193,112.871190193,0.0
    q15-v2.4,14.63114106,14.63114106,14.63114106,0.0
    q16-v2.4,47.082124609,47.082124609,47.082124609,0.0
    q17-v2.4,14.320191869,14.320191869,14.320191869,0.0
    q18-v2.4,30.619759895999998,30.619759895999998,30.619759895999998,0.0
    q19-v2.4,7.874492828999999,7.874492828999999,7.874492828999999,0.0
    q2-v2.4,34.106892226999996,34.106892226999996,34.106892226999996,0.0
    q20-v2.4,6.1991251609999996,6.1991251609999996,6.1991251609999996,0.0
    ...
    ```

    输出结果分为五列，分别为查询名称、最短运行时间（秒）、最长运行时间（秒）、平均运行时间（秒）和标准差（秒）。本示例由于只跑了一轮查询，因此最短/最长/平均执行时间相同，标准差为 0。

## 环境清理

1. 执行如下命令，删除基准测试作业：

    ```shell
    helm uninstall -n spark tpcds-benchmark
    ```

2. 执行如下命令，删除 PVC 资源：

    ```shell
    kubectl delete -f oss-pvc.yaml
    ```

3. 执行如下命令，删除 PV 资源：

    ```shell
    kubectl delete -f oss-pv.yaml
    ```

4. 执行如下命令，删除 Secret 资源：

    ```shell
    kubectl delete -f oss-secret.yaml
    ```

5. 如果不再需要本示例中创建的存储桶，执行如下命令，删除 OSS 存储桶：

    ```shell
    ossutil rm oss://${OSS_BUCKET} -b
    ```

    注意事项：

    - 删除 OSS 存储桶为不可逆操作，请谨慎操作，以免数据丢失。

6. 销毁本集群测试集群环境：

    ```shell
    terraform -chdir=terraform/alicloud destroy
    ```
