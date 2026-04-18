#!/bin/bash
# 启动持久的 port-forward 脚本
# 用途：在本地 localhost:30080 上暴露 K8s 应用

echo "=========================================="
echo "启动应用访问代理"
echo "=========================================="
echo ""

# 确保 port-forward 正确设置
echo "📡 建立 port-forward: localhost:30080 -> 应用 Pod:8080"
echo ""

kubectl port-forward -n derek-local $(kubectl get pods -n derek-local -o jsonpath='{.items[0].metadata.name}') 30080:8080

echo ""
echo "port-forward 已停止"
