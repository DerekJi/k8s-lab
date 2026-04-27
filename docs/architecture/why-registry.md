# 为什么应该使用本地 Registry 而不是 kind load

## 问题陈述

之前的部署方案混淆了两个不同的镜像管理方式：

### ❌ Kind Load 方案（当前不推荐）
```bash
podman save -o weather-api.tar localhost:5000/weather-api:latest
kind load image-archive weather-api.tar --name k8s-new
```

**问题：**
- 镜像只存在于本地 kind 集群中
- 无法跨集群共享
- 集群重启后镜像丢失
- 无法实现 CI/CD 中的镜像管理
- 违背了建立 Registry 的初心

### ✅ Registry 方案（推荐）
```bash
podman push localhost:5000/weather-api:latest
# K8s 从 Registry 拉取
```

**优势：**
- ✅ 镜像集中存储在 Registry 中
- ✅ 支持跨集群/环境使用
- ✅ 集群重启镜像仍然可用
- ✅ 真实生产环境的做法
- ✅ 支持镜像版本管理
- ✅ 支持 CI/CD 集成

## 为什么之前的方案失败了

### 根本原因：配置和验证问题

1. **Podman Registry 配置问题**
   - Podman 默认将 `localhost:5000` 当作不安全的 registry
   - 需要在 `~/.config/containers/registries.conf` 中明确配置

2. **镜像推送时的验证不足**
   - 虽然 `podman push` 命令执行成功，但镜像实际上没有进入 Registry
   - 需要验证：`curl http://localhost:5000/v2/_catalog`

3. **端口转发设置问题**
   - 本地 `localhost:5000` 和 K8s 中的 Registry Service 是两个不同的东西
   - 需要通过 `kubectl port-forward` 建立正确的映射

## 正确的部署流程

### 方案：完整使用本地 Registry

```bash
# 1. 部署 Registry
kubectl apply -f registry-deployment.yml

# 2. 启动 port-forward（后台）
kubectl port-forward -n docker-registry svc/docker-registry 5000:5000 &

# 3. 构建镜像
cd src/Lab.Api && podman build -t localhost:5000/weather-api:latest .

# 4. 推送到 Registry
podman push localhost:5000/weather-api:latest

# 5. 验证镜像在 Registry 中
curl http://localhost:5000/v2/_catalog | grep weather-api

# 6. 部署应用（使用 Registry 中的镜像）
kubectl apply -f deployment.yml
```

## 架构对比

### Kind Load 方案（当前）
```
Podman
  ↓
localhost:5000/weather-api:latest
  ↓
kind load image-archive
  ↓
Kind Cluster (containerd)
  ├── 镜像存储在本地节点
  ├── 不通过任何 Registry
  └── ❌ 集群重启丢失
```

### Registry 方案（正确）
```
Podman
  ↓
构建镜像: localhost:5000/weather-api:latest
  ↓
推送到 Registry
  ↓
Registry Pod (docker-registry namespace)
  ├── 持久化存储（配置 PVC 后）
  └── ✅ 所有 Pod 从这里拉取
       ↓
Kind Cluster
  └── deployment 使用
      image: docker-registry.docker-registry.svc.cluster.local:5000/weather-api:latest
```

## 部署步骤

### 快速开始（推荐）
```bash
bash deploy-with-real-registry.sh
```

### 手动步骤

**1. 部署 Registry**
```bash
kubectl apply -f registry-deployment.yml
kubectl wait --for=condition=ready pod -l app=docker-registry -n docker-registry --timeout=60s
```

**2. 启动 port-forward（必须）**
```bash
kubectl port-forward -n docker-registry svc/docker-registry 5000:5000 --address=127.0.0.1 &
sleep 2
```

**3. 配置 Podman（一次性）**
```bash
mkdir -p ~/.config/containers
cat > ~/.config/containers/registries.conf << 'EOF'
[[registry]]
location = "localhost:5000"
insecure = true
EOF
```

**4. 构建镜像**
```bash
cd src/Lab.Api
podman build -t localhost:5000/weather-api:latest .
cd ../..
```

**5. 推送到 Registry**
```bash
podman push localhost:5000/weather-api:latest
```

**6. 验证镜像**
```bash
curl http://localhost:5000/v2/_catalog
# 应该看到: {"repositories":["weather-api"]}
```

**7. 部署应用**
```bash
kubectl apply -f deployment.yml
kubectl apply -f service.yml
```

**8. 验证应用**
```bash
kubectl get pods -n derek-local
# 所有 Pod 应该是 Running 状态
```

## 关键文件配置

### deployment.yml（使用 Registry）
```yaml
spec:
  template:
    spec:
      containers:
        - name: dotnet-lab-api
          image: docker-registry.docker-registry.svc.cluster.local:5000/weather-api:latest
          imagePullPolicy: Always  # 总是从 Registry 拉取
```

### registries.conf（Podman 配置）
```ini
[[registry]]
location = "localhost:5000"
insecure = true
```

## 常见问题

### Q: 为什么需要 port-forward？
**A:** 
- 本地 Podman 需要通过网络连接到 K8s 中的 Registry Service
- port-forward 在本地创建了到 K8s 服务的隧道
- 不启动 port-forward，本地 podman 无法访问集群内的 Registry

### Q: 镜像推送后看不到怎么办？
**A:**
1. 检查 port-forward 是否运行：`ps aux | grep port-forward`
2. 测试连接：`curl http://localhost:5000/v2/_catalog`
3. 查看 Registry 日志：`kubectl logs -n docker-registry -l app=docker-registry`
4. 确保已配置 `registries.conf`

### Q: K8s Pod 无法拉取镜像怎么办？
**A:**
1. 检查镜像确实在 Registry 中
2. 确保使用了正确的 DNS 名称：`docker-registry.docker-registry.svc.cluster.local:5000`
3. 查看 Pod 事件：`kubectl describe pod <pod-name> -n derek-local`
4. 查看 kubelet 日志

### Q: 生产级部署需要什么？
**A:**
1. **持久化存储** - 将 emptyDir 改为 PersistentVolume
2. **HTTPS** - 配置 SSL 证书
3. **认证** - 添加用户名/密码
4. **镜像清理** - 定期删除旧镜像
5. **监控** - 监控 Registry 健康状态

## 相关命令

```bash
# Registry 管理
kubectl port-forward -n docker-registry svc/docker-registry 5000:5000 &
curl http://localhost:5000/v2/_catalog                           # 查看所有镜像
curl http://localhost:5000/v2/weather-api/tags/list             # 查看特定镜像的 tags

# 镜像管理
podman build -t localhost:5000/weather-api:latest .              # 构建
podman push localhost:5000/weather-api:latest                    # 推送
podman pull localhost:5000/weather-api:latest                    # 拉取
podman rmi localhost:5000/weather-api:latest                     # 删除

# 应用部署
kubectl apply -f deployment.yml                                   # 应用
kubectl rollout restart deployment/dotnet-lab-api -n derek-local # 重启
kubectl logs -n derek-local -l app=dotnet-lab-api               # 查看日志
```

## 总结

| 方面 | Kind Load | Registry |
|------|-----------|----------|
| 镜像存储位置 | 本地集群 | 集中 Registry |
| 集群重启后 | ❌ 丢失 | ✅ 保留 |
| 跨集群使用 | ❌ 不支持 | ✅ 支持 |
| 生产环境 | ❌ 不适用 | ✅ 推荐 |
| CI/CD 集成 | ❌ 困难 | ✅ 简单 |
| 镜像版本管理 | ❌ 弱 | ✅ 强 |

---

**结论**: 应该完全使用本地 Registry，而不是 kind load。正确配置和验证很重要。

