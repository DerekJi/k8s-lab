# 本地 Registry 部署指南

## 概述

本地 Registry 是一个 Docker 镜像仓库，运行在 Kubernetes 集群内部。通过本地 Registry，可以：
- ✅ 快速存储和管理镜像
- ✅ 避免依赖公网（离线开发）
- ✅ 加快镜像拉取速度
- ✅ 存储私有镜像

## 快速开始

### 方式 1：自动部署（推荐）

**Linux/Mac:**
```bash
chmod +x deploy-with-registry.sh
./deploy-with-registry.sh
```

**Windows:**
```bash
deploy-with-registry.bat
```

此脚本会自动执行：
1. 部署本地 Registry 到 Kubernetes
2. 构建 WeatherApi 镜像
3. 推送镜像到本地 Registry
4. 部署应用

### 方式 2：手动步骤

**Step 1: 部署 Registry**
```bash
kubectl apply -f registry-deployment.yml
```

**Step 2: 验证 Registry 就绪**
```bash
kubectl get pods -n docker-registry
kubectl get svc -n docker-registry
```

**Step 3: 构建镜像**
```bash
cd src/Lab.Api
docker build -t localhost:5000/weather-api:latest .
```

**Step 4: 推送到 Registry**
```bash
docker push localhost:5000/weather-api:latest
```

**Step 5: 部署应用**
```bash
cd ../..
kubectl apply -f deployment.yml
kubectl apply -f service.yml
kubectl apply -f ingress.yml
```

## Registry 访问地址

| 环境 | 地址 |
|------|------|
| 本地 Docker | `localhost:5000` |
| K8s 集群内部 | `docker-registry.docker-registry.svc.cluster.local:5000` |

## Kubernetes 中如何访问

在 K8s 部署配置中使用以下格式访问镜像：

```yaml
image: localhost:5000/weather-api:latest
imagePullPolicy: Always  # 总是拉取最新版本
```

或使用 DNS 全名：
```yaml
image: docker-registry.docker-registry.svc.cluster.local:5000/weather-api:latest
```

## 常用操作

### 查看 Registry 中的镜像
```bash
# 进入 Registry Pod
kubectl exec -it -n docker-registry <pod-name> sh

# 查看镜像列表
curl http://localhost:5000/v2/_catalog
```

### 删除镜像
```bash
# 通过 API 删除
curl -X DELETE http://localhost:5000/v2/weather-api/manifests/<sha256:...>
```

### 重新推送镜像
```bash
cd src/Lab.Api
docker build -t localhost:5000/weather-api:v2 .
docker push localhost:5000/weather-api:v2
```

### 查看 Registry Pod 日志
```bash
kubectl logs -n docker-registry -l app=docker-registry -f
```

## 清理

### 删除 Registry（保留镜像）
```bash
kubectl delete namespace docker-registry
```

### 删除所有相关资源
```bash
kubectl delete namespace docker-registry
kubectl delete namespace derek-local
```

## 常见问题

### Q: 镜像推送失败，提示 "refused to connect"？
**A:** 确保 Registry Service 已正确暴露，执行：
```bash
kubectl get svc -n docker-registry
```
如果 EXTERNAL-IP 是 pending，使用本地访问方式：
```bash
docker tag localhost:5000/weather-api:latest registry:5000/weather-api:latest
docker push registry:5000/weather-api:latest
```

### Q: 如何从另一台机器访问 Registry？
**A:** 需要将 Registry 配置为不安全的 Registry，编辑 Docker daemon 配置：
```json
{
  "insecure-registries": ["<host-ip>:5000"]
}
```

### Q: 如何持久化 Registry 数据？
**A:** 修改 `registry-deployment.yml`，将 emptyDir 改为 PersistentVolume：
```yaml
volumes:
  - name: registry-storage
    persistentVolumeClaim:
      claimName: registry-pvc
```

## 相关文件

- `registry-deployment.yml` - Registry 部署配置
- `deployment.yml` - 应用部署配置（使用本地 Registry）
- `deploy-with-registry.sh` - Linux/Mac 自动部署脚本
- `deploy-with-registry.bat` - Windows 自动部署脚本

## 架构图

```
┌─────────────────────────────────────┐
│     Docker Desktop / Docker Engine  │
│                                     │
│  ┌───────────────────────────────┐  │
│  │   localhost:5000 (Registry)   │  │
│  │  (存储 weather-api:latest)    │  │
│  └───────────────────────────────┘  │
└──────────────┬──────────────────────┘
               │ (docker push/pull)
               │
┌──────────────▼──────────────────────┐
│     Kubernetes Cluster              │
│                                     │
│  ┌───────────────────────────────┐  │
│  │  docker-registry namespace    │  │
│  │  (Registry Pod & Service)     │  │
│  └───────────────────────────────┘  │
│                                     │
│  ┌───────────────────────────────┐  │
│  │  derek-local namespace        │  │
│  │  (WeatherApi Pods)            │  │
│  │  (拉取镜像: :5000/weather-api)│  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```
