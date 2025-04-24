# 搭建 Spark on ACK 基准测试环境

本文介绍如何搭建 Spark on ACK 基准测试环境。

## 安装 Terraform

[Terraform](https://www.terraform.io/) 是一个开源的基础设施即代码（Infrastructure as Code，IaC）工具，由 HashiCorp 公司开发。它允许用户以声明式的方式定义和管理云基础架构和网络资源，如计算实例、存储、网络配置、负载均衡器、数据库等，甚至是 Kubernetes 集群和服务网格等复杂应用基础设施。使用 Terraform 能够以 IaC 的方式管理基准测试所需的集群环境，从而方便用户复现。因此，本文将使用 Terraform 来管理集群环境。

首先，需要安装 `terraform` 命令行工具，在 macOS 操作系统中，可以执行如下命令进行安装：

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

更多其他操作系统的安装方式，请参考 [Install | Terraform | HashiCorp Developer](https://developer.hashicorp.com/terraform/install)。

Terraform CLI 自 `v0.13.2` 开始支持网络镜像特性，为了解决下载 `alicloud` Provider 时由于网络超时等原因造成下载失败的问题，阿里云提供了 Terraform 镜像源服务，您可以配置 Terraform 使用阿里云镜像源以加速访问，执行如下脚本将所需配置写入 `~/.terraformrc` 文件：

```bash
cat <<EOF > ~/.terraformrc
plugin_cache_dir = "$HOME/.terraform.d/plugin-cache"

provider_installation {
  network_mirror {
    url = "https://mirrors.aliyun.com/terraform/"
    // Setting alicloud from Alibaba Cloud Mirror Service
    include = ["registry.terraform.io/aliyun/alicloud",
               "registry.terraform.io/hashicorp/alicloud",
              ]
  }
  direct {
    // setting other providers from Terraform Registry
    exclude = ["registry.terraform.io/aliyun/alicloud",
               "registry.terraform.io/hashicorp/alicloud",
              ]
  }
}

EOF
```

## 下载代码

执行如下命令克隆本代码仓库并切换到项目根目录：

```bash
git clone https://github.com/AliyunContainerService/benchmark-for-spark.git

cd benchmark-for-spark
```

## 配置 Terraform

terraform 配置文件目录结构如下：

```bash
$ tree -L 2 terraform/alicloud
terraform/alicloud
├── datasources.tf       # 数据源
├── main.tf              # 配置文件
├── modules              # 子模块定义
│   ├── celeborn
│   ├── cs
│   ├── ecs
│   ├── fluid
│   ├── oss
│   ├── resource-manager
│   ├── spark
│   └── vpc
├── outputs.tf           # 输出参数
├── provider.tf          # 配置阿里云
├── root.tf              # root 配置文件
├── terraform.tfvars     # 输入参数
└── variables.tf         # 输入变量定义
```

本文采用模块化的方式来管理阿里云基础设施资源，其中 `modules` 目录下存放了各个模块的定义文件，包括：

- **resource-manager 模块**：用于创建资源组
- **vpc 模块**：用于创建 VPC 资源
- **ecs 模块**：用于创建安全组资源
- **cs 模块**：用于创建 ACK 集群，不包含节点池
- **oss 模块**（可选）：用于创建 OSS 存储桶
- **spark 模块**（可选）：用于创建 `spark-master` 和 `spark-worker` 两个节点池
- **fluid 模块**（可选）：用于创建 `fluid` 节点池
- **celeborn 模块**（可选）：用于创建 `celeborn` 节点池
- **eci 模块**（可选）：用于向 ACK 集群安装 `ack-virtual-node` 插件

### 配置阿里云访问凭据

通过设置环境变量的方式来配置阿里云访问凭据：

```bash
export ALICLOUD_ACCESS_KEY=<ACCESS_KEY_ID>
export ALICLOUD_SECRET_KEY=<ACCESS_KEY_SECRET>
```

其中 `<ACCESS_KEY_ID>` 和 `<ACCESS_KEY_SECRET>` 需要替换成你的阿里云 AccessKey ID 和 AccessKey Secret。

或者你也可以通过[配置阿里云 CLI](https://help.aliyun.com/cli/overview) 的方式配置访问凭据：

- 在 Linux 和 macOS 系统中，访问凭据默认位于 `${HOME}/.aliyun/config.json`
- 在 Windows 系统中，访问凭据默认位于 `%USERPROFILE%\.aliyun\config.json`。默认使用 `config.json` 中名为 `default` 的 profile，如果你需要指定其他 profile，可以在 `terraform.tfvars` 文件中修改 `profile` 配置参数。

### 选择要创建的模块

在 `terraform/alicloud/root.tf` 配置文件中可以配置需要创建的模块，对于可选模块，如果不需要创建，用 `#` 将其注释掉即可：

```terraform
# Create resource group
module "resource_manager" {
  source = "./modules/resource-manager"
  suffix = random_string.suffix.id
}

# Create VPC and vswitch
module "vpc" {
  source            = "./modules/vpc"
  suffix            = random_string.suffix.id
  zone_id           = var.zone_id
  resource_group_id = module.resource_manager.resource_group_id
}

# Create security group
module "ecs" {
  source            = "./modules/ecs"
  suffix            = random_string.suffix.id
  vpc_id            = module.vpc.vpc_id
  resource_group_id = module.resource_manager.resource_group_id
}

# # module "oss" {
#   source = "./modules/oss"
#   suffix = random_string.suffix.id
# }

# Create ACK
module "cs" {
  source             = "./modules/cs"
  suffix             = random_string.suffix.id
  worker_vswitch_ids = [module.vpc.vswitch_id]
  pod_vswitch_ids    = [module.vpc.vswitch_id]
  resource_group_id  = module.resource_manager.resource_group_id
  security_group_id  = module.ecs.security_group_id
}

# Create node pool for spark
module "spark" {
  source                = "./modules/spark"
  suffix                = random_string.suffix.id
  cluster_id            = module.cs.cluster_id
  vswitch_ids           = [module.vpc.vswitch_id]
  master_instance_count = var.spark_master_instance_count
  master_instance_type  = var.spark_master_instance_type
  worker_instance_count = var.spark_worker_instance_count
  worker_instance_type  = var.spark_worker_instance_type
  resource_group_id     = module.resource_manager.resource_group_id
  security_group_id     = module.ecs.security_group_id
}

# # Create node pool for fluid
# module "fluid" {
#   source            = "./modules/fluid"
#   suffix            = random_string.suffix.id
#   cluster_id        = module.cs.cluster_id
#   vswitch_ids       = [module.vpc.vswitch_id]
#   instance_count    = var.fluid_instance_count
#   instance_type     = var.fluid_instance_type
#   resource_group_id = module.resource_manager.resource_group_id
#   security_group_id = module.ecs.security_group_id
# }

# # Create node pool for celeborn
# module "celeborn" {
#   source            = "./modules/celeborn"
#   suffix            = random_string.suffix.id
#   cluster_id        = module.cs.cluster_id
#   vswitch_ids       = [module.vpc.vswitch_id]
#   instance_count    = var.celeborn_instance_count
#   instance_type     = var.celeborn_instance_type
#   resource_group_id = module.resource_manager.resource_group_id
#   security_group_id = module.ecs.security_group_id
# }

# # Install ack-virtual-node addon
# module "eci" {
#   source     = "./modules/eci"
#   cluster_id = module.cs.cluster_id
# }
```

### 修改输入参数

你可以通过修改配置文件 `terraform.tfvars` 来配置集群的规模和实例规格或者在运行时通过 `--var` 参数动态修改输入参数：

```terraform
# Alicloud
zone_id = "cn-beijing-i"

# Spark
spark_master_instance_count = 1
spark_master_instance_type  = "ecs.g7.4xlarge"
spark_worker_instance_count = 6
spark_worker_instance_type  = "ecs.g7.8xlarge"

# Fluid
fluid_instance_count = 3
fluid_instance_type  = "ecs.i3.2xlarge"

# Celeborn
celeborn_instance_count = 3
celeborn_instance_type  = "ecs.i3.2xlarge"
```

注：

- 对于可选模块，如果没有启用，相应的配置参数忽略掉即可。

## 创建基准测试集群环境

本文创建的基准测试集群环境涉及到的阿里云资源包括：

- 资源组
- ECS 安全组
- VPC 网络和虚拟交换机
- ACK 集群，该集群包含多个节点池，包括 `spark-master`、`spark-worker`、`celeborn-master`、`celeborn-worker` 和 `fluid` 等节点池。

1. 执行如下命令，初始化 Terraform：

    ```bash
    terraform -chdir=terraform/alicloud init
    ```

2. 执行如下命令，创建测试环境：

    ```bash
    terraform -chdir=terraform/alicloud apply \
        --var region=cn-beijing \
        --var zone_id=cn-beijing-i \
        --var spark_master_instance_count=1 \
        --var spark_master_instance_type=ecs.g7.4xlarge \
        --var spark_worker_instance_count=6 \
        --var spark_worker_instance_type=ecs.g7.8xlarge
    ```

    命令执行过程中需要手动输入 `yes` 进行确认，该命令执行完成后会在当前目录下创建 `terraform.tfstate` 和 `terraform.tfstate.backup` 等文件用于存储状态信息。

等待集群创建完成后，登录[阿里云容器服务控制台](https://csnew.console.aliyun.com)，查看集群状态，该集群包括如下节点池：

- `spark-master` 节点池：包含 `1` 个规格为 `ecs.g7.4xlarge` 的节点。
- `spark-worker` 节点池：包含 `6` 个规格为 `ecs.g7.8xlarge` 的节点。
- `celeborn-master` 节点池：包含 `0` 个规格为 `ecs.g7.2xlarge` 的节点。
- `celeborn-worker` 节点池：包含 `0` 个规格为 `ecs.i4.8xlarge` 的节点。
- `fluid` 节点池：包含 `0` 个规格为 `ecs.i4.8xlarge` 的节点。

⚠️ 注意事项：

- 新创建的 ACK 集群的 kubeconfig 文件会直接保存到 `~/.kube/config`，请注意对原有的 kubeconfig 文件进行备份。

## 准备依赖 Jar 包并上传至 OSS

1. 执行如下命令，设置 OSS 相关配置：

    ```bash
    # OSS 存储桶所在地域
    REGION=cn-beijing

    # OSS 存储桶名称
    OSS_BUCKET=example-bucket

    # OSS 访问端点（默认使用内网访问端点）
    OSS_ENDPOINT=oss-${REGION}-internal.aliyuncs.com
    ```

2. 如果指定的 OSS 存储桶不存在，执行如下命令，创建该存储桶：

    ```bash
    ossutil mb oss://${OSS_BUCKET} --region ${REGION}
    ```

3. Spark 作业访问 OSS 数据有多种方式，根据选择的 SDK 下载相应的 Jar 包，并上传至 OSS。

    a. 如果选择 [Hadoop-Aliyun SDK](https://apache.github.io/hadoop/hadoop-aliyun/tools/hadoop-aliyun/index.html)，执行如下命令：

    ```bash
    # Download Hadoop-Aliyun SDK jars
    wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aliyun/3.3.4/hadoop-aliyun-3.3.4.jar
    wget https://repo1.maven.org/maven2/com/aliyun/oss/aliyun-sdk-oss/3.17.4/aliyun-sdk-oss-3.17.4.jar
    wget https://repo1.maven.org/maven2/org/jdom/jdom2/2.0.6.1/jdom2-2.0.6.1.jar

    # Upload Hadoop-Aliyun SDK jars to OSS
    ossutil cp hadoop-aliyun-3.3.4.jar oss://${OSS_BUCKET}/spark/jars/
    ossutil cp aliyun-sdk-oss-3.17.4.jar oss://${OSS_BUCKET}/spark/jars/
    ossutil cp jdom2-2.0.6.1.jar oss://${OSS_BUCKET}/spark/jars/
    ```

    b. 如果选择 [Hadoop-AWS SDK](https://apache.github.io/hadoop/hadoop-aws/tools/hadoop-aws/index.html)，执行如下命令：

    ```bash
    # Download Hadoop-AWS SDK jars
    wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar
    wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.367/aws-java-sdk-bundle-1.12.367.jar

    # Upload Hadoop-AWS SDK jars to OSS
    ossutil cp hadoop-aws-3.3.4.jar oss://${OSS_BUCKET}/spark/jars/
    ossutil cp aws-java-sdk-bundle-1.12.367.jar oss://${OSS_BUCKET}/spark/jars/
    ```

    c. 如果选择 [JindoSDK](https://github.com/aliyun/alibabacloud-jindodata)，执行如下命令：

    ```bash
    # Download JindoSDK
    wget https://jindodata-binary.oss-cn-shanghai.aliyuncs.com/mvn-repo/com/aliyun/jindodata/jindo-core/6.4.0/jindo-core-6.4.0.jar
    wget https://jindodata-binary.oss-cn-shanghai.aliyuncs.com/mvn-repo/com/aliyun/jindodata/jindo-core-linux-el7-aarch64/6.4.0/jindo-core-linux-el7-aarch64-6.4.0.jar
    wget https://jindodata-binary.oss-cn-shanghai.aliyuncs.com/mvn-repo/com/aliyun/jindodata/jindo-core-linux-el6-x86_64/6.4.0/jindo-core-linux-el6-x86_64-6.4.0.jar
    wget https://jindodata-binary.oss-cn-shanghai.aliyuncs.com/mvn-repo/com/aliyun/jindodata/jindo-sdk/6.4.0/jindo-sdk-6.4.0.jar

    # Upload JindoSDK jars to OSS
    ossutil cp jindo-core-6.4.0.jar oss://${OSS_BUCKET}/spark/jars/
    ossutil cp jindo-core-linux-el7-aarch64-6.4.0.jar oss://${OSS_BUCKET}/spark/jars/
    ossutil cp jindo-core-linux-el6-x86_64-6.4.0.jar oss://${OSS_BUCKET}/spark/jars/
    ossutil cp jindo-sdk-6.4.0.jar oss://${OSS_BUCKET}/spark/jars/
    ```

## 准备基准测试容器镜像

执行如下命令，构建基准测试容器镜像并推送至镜像仓库：

```bash
IMAGE_REGISTRY=registry-cn-beijing.ack.aliyuncs.com      # 请替换成你的镜像仓库地址
IMAGE_REPOSITORY=ack-demo/spark-tpcds-benchmark          # 请替换成你的镜像仓库名称
IMAGE_TAG=3.3.2-0.1                                      # 镜像标签
IMAGE=${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG} # 完整的镜像地址
PLATFORMS=linux/amd64,linux/arm64                        # 镜像架构

# 构建镜像并推送至你的镜像仓库中
docker buildx build \
    --output=type=registry \
    --push \
    --platform=${PLATFORMS} \
    --tag=${IMAGE} \
    --build-arg=SPARK_IMAGE=apache/spark:v3.3.2 \
    .
```

- 该容器镜像中包含了基准测试相关的 Jar 包，后续步骤中会将其他依赖 Jar 包上传至 OSS，并将 OSS 作为只读存储卷挂载至 Spark Pod 中。
- 你可以通过修改变量 `IMAGE_REPOSITORY` 和 `IMAGE_TAG` 的值以使用自己的镜像仓库。

## 创建 PV 和 PVC

1. 为 Spark 作业创建名为 `spark` 的命名空间：

    ```bash
    kubectl create namespace spark
    ```

2. 创建如下 Secret 清单文件并保存为 `oss-secret.yaml`：

    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: oss-secret
      namespace: spark
    stringData:
      akId: <OSS_ACCESS_KEY_ID>
      akSecret: <OSS_ACCESS_KEY_SECRET>
    ```

    注意事项：

    - `<OSS_ACCESS_KEY_ID>` 和 `<OSS_ACCESS_KEY_SECRET>` 需分别替换成阿里云 AccessKey ID 和 AccessKey Secret。

3. 执行如下命令创建 Secret 资源：

    ```bash
    kubectl create -f oss-secret.yaml
    ```

4. 创建如下 PV 清单文件并保存为 `oss-pv.yaml`：

    ```yaml
    apiVersion: v1
    kind: PersistentVolume
    metadata:
      name: oss-pv
      labels:
        alicloud-pvname: oss-pv
    spec:
      capacity:
        storage: 1Ti
      accessModes:
      - ReadOnlyMany
      persistentVolumeReclaimPolicy: Retain
      csi:
        driver: ossplugin.csi.alibabacloud.com
        volumeHandle: oss-pv
        nodePublishSecretRef:
          name: oss-secret
          namespace: spark
        volumeAttributes:
          bucket: <OSS_BUCKET>
          url: <OSS_ENDPOINT>
          otherOpts: "-o umask=022 -o max_stat_cache_size=0 -o allow_other"
          path: /
    ```

    注意事项：

    - `<OSS_BUCKET>` 需要替换成 OSS 存储桶名称。
    - `<OSS_ENDPOINT>` 需要替换成 OSS 访问端点，例如北京地域 OSS 内网访问端点为 `oss-cn-beijing-internal.aliyuncs.com`。

5. 执行如下命令创建 PV 资源：

    ```bash
    kubectl create -f oss-pv.yaml
    ```

6. 创建如下 PVC 清单文件并保存为 `oss-pvc.yaml`：

    ```yaml
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: oss-pvc
      namespace: spark
    spec:
      accessModes:
      - ReadOnlyMany
      resources:
        requests:
          storage: 1Ti
      selector:
        matchLabels:
          alicloud-pvname: oss-pv
    ```

7. 执行如下命令创建 PVC 资源：

    ```bash
    kubectl create -f oss-pvc.yaml
    ```

8. 执行如下命令查看 PVC 状态：

    ```bash
    kubectl get -n spark pvc oss-pvc
    ```

    预期输出：

    ```text
    NAME      STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
    oss-pvc   Bound    oss-pv   200Gi      ROX                           38s
    ```

    输出表明 PVC 已经创建并绑定成功。

## 部署 ack-spark-operator

1. 如果尙未添加阿里云容器服务 Helm chart 仓库，执行如下命令进行添加：

    ```bash
    helm repo add --force-update aliyunhub https://aliacs-app-catalog.oss-cn-hangzhou.aliyuncs.com/charts-incubator
    ```

2. 执行如下命令，部署阿里云 `ack-spark-operator` 组件：

    ```bash
    helm install spark-operator aliyunhub/ack-spark-operator \
        --version 2.1.2 \
        --namespace spark \
        --create-namespace \
        --set image.registry=registry-cn-beijing-vpc.ack.aliyuncs.com \
        --set 'spark.jobNamespaces={spark}'
    ```

    注：

    - 需要根据集群所在地域选择对应的镜像仓库地址，例如杭州地域内网镜像地址为 `registry-cn-hangzhou-vpc.ack.aliyuncs.com`。

## 安装 ack-spark-history-server（可选）

1. 如果 OSS 存储桶尚未创建日志存储目录 `spark/event-logs`，执行如下命令进行创建：

    ```bash
    ossutil mb oss://${OSS_BUCKET}/spark/event-logs
    ```

2. 如果尙未添加阿里云容器服务 Helm chart 仓库，执行如下命令进行添加：

    ```bash
    helm repo add --force-update aliyunhub https://aliacs-app-catalog.oss-cn-hangzhou.aliyuncs.com/charts-incubator
    ```

3. 执行如下命令，部署阿里云 `ack-spark-operator` 组件：

    ```bash
    helm install spark-history-server aliyunhub/ack-spark-history-server \
        --version 1.4.0 \
        --namespace spark \
        --create-namespace \
        --set image.registry=registry-cn-beijing-vpc.ack.aliyuncs.com \
        --set 'sparkConf.spark\.history\.fs\.logDirectory=file:///mnt/oss/spark/event-logs' \
        --set 'volumes[0].name=oss' \
        --set 'volumes[0].persistentVolumeClaim.claimName=oss-pvc' \
        --set 'env[0].name=SPARK_DAEMON_MEMORY' \
        --set 'env[0].value=7g' \
        --set 'volumeMounts[0].name=oss' \
        --set 'volumeMounts[0].subPath=spark/event-logs' \
        --set 'volumeMounts[0].mountPath=/mnt/oss/spark/event-logs' \
        --set resources.requests.cpu=2 \
        --set resources.requests.memory=8Gi \
        --set resources.limits.cpu=2 \
        --set resources.limits.memory=8Gi \
        --set 'nodeSelector.spark\.tpcds\.benchmark/role=spark-master'
    ```

    注：

    - 需要根据集群所在地域选择对应的镜像仓库地址，例如杭州地域内网镜像地址为 `registry-cn-hangzhou-vpc.ack.aliyuncs.com`；
    - 部署 ack-spark-history-server 请参考[使用 Spark History Server 查看 Spark 作业信息](https://help.aliyun.com/ack/ack-managed-and-ack-dedicated/use-cases/use-spark-history-server-to-view-spark-job-information)。

## 释放资源

在基准测试完成之后可以执行如下命令释放资源：

```bash
terraform -chdir=terraform/alicloud destroy
```
