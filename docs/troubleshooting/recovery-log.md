# 应用恢复记录

## 📋 事件时间线

### 问题发生
- **时间**: 2026-04-18 19:50 左右
- **症状**: port-forward 连接丢失，Podman 守护进程无响应
- **根本原因**: Podman machine 崩溃或被中断

### 恢复过程
1. 检测到 Podman 无法连接
2. 重启 Podman machine: `podman machine start`
3. 发现原 kind 集群无法恢复
4. 删除旧集群并创建新集群
5. 重新构建和部署应用

## 🔄 完整恢复命令

```bash
# 1. 重启 Podman（如果需要）
podman machine stop
sleep 2
podman machine start

# 2. 创建新的 kind 集群（如果旧集群不可用）
kind delete cluster --name kind-cluster 2>/dev/null
kind create cluster --name kind-cluster --wait 5m

# 3. 构建镜像
cd src/Lab.Api
podman build -t localhost/dotnet-webapi:latest .

# 4. 导出和导入镜像到 kind
podman save localhost/dotnet-webapi:latest -o /tmp/dotnet-webapi.tar
kind load image-archive /tmp/dotnet-webapi.tar --name kind-cluster

# 5. 部署应用
cd /d/source/k8s-lab
kubectl create namespace derek-local --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f deployment.yml
kubectl apply -f service.yml

# 6. 等待 Pod 就绪
kubectl wait --for=condition=ready pod -l app=dotnet-lab-api -n derek-local --timeout=120s

# 7. 启动 port-forward
kubectl port-forward -n derek-local svc/dotnet-lab-api-service 5555:80 --address=127.0.0.1

# 8. 测试
curl http://localhost:5555/swagger/index.html
```

## 📊 恢复前后对比

| 项目 | 恢复前 | 恢复后 |
|------|-------|-------|
| Podman 状态 | ❌ 无法连接 | ✅ 正常运行 |
| K8s 集群 | ❌ 无法访问 | ✅ 新集群创建 |
| 应用 Pod | ❌ 丢失 | ✅ 2/2 运行中 |
| Swagger UI | ❌ 无法访问 | ✅ localhost:5555 |
| API 端点 | ❌ 无法访问 | ✅ 正常响应 |

## 💡 关键学习

### Podman 稳定性
- Podman machine 可能在某些情况下无响应
- 重启 machine 通常能解决连接问题
- 命令: `podman machine stop && sleep 2 && podman machine start`

### Kind 集群管理
- 如果 API server 无法连接，通常需要重建集群
- Kind 集群数据存储在 Podman 中，Podman 重启后可能需要重建
- 不要在生产环境依赖 kind 集群的持久性

### 镜像管理
- 在 kind 中使用镜像需要通过 `kind load image-archive` 导入
- `podman save` 导出镜像为 tar，然后用 `kind load` 导入
- 不能直接使用 `podman build` 的输出

## 🚀 快速恢复脚本

```bash
#!/bin/bash
# recovery.sh - 快速恢复脚本

set -e

echo "🔄 恢复 Podman..."
podman machine stop 2>/dev/null || true
sleep 2
podman machine start
sleep 5

echo "🔄 重建 kind 集群..."
kind delete cluster --name kind-cluster 2>/dev/null || true
kind create cluster --name kind-cluster --wait 5m

echo "🔄 重新构建镜像..."
cd src/Lab.Api
podman build -t localhost/dotnet-webapi:latest .

echo "🔄 导入镜像到 kind..."
podman save localhost/dotnet-webapi:latest -o /tmp/dotnet-webapi.tar
kind load image-archive /tmp/dotnet-webapi.tar --name kind-cluster

echo "🔄 部署应用..."
cd /d/source/k8s-lab
kubectl create namespace derek-local --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f deployment.yml
kubectl apply -f service.yml

echo "⏳ 等待 Pod 就绪..."
kubectl wait --for=condition=ready pod -l app=dotnet-lab-api -n derek-local --timeout=120s

echo "✅ 恢复完成！"
echo ""
echo "启动 port-forward:"
echo "  kubectl port-forward -n derek-local svc/dotnet-lab-api-service 5555:80 --address=127.0.0.1"
echo ""
echo "访问 Swagger:"
echo "  curl http://localhost:5555/swagger/index.html"
```

## 📌 当前状态（恢复后）

```
✅ Podman machine: 运行中
✅ Kind cluster: kind-cluster (新建)
✅ 应用 Pod: 2/2 Ready
✅ Swagger UI: localhost:5555
✅ API 端点: localhost:5555/api/weather
```

---

最后更新: 2026-04-18 19:52  
状态: ✅ 完全恢复
