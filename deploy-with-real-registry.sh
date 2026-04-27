#!/bin/bash

# 使用本地 Registry 的完整部署流程（正确版本）

set -e

echo "========================================="
echo "本地 Registry 完整部署流程"
echo "========================================="
echo ""

# Step 1: 确保 Registry 运行
echo "=== Step 1: 部署 Registry ==="
kubectl apply -f registry-deployment.yml
echo "✓ Registry 部署完成"
echo ""

# Step 2: 等待 Registry 就绪
echo "=== Step 2: 等待 Registry 就绪 ==="
kubectl wait --for=condition=ready pod -l app=docker-registry -n docker-registry --timeout=60s
echo "✓ Registry 已就绪"
echo ""

# Step 3: 启动 port-forward（后台运行）
echo "=== Step 3: 启动 Registry port-forward ==="
kubectl port-forward -n docker-registry svc/docker-registry 5000:5000 --address=127.0.0.1 >/dev/null 2>&1 &
PF_PID=$!
sleep 2
echo "✓ Port-forward 已启动 (PID: $PF_PID)"
echo ""

# Step 4: 构建镜像
echo "=== Step 4: 构建镜像 ==="
cd src/Lab.Api
podman build -t localhost:5000/weather-api:latest .
cd ../..
echo "✓ 镜像构建完成"
echo ""

# Step 5: 配置 Podman Registry（允许 HTTP）
echo "=== Step 5: 配置 Podman Registry ==="
# 检查是否已配置
if ! podman info 2>/dev/null | grep -q "localhost:5000"; then
  echo "配置 insecure registry..."
  mkdir -p ~/.config/containers
  if [ ! -f ~/.config/containers/registries.conf ]; then
    cat > ~/.config/containers/registries.conf << 'EOF'
[[registry]]
location = "localhost:5000"
insecure = true
EOF
    echo "✓ Registries 配置完成"
  fi
fi
echo ""

# Step 6: 推送镜像到 Registry
echo "=== Step 6: 推送镜像到 Registry ==="
echo "推送 localhost:5000/weather-api:latest..."
podman push localhost:5000/weather-api:latest
echo "✓ 镜像推送完成"
echo ""

# Step 7: 验证镜像
echo "=== Step 7: 验证镜像在 Registry 中 ==="
REPOS=$(curl -s http://localhost:5000/v2/_catalog)
echo "Registry 中的镜像: $REPOS"
if echo "$REPOS" | grep -q "weather-api"; then
  echo "✓ 镜像已成功推送到 Registry"
else
  echo "✗ 警告: 镜像未在 Registry 中找到"
fi
echo ""

# Step 8: 更新 deployment 使用 Registry 中的镜像
echo "=== Step 8: 更新应用配置 ==="
cat > deployment.yml << 'EOF'
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
          image: docker-registry.docker-registry.svc.cluster.local:5000/weather-api:latest
          imagePullPolicy: Always  # 总是从 Registry 拉取最新镜像
          ports:
            - containerPort: 8080
          env:
            - name: ASPNETCORE_ENVIRONMENT
              value: Development
EOF
echo "✓ deployment.yml 已更新为使用 Registry"
echo ""

# Step 9: 部署应用
echo "=== Step 9: 部署应用 ==="
kubectl apply -f deployment.yml
kubectl apply -f service.yml
kubectl apply -f ingress.yml
echo "✓ 应用部署完成"
echo ""

# Step 10: 等待 Pod 就绪
echo "=== Step 10: 等待应用就绪 ==="
kubectl wait --for=condition=ready pod -l app=dotnet-lab-api -n derek-local --timeout=120s || {
  echo "✗ Pod 启动失败，查看日志..."
  kubectl logs -n derek-local -l app=dotnet-lab-api --tail=20
  kill $PF_PID 2>/dev/null || true
  exit 1
}
echo "✓ 应用已就绪"
echo ""

# Step 11: 清理 port-forward
echo "=== Step 11: 清理 ==="
kill $PF_PID 2>/dev/null || true
echo "✓ 清理完成"
echo ""

echo "========================================="
echo "✅ 部署完成！"
echo "========================================="
echo ""
echo "应用信息:"
echo "  - Namespace: derek-local"
echo "  - Service: dotnet-lab-api-service"
echo "  - Replicas: 2"
echo ""
echo "验证命令:"
echo "  kubectl get pods -n derek-local"
echo "  kubectl port-forward -n derek-local svc/dotnet-lab-api-service 5555:80"
echo ""
echo "Registry 信息:"
echo "  - Namespace: docker-registry"
echo "  - Service: docker-registry"
echo "  - 地址: docker-registry.docker-registry.svc.cluster.local:5000"
echo ""
