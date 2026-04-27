# k8s-lab

本地 Kubernetes 实验项目，基于 .NET 8 Web API，使用 Kind + Podman 运行于 Windows/WSL 环境。

## 项目结构

```
k8s-lab/
├── src/                        # 应用源代码
│   ├── Lab.Api/                # .NET 8 Web API（天气预报示例）
│   └── k8s-lab.sln
├── k8s/                        # Kubernetes 清单文件
│   ├── app/                    # 应用资源（Deployment / Service / Ingress）
│   ├── infrastructure/         # 基础设施（Ingress-Nginx / 本地 Registry）
│   └── tests/                  # 冒烟测试
├── scripts/                    # 运维脚本
│   ├── deploy/                 # 部署脚本
│   ├── start/                  # 本地启动脚本
│   └── maintenance/            # 维护 & 恢复脚本
└── docs/                       # 文档
    ├── guides/                 # 操作指南
    ├── architecture/           # 架构决策
    ├── troubleshooting/        # 故障排查
    └── milestones/             # 里程碑记录
```

## 快速开始

### 1. 部署应用

```bash
# 方式一：直接部署（镜像需提前加载到集群）
kubectl apply -f k8s/app/deployment.yml
kubectl apply -f k8s/app/service.yml
kubectl apply -f k8s/app/ingress.yml

# 方式二：使用一键部署脚本
bash scripts/deploy/deploy-all.sh
```

### 2. 启动本地访问

```bash
# 通过 port-forward 暴露 Swagger UI
bash scripts/start/start-swagger.sh          # 默认端口 5555
bash scripts/start/start-swagger.sh 8080     # 自定义端口

# 或手动执行
kubectl port-forward -n derek-local svc/dotnet-lab-api-service 5555:80 --address=127.0.0.1
```

### 3. 访问地址

| 功能 | 地址 |
|------|------|
| Swagger UI | http://localhost:5555/swagger/index.html |
| Weather API | http://localhost:5555/api/weather |

## 镜像构建与部署

```bash
# 构建镜像
cd src/Lab.Api
podman build -t localhost:5000/weather-api:latest .
cd ../..

# 加载到 Kind 集群（推荐，无需 Registry）
podman save -o weather-api.tar localhost:5000/weather-api:latest
kind load image-archive weather-api.tar --name k8s-new
rm weather-api.tar

# 部署应用
kubectl apply -f k8s/app/deployment.yml
```

### 使用本地 Registry 部署

```bash
bash scripts/deploy/deploy-with-registry.sh     # 推送镜像到本地 Registry
bash scripts/deploy/deploy-with-real-registry.sh  # 完整流程（含 Registry 部署）
```

## 常用 kubectl 命令

```bash
# 查看状态
kubectl get pods -n derek-local
kubectl get svc -n derek-local
kubectl logs -n derek-local <pod-name>

# 等待 Pod 就绪
kubectl wait --for=condition=ready pod -n derek-local -l app=dotnet-lab-api --timeout=120s

# 重启应用
kubectl rollout restart deployment/dotnet-lab-api -n derek-local
```

## 故障排查

```bash
# Podman 无法连接
podman machine stop && sleep 2 && podman machine start

# 集群完全恢复
bash scripts/maintenance/auto-recovery.sh
```

详细故障排查见 [docs/troubleshooting/podman-registry.md](docs/troubleshooting/podman-registry.md)

## 文档索引

| 分类 | 文档 |
|------|------|
| 操作指南 | [部署指南](docs/guides/deployment.md) · [访问配置](docs/guides/access.md) · [本地 Registry](docs/guides/local-registry.md) · [Swagger 配置](docs/guides/swagger.md) |
| 架构决策 | [方案权衡](docs/architecture/tradeoffs.md) · [为什么用 Registry](docs/architecture/why-registry.md) |
| 故障排查 | [Podman Registry 问题](docs/troubleshooting/podman-registry.md) · [恢复日志](docs/troubleshooting/recovery-log.md) |

---

**环境**: Kind + Podman · .NET 8 · Kubernetes 1.30
