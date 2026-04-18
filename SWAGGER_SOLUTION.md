# Swagger 访问解决方案

## 📊 问题分析

### 问题 1: Nginx Ingress 在 kind 中失效
**症状:**
- Nginx controller Pod 在运行，但无法处理请求
- 错误: `pthread_create() failed (11: Resource temporarily unavailable)`
- Worker 进程无法创建，所有请求超时

**根本原因:**
- Kind 集群内存/资源约束严格
- Nginx-ingress-controller 需要大量线程，在 kind 中 pthread 创建失败
- 这是 kind 环境的已知限制，不是应用问题

**解决方案:**
- ✅ 删除 Ingress，改用 NodePort + port-forward
- 这在单机开发环境中是标准做法

### 问题 2: Port 30080 和 9090 被占用
**症状:**
- 尝试启动 port-forward 时端口已被占用
- 错误: `bind: Only one usage of each socket address`

**原因:**
- 之前的 port-forward 进程在后台运行
- Windows 的 TIME_WAIT 状态延迟端口释放

**解决方案:**
- ✅ 强制杀死占用的进程: `taskkill /PID <pid> /F`
- ✅ 改用其他端口（如 5555）

## ✅ 当前工作状态

### 访问方式
```bash
# 方式 1: 使用启动脚本
bash start-swagger.sh        # 默认使用端口 5555
bash start-swagger.sh 30080  # 使用指定端口

# 方式 2: 手动启动
kubectl port-forward -n derek-local svc/dotnet-lab-api-service 5555:80 --address=127.0.0.1
```

### 访问 Swagger
```bash
# 在浏览器中打开或用 curl
curl http://localhost:5555/swagger/index.html

# 或直接访问 API
curl http://localhost:5555/api/weather
```

## 📋 部署架构（最终版）

```
┌─────────────────────────────────────────────────────┐
│                  本地开发环境                         │
├─────────────────────────────────────────────────────┤
│                                                     │
│  localhost:5555 ──┐                                │
│                   ├─→ port-forward ──→ K8s Node   │
│  localhost:5556 ──┘                 ↓             │
│                              Service (ClusterIP)  │
│                                     ↓             │
│                    ┌──────────────────────────┐   │
│                    │  Pod 1                   │   │
│                    │  (dotnet-lab-api:8080)  │   │
│                    └──────────────────────────┘   │
│                                     ↕             │
│                    ┌──────────────────────────┐   │
│                    │  Pod 2                   │   │
│                    │  (dotnet-lab-api:8080)  │   │
│                    └──────────────────────────┘   │
│                                                   │
│  ❌ Nginx Ingress (已删除 - kind 不支持)          │
│                                                   │
└─────────────────────────────────────────────────────┘
```

## 🔧 关键配置

### Service 配置 (service.yml)
```yaml
type: NodePort
port: 80              # 集群内端口
targetPort: 8080      # Pod 实际监听端口
```

### 部署配置 (deployment.yml)
```yaml
env:
  - name: ASPNETCORE_ENVIRONMENT
    value: Development  # 启用 Swagger UI
containers:
  - containerPort: 8080
```

## 📝 故障排查命令

```bash
# 检查 Pod 状态
kubectl get pods -n derek-local

# 查看 Pod 日志
kubectl logs -n derek-local <pod-name>

# 检查 Service 端点
kubectl get endpoints -n derek-local dotnet-lab-api-service

# 检查占用的端口
netstat -ano | grep -E "(5555|30080|9090)"

# 杀死占用端口的进程
taskkill /PID <pid> /F
```

## 💡 学到的经验

1. **Nginx Ingress 在 kind 中有限制**
   - Kind 提供的资源约束会导致 Nginx worker 创建失败
   - 生产环境应使用完整的 Kubernetes 集群

2. **Port-forward 是开发环境的标准做法**
   - 简单可靠
   - 避免 Ingress 复杂性
   - 适合单机开发

3. **端口管理**
   - 始终检查端口占用: `netstat -ano | grep :port`
   - 使用不常见的端口避免冲突（如 5555）
   - 确保旧进程完全终止

## 🚀 下次快速启动

```bash
# 一键启动
bash start-swagger.sh

# 测试
curl http://localhost:5555/swagger/index.html
```

---

最后更新: 2026-04-18
状态: ✅ 工作正常
