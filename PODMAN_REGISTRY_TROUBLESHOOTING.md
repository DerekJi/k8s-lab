# Podman + Kubernetes Registry 推送问题诊断与解决

## 问题概述

在 Windows + WSL2 + Podman + Kind Kubernetes 环境中，无法将 Docker 镜像推送到 K8s 集群内的 HTTP Registry。最终通过配置防火墙和理解 Podman remote 架构解决。

## 问题链分析

### 问题 1: Podman 默认要求 HTTPS

**症状**
```
Error: trying to reuse blob ... at destination: pinging container registry localhost:5000: 
Get "https://localhost:5000/v2/": http: server gave HTTP response to HTTPS client
```

**原因**
- Podman 默认要求使用 HTTPS 连接 registry
- HTTP registry 被当作不安全的 registry，需要显式配置允许

**初始解决尝试**
```bash
podman push --tls-verify=false localhost:5000/weather-api:latest
```
虽然命令行参数可以禁用 TLS 验证，但不是持久的解决方案。

---

### 问题 2: registries.conf 配置文件位置不对

**症状**
在 Windows 的 `~/.config/containers/registries.conf` 中添加 insecure registry 配置，但 Podman 仍然尝试 HTTPS。

**原因**
- Podman 在 Windows 上采用 **remote 模式**
- 实际的 Podman 服务运行在 **WSL2/Podman Machine 内的 Linux VM** 中
- Podman 客户端（Windows）和服务（Linux VM）是分离的
- 配置文件修改必须在 **VM 内部** 进行

**架构理解**
```
Windows (宿主机)
├── Podman 客户端 (CLI)
├── ~/.config/containers/registries.conf (这里配置无效)
└── WSL2 / Podman Machine (Linux VM)
    └── Podman 服务
        └── /etc/containers/registries.conf (这里才有效!)
```

**正确解法**
```bash
podman machine ssh "cat >> /etc/containers/registries.conf << 'EOF'

[[registry]]
location = "172.25.16.1:5000"
insecure = true
EOF"
```

---

### 问题 3: Podman VM 无法访问 Windows host

**症状**
```
Error: dial tcp 127.0.0.1:5000: connect: no route to host
```
虽然本地 `curl http://localhost:5000/v2/_catalog` 可以访问，但 Podman VM 内无法连接。

**根本原因**
- Kubernetes port-forward 在 **Windows localhost (127.0.0.1)** 上监听
- Podman 服务运行在 **Linux VM 内**（172.25.30.116）
- 两个 localhost 不是同一个网络命名空间

**网络隔离图**
```
Windows Host (127.0.0.1)
  ├── kubectl port-forward 监听在 127.0.0.1:5000
  ├── Windows 防火墙
  └── [防火墙阻止] ← Podman VM (172.25.30.116) 无法访问

Podman VM (172.25.30.116)
  └── gateway: 172.25.16.1 (可以用来访问 Windows host)
```

**解决步骤**

1. **开放 Windows 防火墙**
```powershell
# 在管理员 PowerShell 中执行
New-NetFirewallRule -DisplayName 'Allow Podman Registry Port 5000' `
  -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow -Profile Any
```

2. **让 port-forward 绑定所有接口**
```bash
kubectl port-forward -n docker-registry svc/docker-registry 5000:5000 --address=0.0.0.0 &
```

3. **通过 Windows gateway IP 推送**
```bash
podman push --tls-verify=false 172.25.16.1:5000/weather-api:latest
```

---

### 问题 4: Kubernetes containerd 无法拉取 HTTP 镜像

**症状**
```
Failed to pull image "docker-registry.docker-registry.svc.cluster.local:5000/weather-api:latest":
failed to resolve reference: failed to do request: Head "https://...": 
lookup docker-registry.docker-registry.svc.cluster.local on [fc00:...]:53: no such host
```

**原因**
- containerd 默认需要 HTTPS 连接 registry
- containerd 使用 IPv6 DNS resolver 无法正确解析 Kubernetes DNS 名称
- DNS 解析问题导致连接失败

**解决方案**
在 K8s 节点内配置 containerd 信任 HTTP registry：

```bash
# 进入 kind 节点配置
podman exec k8s-new-control-plane sh -c "
mkdir -p /etc/containerd/certs.d/10.96.27.59:5000
cat > /etc/containerd/certs.d/10.96.27.59:5000/hosts.toml << 'EOF'
[host.\"http://10.96.27.59:5000\"]
  capabilities = [\"pull\", \"resolve\"]
  skip_verify = true
EOF"
```

其中 `10.96.27.59` 是 Registry Service 的 ClusterIP。

**为什么用 ClusterIP 而不是 DNS 名称？**
- containerd 的镜像拉取过程使用了不同于 Pod DNS 的 resolver
- 直接用 ClusterIP 绕过 DNS 解析问题
- 在 K8s 集群内部，ClusterIP 总是可以到达

---

## 最终完整解决方案

### 前置条件
- Windows 防火墙已开放 5000 端口
- Registry 已在 K8s 集群中运行
- containerd 已配置信任 HTTP registry

### 推送镜像工作流

```bash
# 1. 启动 port-forward（绑定所有接口）
kubectl port-forward -n docker-registry svc/docker-registry 5000:5000 --address=0.0.0.0 &

# 2. 构建镜像
cd src/Lab.Api
podman build -t 172.25.16.1:5000/weather-api:latest .
cd ../..

# 3. 推送镜像（禁用 TLS 验证）
podman push --tls-verify=false 172.25.16.1:5000/weather-api:latest

# 4. 验证镜像在 Registry 中
curl http://localhost:5000/v2/_catalog

# 5. 部署应用（K8s 从 ClusterIP 拉取）
kubectl apply -f deployment.yml
```

### Deployment 配置

```yaml
spec:
  containers:
    - name: dotnet-lab-api
      image: 10.96.27.59:5000/weather-api:latest  # Registry ClusterIP
      imagePullPolicy: Always
```

---

## 关键学习点

### 1. Podman Remote 架构的理解
- Podman 在 Windows 上采用 client-server 模式
- 客户端在 Windows，服务在 Linux VM
- 配置文件必须在服务所在的 VM 内修改
- `podman machine ssh` 是与 VM 交互的方式

### 2. 网络隔离的处理
- Windows 防火墙不仅阻止外部连接，也阻止 VM 到 host 的连接
- 需要显式开放防火墙规则
- 通过 gateway IP (172.25.16.1) 从 VM 访问 Windows host

### 3. Kubernetes containerd 配置
- containerd 有独立的 registry 信任配置
- 直接用 ClusterIP 比 DNS 名称更可靠
- `/etc/containerd/certs.d/<registry>/hosts.toml` 格式

### 4. 调试策略
- 分层测试：先测试网络连通性，再测试 DNS，最后测试应用拉取
- 使用 `podman machine ssh` 从 VM 内部测试网络和配置
- 检查 Pod 事件和 containerd 日志诊断拉取问题

---

## 相关配置文件变更

### registry-deployment.yml
```yaml
# Service 从 LoadBalancer 改为 NodePort (便于调试)
spec:
  type: NodePort
  ports:
    - port: 5000
      targetPort: 5000
      nodePort: 32000
```

### deployment.yml
```yaml
# 使用 Registry ClusterIP 而不是 DNS 名称
image: 10.96.27.59:5000/weather-api:latest
imagePullPolicy: Always
```

---

## 故障排查清单

- [ ] Windows 防火墙是否开放了 5000 端口？
  ```powershell
  Get-NetFirewallRule -DisplayName '*Port 5000*'
  ```

- [ ] Podman VM 能否访问 Windows host？
  ```bash
  podman machine ssh "curl http://172.25.16.1:5000/v2/_catalog"
  ```

- [ ] 镜像是否在 Registry 中？
  ```bash
  curl http://localhost:5000/v2/_catalog
  ```

- [ ] containerd 配置是否正确？
  ```bash
  podman exec k8s-new-control-plane cat /etc/containerd/certs.d/10.96.27.59:5000/hosts.toml
  ```

- [ ] Pod 事件是否显示成功拉取？
  ```bash
  kubectl describe pod -n derek-local <pod-name> | grep -A5 Events
  ```

---

## 总结表格

| 问题 | 症状 | 原因 | 解决方案 |
|------|------|------|----------|
| HTTPS 强制 | `http: server gave HTTP response to HTTPS client` | Podman 默认 HTTPS | Podman VM 内 registries.conf 添加 insecure 配置 |
| 配置位置错误 | 配置不生效 | 配置在 Windows，服务在 VM | 用 `podman machine ssh` 修改 VM 内配置 |
| VM 无法访问 host | `connect: no route to host` | Windows 防火墙阻止 + 网络隔离 | 开放防火墙 + 用 gateway IP (172.25.16.1) |
| containerd 拉取失败 | `no such host` | containerd 不信任 HTTP registry | 配置 /etc/containerd/certs.d/ 允许 HTTP |

---

**最后更新**: 2026-04-20  
**状态**: ✅ 完全解决，应用从 Registry 正常拉取镜像

