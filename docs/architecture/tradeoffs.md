# Registry vs Kind Load：权衡分析

## 问题的根源

你的问题 "为什么已经创建了 Registry 还用 kind load？" 指出了一个架构矛盾。

### 环境限制

在当前的环境中（Podman on Windows）：

```
开发环境限制：
- Podman 在 Windows 上的 HTTP registry 支持有限
- HTTPS/TLS 验证问题无法轻易解决
- Docker Desktop 不可用（公司政策要求使用 Podman）
```

### 两个方案的对比

| 方面 | Kind Load | Registry |
|------|-----------|----------|
| 镜像管理 | 临时，集群本地 | 中央存储 |
| 生产就绪 | ❌ 不是 | ✅ 是 |
| 本地开发 | ✅ 简单快速 | ⚠️ Podman 问题 |
| 跨集群使用 | ❌ 无法共享 | ✅ 可以共享 |
| 当前环境可行性 | ✅ 完全可行 | ⚠️ 有限制 |

## 推荐方案：混合架构

既然环境有限制，采用混合方案是最实用的：

```
开发阶段（本地开发）:
├── 代码变更
├── Podman build
├── kind load image-archive
└── kubectl apply

生产就绪：
├── CI/CD pipeline 处理
├── Docker push 或其他工具
├── Registry 存储
└── K8s 从 Registry 拉取
```

### 部署配置

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dotnet-lab-api
  namespace: derek-local
spec:
  replicas: 2
  selector:
    matchLabels:
      app: dotnet-lab-api
  template:
    metadata:
      labels:
        app: dotnet-lab-api
    spec:
      containers:
        - name: dotnet-lab-api
          image: localhost:5000/weather-api:latest
          # 说明：当前使用 kind load 方式，镜像通过 kind 集群加载
          imagePullPolicy: Never  # 不尝试从任何 registry 拉取
          ports:
            - containerPort: 8080
          env:
            - name: ASPNETCORE_ENVIRONMENT
              value: Development
```

## 三层架构规划

### Layer 1: 现在（本地开发）
```bash
# 快速迭代
podman build -t localhost:5000/weather-api:latest .
kind load image-archive weather-api.tar --name k8s-new
kubectl rollout restart deployment/dotnet-lab-api
```

✅ **优势**：快速、可靠、无依赖  
⚠️ **局限**：镜像仅在本地集群

### Layer 2: 未来（多集群或共享环境）
```bash
# 使用 Registry 做中间层
podman save -o weather-api.tar localhost:5000/weather-api:latest
# 通过 CI/CD 或其他机制推送到 Registry
registry-cli push weather-api.tar

# 应用从 Registry 拉取
image: docker-registry.docker-registry.svc.cluster.local:5000/weather-api:latest
imagePullPolicy: Always
```

✅ **优势**：可跨集群、更灵活  
📋 **前提**：环境改进或使用 Docker

### Layer 3: 生产（完整 CI/CD）
```
代码提交
  ↓
GitHub Actions / Jenkins
  ↓
Docker build
  ↓
推送到私有 Registry
  ↓
K8s 从 Registry 拉取并部署
```

✅ **优势**：自动化、可扩展、安全

## 当前推荐方案

**采用混合方案，既发挥 Registry 的架构优势，也适应环境限制：**

### 1. Registry 的用途保留

```bash
# Registry 部署保持原样
kubectl apply -f registry-deployment.yml
```

这样为未来预留了位置，如果：
- 环境升级到 Docker
- 需要多集群同步
- 需要完整 CI/CD

### 2. 本地开发流程

```bash
# 构建镜像
cd src/Lab.Api && podman build -t localhost:5000/weather-api:latest .

# 加载到 kind 集群
cd ../.. && podman save -o weather-api.tar localhost:5000/weather-api:latest
kind load image-archive weather-api.tar --name k8s-new
rm weather-api.tar

# 部署应用
kubectl apply -f deployment.yml

# 更新时只需重新构建和加载
kubectl rollout restart deployment/dotnet-lab-api -n derek-local
```

### 3. 配置文件说明

在 `deployment.yml` 中明确说明架构：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dotnet-lab-api
  namespace: derek-local
  labels:
    version: "1.0"
    environment: "development"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: dotnet-lab-api
  template:
    metadata:
      labels:
        app: dotnet-lab-api
    spec:
      containers:
        - name: dotnet-lab-api
          # 镜像存储位置：localhost:5000（虚拟 registry 标签）
          # 实际加载方式：kind load image-archive（集群本地）
          # 未来迁移：当切换到 Docker 时，改为从 Registry 拉取
          image: localhost:5000/weather-api:latest
          imagePullPolicy: Never  # 本地开发：不拉取，使用已加载镜像
          ports:
            - containerPort: 8080
          env:
            - name: ASPNETCORE_ENVIRONMENT
              value: Development
```

## 路线图

### 现在（✅ 已完成）
- [x] Registry 部署
- [x] 镜像构建
- [x] 通过 kind load 部署
- [x] 应用运行正常

### 短期（可选改进）
- [ ] 如果需要多集群，配置 Registry 持久化存储
- [ ] 文档化 Registry 的未来用途
- [ ] 准备 CI/CD 集成方案

### 中期（环境改进）
- [ ] 升级到 Docker Desktop（如果政策允许）
- [ ] 或在 Linux 开发环境中验证 Podman+Registry
- [ ] 实现完整的 Registry 推送流程

### 长期（生产部署）
- [ ] 建立企业级 Registry
- [ ] 完整的 CI/CD 流程
- [ ] 镜像签名和扫描
- [ ] 多环境镜像管理

## 总结

**目前的最佳实践：**

1. ✅ **保持 Registry 部署** - 为未来预留
2. ✅ **使用 kind load** - 现在最实用的方案
3. ✅ **清晰的架构文档** - 说明意图和限制
4. ✅ **准备迁移路径** - 当环境改进时快速切换

**权衡理由：**
- 利用现有最可靠的方案（kind load）
- 保留未来灵活性（Registry 已部署）
- 避免环境限制导致的复杂配置
- 专注于应用开发而非基础设施问题

---

这是一个务实的方案，既尊重架构原则，也承认环境限制。

