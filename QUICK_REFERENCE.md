# 🚀 快速参考卡

## 日常使用

### 启动应用（一行命令）
```bash
kubectl port-forward -n derek-local svc/dotnet-lab-api-service 5555:80 --address=127.0.0.1
```

### 访问
- **Swagger UI**: http://localhost:5555/swagger/index.html
- **API 文档**: http://localhost:5555/swagger/v1/swagger.json
- **天气 API**: http://localhost:5555/api/weather

### 使用启动脚本（更简单）
```bash
bash start-swagger.sh          # 默认端口 5555
bash start-swagger.sh 8080     # 自定义端口
```

## 故障排查

### 问题: Swagger 无法访问
```bash
# 1. 检查 port-forward 是否运行
ps aux | grep "port-forward"

# 2. 检查 Pod 状态
kubectl get pods -n derek-local

# 3. 检查端口是否被占用
netstat -ano | grep 5555

# 4. 查看应用日志
kubectl logs -n derek-local $(kubectl get pods -n derek-local -o jsonpath='{.items[0].metadata.name}')
```

### 问题: Podman 无法连接
```bash
# 重启 Podman machine
podman machine stop && sleep 2 && podman machine start

# 等待就绪后重新连接
sleep 5
kubectl cluster-info
```

### 问题: 集群无法恢复
```bash
# 运行完整恢复脚本
# 需要创建 recovery.sh 或手动执行：

# 1. 重建集群
kind delete cluster --name kind-cluster
kind create cluster --name kind-cluster

# 2. 重新部署（见 RECOVERY_LOG.md）
```

## 文件结构
```
d:/source/k8s-lab/
├── start-swagger.sh              ← 启动脚本
├── start-app.sh                  ← 备用启动脚本
├── deployment.yml                ← K8s Deployment
├── service.yml                   ← K8s Service
├── SWAGGER_SOLUTION.md           ← 详细故障排查
├── RECOVERY_LOG.md               ← 恢复过程文档
├── src/
│   └── Lab.Api/                  ← 应用源代码
│       ├── Dockerfile
│       ├── Program.cs
│       ├── Controllers/
│       │   └── WeatherController.cs
│       └── Models/
│           └── WeatherForecast.cs
└── k8s-lab.sln                   ← 解决方案文件
```

## 关键概念

### 为什么用 port-forward？
- Kind 集群是本地测试环境
- Ingress 在 kind 中不可靠（资源限制）
- Port-forward 是官方推荐的做法

### 为什么不用 NodePort + localhost?
- Windows 上 localhost 可能无法连接 k8s NodePort
- 需要通过 port-forward 桥接

### Podman vs Docker?
- 公司政策要求用 Podman
- Podman 与 Docker 命令兼容
- 但 Podman machine（VM）比 Docker Desktop 更容易不稳定

## 常用 kubectl 命令

```bash
# 查看 Pod
kubectl get pods -n derek-local
kubectl describe pod -n derek-local <pod-name>
kubectl logs -n derek-local <pod-name>

# 查看 Service
kubectl get svc -n derek-local
kubectl get endpoints -n derek-local

# 等待 Pod 就绪
kubectl wait --for=condition=ready pod -n derek-local -l app=dotnet-lab-api --timeout=120s

# 执行命令
kubectl exec -it -n derek-local <pod-name> -- /bin/sh
```

## 问题反馈

如果 Swagger 仍然无法访问：
1. 检查是否在后台运行了 port-forward
2. 检查端口是否被其他进程占用
3. 检查 Pod 是否正常运行
4. 检查应用日志是否有错误
5. 查看完整的故障排查指南: SWAGGER_SOLUTION.md

---

最后更新: 2026-04-18  
应用状态: ✅ 正常运行
