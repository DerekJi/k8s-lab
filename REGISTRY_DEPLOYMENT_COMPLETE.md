# 本地 Registry 部署完成指南

## ✅ 部署状态

**当前配置已完成：**
- ✅ Registry Deployment 已在 `docker-registry` namespace 中运行
- ✅ WeatherApi 镜像已构建并加载到 K8s 集群
- ✅ 应用已成功部署到 `derek-local` namespace
- ✅ 所有 Pod 运行正常 (2/2 Ready)

## 🚀 完整部署工作流

### 场景 1: 首次部署（已完成）

1. **部署本地 Registry**
   ```bash
   kubectl apply -f registry-deployment.yml
   ```

2. **构建镜像**
   ```bash
   cd src/Lab.Api
   podman build -t localhost:5000/weather-api:latest .
   cd ../..
   ```

3. **加载镜像到 K8s 集群**
   ```bash
   podman save -o weather-api.tar localhost:5000/weather-api:latest
   kind load image-archive weather-api.tar --name k8s-new
   rm weather-api.tar
   ```

4. **部署应用**
   ```bash
   kubectl apply -f deployment.yml
   kubectl apply -f service.yml
   kubectl apply -f ingress.yml
   ```

### 场景 2: 更新镜像（推荐流程）

当代码更新需要重新部署时：

```bash
# 1. 修改代码后，重新构建镜像
cd src/Lab.Api
podman build -t localhost:5000/weather-api:latest .
cd ../..

# 2. 加载到集群
podman save -o weather-api.tar localhost:5000/weather-api:latest
kind load image-archive weather-api.tar --name k8s-new
rm weather-api.tar

# 3. 强制更新部署（重启 Pod）
kubectl rollout restart deployment/dotnet-lab-api -n derek-local
```

### 场景 3: 仅部署（使用已有镜像）

如果镜像已经在集群中：

```bash
kubectl apply -f deployment.yml
```

## 📦 Registry 的实际用途

### 当前方案的特点：
- ✅ **离线支持** - 镜像加载到集群后无需网络
- ✅ **快速迭代** - 镜像构建一次，可多次部署
- ✅ **隔离** - 镜像存储在集群内，不暴露到公网
- ⚠️  **本地数据** - 重启集群会丢失镜像（使用 emptyDir）

### Registry 可用于：

**生产级持久化（需修改）：**
```yaml
# 替换 registry-deployment.yml 中的 volumes：
volumes:
  - name: registry-storage
    persistentVolumeClaim:
      claimName: registry-pvc
```

然后创建 PVC：
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry-pvc
  namespace: docker-registry
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

## 🔧 常见操作

### 查看镜像（使用 Registry 存储）

```bash
# 通过 port-forward 访问 Registry API
kubectl port-forward -n docker-registry svc/docker-registry 5000:5000 &

# 查看镜像列表
curl -s http://localhost:5000/v2/_catalog

# 查看镜像的 tag
curl -s http://localhost:5000/v2/weather-api/tags/list
```

### 推送镜像到 Registry（完整流程）

```bash
# 1. 设置 port-forward
kubectl port-forward -n docker-registry svc/docker-registry 5000:5000 &

# 2. 推送镜像（禁用 TLS）
podman push --tls-verify=false localhost:5000/weather-api:latest

# 3. 验证
curl -s http://localhost:5000/v2/_catalog

# 4. 停止 port-forward
kill %1
```

### 删除镜像

```bash
# 删除本地 Podman 镜像
podman rmi localhost:5000/weather-api:latest

# 删除集群中的镜像（重新构建并加载）
podman build -t localhost:5000/weather-api:v2 .
podman save -o weather-api.tar localhost:5000/weather-api:v2
kind load image-archive weather-api.tar --name k8s-new
```

## 🔍 故障排查

### Pod 无法拉取镜像

**症状：** ImagePullBackOff 或 ErrImagePull

**解决：**
```bash
# 检查镜像是否在集群中
kind get images --name k8s-new | grep weather-api

# 如果没有，重新加载
podman save -o weather-api.tar localhost:5000/weather-api:latest
kind load image-archive weather-api.tar --name k8s-new
rm weather-api.tar

# 重启部署
kubectl rollout restart deployment/dotnet-lab-api -n derek-local
```

### Registry 无法访问

**症状：** connection refused

**解决：**
```bash
# 检查 Registry Pod
kubectl get pods -n docker-registry

# 查看日志
kubectl logs -n docker-registry -l app=docker-registry

# 检查 Service
kubectl get svc -n docker-registry
```

### 镜像推送失败

**错误信息：** http: server gave HTTP response to HTTPS client

**解决：** 使用 `--tls-verify=false` 参数

```bash
podman push --tls-verify=false localhost:5000/weather-api:latest
```

## 📝 相关文件说明

| 文件 | 用途 |
|------|------|
| `registry-deployment.yml` | Registry 的 K8s 部署配置 |
| `deployment.yml` | 应用部署配置（使用本地镜像） |
| `LOCAL_REGISTRY_GUIDE.md` | 详细的 Registry 操作指南 |
| `QUICK_REFERENCE.md` | 日常快速参考 |

## 🎯 下一步

### 生产级部署改进：

1. **添加持久化存储**
   - 修改 Registry 使用 PersistentVolume
   - 确保镜像不会因重启而丢失

2. **配置 HTTPS**
   - 为 Registry 添加 SSL 证书
   - 配置 Podman 信任证书

3. **添加认证**
   - 为 Registry 添加用户名/密码
   - 配置 imagePullSecrets

4. **多镜像支持**
   - 在 Registry 中存储多个应用镜像
   - 建立镜像版本管理

5. **废弃物清理**
   - 定期清理旧镜像
   - 设置存储配额

## 📚 参考命令

```bash
# 镜像操作
podman images                                    # 查看本地镜像
podman build -t <tag> .                         # 构建镜像
podman save -o file.tar <image>                 # 导出镜像
podman rmi <image>                              # 删除镜像

# Kind 操作
kind get clusters                               # 列出集群
kind load image-archive file.tar --name <name> # 加载镜像到集群
kind get images --name <name>                  # 查看集群中的镜像

# Kubernetes 操作
kubectl apply -f file.yml                       # 应用配置
kubectl rollout restart deployment/<name>      # 重启部署
kubectl get pods -n <namespace>                # 查看 Pod
kubectl logs <pod> -n <namespace>              # 查看日志

# Registry 操作
kubectl port-forward -n docker-registry svc/docker-registry 5000:5000 # 端口转发
curl http://localhost:5000/v2/_catalog         # 查看镜像列表
```

---

**部署完成时间**: 2026-04-20  
**状态**: ✅ 生产就绪（本地开发环境）

