#!/bin/bash
# auto-recovery.sh - 完全自动恢复脚本
# 用途: 一键恢复整个应用栈
# 使用: bash auto-recovery.sh

set -e

PROJECT_DIR="/d/source/k8s-lab"
CLUSTER_NAME="kind-cluster"
NAMESPACE="derek-local"
IMAGE_NAME="localhost/dotnet-webapi:latest"
PORT=5555

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 自动恢复脚本启动"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 函数：重试机制
retry_cmd() {
    local max_attempts=3
    local attempt=1
    local delay=2
    
    while [ $attempt -le $max_attempts ]; do
        echo "尝试 ($attempt/$max_attempts): $@"
        if eval "$@"; then
            return 0
        fi
        if [ $attempt -lt $max_attempts ]; then
            echo "⏳ 等待 ${delay} 秒后重试..."
            sleep $delay
            delay=$((delay * 2))
        fi
        attempt=$((attempt + 1))
    done
    
    echo "❌ 命令失败（已重试 $max_attempts 次）"
    return 1
}

# 步骤 1: 检查 Podman
echo ""
echo "✓ 步骤 1: 检查 Podman..."
if ! podman ps > /dev/null 2>&1; then
    echo "⚠️  Podman 无法连接，重启中..."
    podman machine stop 2>/dev/null || true
    sleep 2
    podman machine start
    sleep 5
fi
echo "✓ Podman 正常"

# 步骤 2: 清理旧集群
echo ""
echo "✓ 步骤 2: 清理旧集群..."
kind delete cluster --name $CLUSTER_NAME 2>/dev/null || true
sleep 2
echo "✓ 旧集群已清理"

# 步骤 3: 创建新集群（带重试）
echo ""
echo "✓ 步骤 3: 创建新集群..."
retry_cmd "kind create cluster --name $CLUSTER_NAME --wait 5m" || exit 1
sleep 2
echo "✓ 新集群已创建"

# 步骤 4: 验证集群连接
echo ""
echo "✓ 步骤 4: 验证集群连接..."
kubectl cluster-info
echo "✓ 集群连接正常"

# 步骤 5: 构建镜像
echo ""
echo "✓ 步骤 5: 构建镜像..."
cd "$PROJECT_DIR/src/Lab.Api"
podman build -t $IMAGE_NAME . --quiet
echo "✓ 镜像已构建"

# 步骤 6: 导入镜像到 kind
echo ""
echo "✓ 步骤 6: 导入镜像到 kind..."
podman save $IMAGE_NAME -o /tmp/dotnet-webapi.tar
kind load image-archive /tmp/dotnet-webapi.tar --name $CLUSTER_NAME
rm /tmp/dotnet-webapi.tar
echo "✓ 镜像已导入"

# 步骤 7: 部署应用
echo ""
echo "✓ 步骤 7: 部署应用..."
cd "$PROJECT_DIR"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
kubectl apply -f deployment.yml > /dev/null 2>&1
kubectl apply -f service.yml > /dev/null 2>&1
echo "✓ 应用已部署"

# 步骤 8: 等待 Pod 就绪
echo ""
echo "✓ 步骤 8: 等待 Pod 就绪..."
retry_cmd "kubectl wait --for=condition=ready pod -l app=dotnet-lab-api -n $NAMESPACE --timeout=120s" || exit 1
echo "✓ Pod 已就绪"

# 步骤 9: 验证应用
echo ""
echo "✓ 步骤 9: 验证应用..."
READY_PODS=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[?(@.status.conditions[?(@.type=="Ready")].status=="True")].metadata.name}' | wc -w)
if [ "$READY_PODS" -ge 2 ]; then
    echo "✓ 应用验证成功 ($READY_PODS 个 Pod 就绪)"
else
    echo "⚠️  只有 $READY_PODS 个 Pod 就绪（预期 2 个）"
fi

# 步骤 10: 显示访问信息
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 恢复完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 下一步:"
echo ""
echo "1️⃣  启动 port-forward 在另一个终端:"
echo "   kubectl port-forward -n $NAMESPACE svc/dotnet-lab-api-service $PORT:80 --address=127.0.0.1"
echo ""
echo "2️⃣  访问 Swagger UI:"
echo "   curl http://localhost:$PORT/swagger/index.html"
echo ""
echo "3️⃣  或直接运行："
echo "   bash start-swagger.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
