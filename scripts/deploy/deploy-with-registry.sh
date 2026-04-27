#!/bin/bash

# 部署本地 Registry 并推送镜像的脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== 1. 部署本地 Docker Registry ==="
kubectl apply -f "$PROJECT_ROOT/k8s/infrastructure/registry.yml"
echo "✓ Registry 部署完成"

echo ""
echo "=== 2. 等待 Registry 就绪 ==="
kubectl wait --for=condition=ready pod -l app=docker-registry -n docker-registry --timeout=60s
echo "✓ Registry 已就绪"

echo ""
echo "=== 3. 获取 Registry 地址 ==="
REGISTRY_IP=$(kubectl get svc docker-registry -n docker-registry -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$REGISTRY_IP" ]; then
  REGISTRY_IP=$(kubectl get svc docker-registry -n docker-registry -o jsonpath='{.spec.clusterIP}')
fi
echo "Registry 地址: $REGISTRY_IP:5000"

echo ""
echo "=== 4. 构建 WeatherApi 镜像 ==="
cd "$PROJECT_ROOT/src/Lab.Api"
docker build -t localhost:5000/weather-api:latest .
echo "✓ 镜像构建完成: localhost:5000/weather-api:latest"

echo ""
echo "=== 5. 推送镜像到本地 Registry ==="
docker push localhost:5000/weather-api:latest
echo "✓ 镜像推送完成"

echo ""
echo "=== 6. 部署应用到 Kubernetes ==="
kubectl apply -f "$PROJECT_ROOT/k8s/app/deployment.yml"
kubectl apply -f "$PROJECT_ROOT/k8s/app/service.yml"
kubectl apply -f "$PROJECT_ROOT/k8s/app/ingress.yml"
echo "✓ 应用部署完成"

echo ""
echo "=== 部署完成！==="
echo "Registry 地址: localhost:5000"
echo "应用地址: http://localhost (需要配置 /etc/hosts)"
echo ""
echo "验证命令:"
echo "  kubectl get pods -n derek-local"
echo "  kubectl get svc -n derek-local"
