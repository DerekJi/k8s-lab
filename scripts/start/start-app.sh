#!/bin/bash
# 启动应用并通过 port-forward 暴露访问
# 此脚本可在后台持续运行

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "K8s WebAPI 应用启动脚本"
echo "=========================================="
echo ""

# 确定端口
PORT=${1:-9090}
echo "📡 使用端口: $PORT"
echo ""

# 获取 Pod 信息
echo "🔍 查找应用 Pod..."
POD=$(kubectl get pods -n derek-local -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD" ]; then
    echo "❌ 错误：找不到应用 Pod"
    echo "请先运行: kubectl apply -f k8s/app/deployment.yml"
    exit 1
fi

echo "✓ 找到 Pod: $POD"
echo ""

# 启动 port-forward
echo "启动 port-forward..."
echo "📝 命令: kubectl port-forward -n derek-local svc/dotnet-lab-api-service $PORT:80"
echo ""
echo "应用将在以下地址可访问:"
echo "  - Swagger UI:  http://localhost:$PORT/swagger/index.html"
echo "  - API 端点:    http://localhost:$PORT/api/weather"
echo ""
echo "按 Ctrl+C 停止"
echo ""

kubectl port-forward -n derek-local svc/dotnet-lab-api-service $PORT:80
