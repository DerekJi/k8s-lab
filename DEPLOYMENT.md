# K8s 部署指南

## 项目结构

```
d:\source\k8s-lab\
├── src/Lab.Api/              # .NET WebAPI 项目
├── deployment.yml            # K8s Deployment 配置
├── service.yml               # K8s Service 配置
├── ingress.yml               # K8s Ingress 配置
├── ingress-nginx-deployment.yml  # nginx-ingress-controller
├── deploy-all.sh             # 一键部署脚本（Linux/Git Bash）
├── deploy-all.bat            # 一键部署脚本（Windows CMD）
└── Dockerfile                # Docker 镜像构建文件
```

## 部署步骤

### 1. 构建镜像
```bash
cd src/Lab.Api
podman build -t dotnet-webapi:latest .
cd ../..
```

### 2. 导出镜像为 tar
```bash
podman save -o dotnet-webapi.tar dotnet-webapi:latest
```

### 3. 导入镜像到 kind 集群
```bash
kind load image-archive --name kind-cluster dotnet-webapi.tar
```

### 4. 一键部署所有 K8s 资源

#### Linux/Git Bash：
```bash
bash deploy-all.sh
```

#### Windows CMD：
```cmd
deploy-all.bat
```

### 5. 配置 hosts 文件

**Windows：**
- 编辑 `C:\Windows\System32\drivers\etc\hosts`
- 添加一行：`127.0.0.1 k8s-local`

**Linux/Mac：**
- 编辑 `/etc/hosts`
- 添加一行：`127.0.0.1 k8s-local`

### 6. 访问应用

在浏览器访问：
- Swagger UI: `http://k8s-local/swagger/index.html`
- API 端点: `http://k8s-local/api/weather`

## 验证部署

```bash
# 查看 Deployment
kubectl get deployment -n derek-local

# 查看 Pods
kubectl get pods -n derek-local

# 查看 Service
kubectl get service -n derek-local

# 查看 Ingress
kubectl get ingress -n derek-local

# 查看 nginx-ingress 状态
kubectl get pods -n ingress-nginx
```

## 查看日志

```bash
# 查看应用日志
kubectl logs -n derek-local <pod-name>

# 查看 nginx-ingress 日志
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

## 手动部署单个资源

如果不想用脚本，可以手动部署：

```bash
# 部署 nginx-ingress（只需一次）
kubectl apply -f ingress-nginx-deployment.yml

# 等待 nginx 启动
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s

# 部署应用
kubectl apply -f deployment.yml
kubectl apply -f service.yml
kubectl apply -f ingress.yml
```

## 常见问题

### Ingress 的 ADDRESS 为空？
- nginx-ingress-controller 还没启动，请等待 1-2 分钟，或查看 `kubectl get pods -n ingress-nginx` 确认 Pod 状态。

### 访问 http://k8s-local 仍然无法连接？
- 确认已正确配置 hosts 文件
- 刷新浏览器缓存
- 检查 `kubectl get ingress -n derek-local` 是否有 ADDRESS

### Pod 显示 ImagePullBackOff？
- 确认已执行 `kind load image-archive` 导入镜像
- 检查 `podman images` 是否有 `dotnet-webapi:latest` 镜像

## 清理资源

```bash
# 删除应用（但保留 nginx-ingress）
kubectl delete deployment dotnet-lab-api -n derek-local
kubectl delete service dotnet-lab-api-service -n derek-local
kubectl delete ingress dotnet-lab-api-ingress -n derek-local

# 删除整个 namespace
kubectl delete namespace derek-local

# 删除 nginx-ingress（谨慎！）
kubectl delete namespace ingress-nginx
```
