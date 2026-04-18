#!/bin/bash
# Start port-forward to access the WebAPI Swagger UI

PORT=${1:-5555}

echo "🚀 启动 port-forward..."
echo "   Swagger 将在 http://localhost:${PORT}/swagger/index.html 可访问"
echo ""
echo "   按 Ctrl+C 停止"
echo ""

kubectl port-forward -n derek-local svc/dotnet-lab-api-service ${PORT}:80 --address=127.0.0.1
