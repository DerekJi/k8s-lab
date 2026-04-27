#!/bin/bash
echo "🔧 初始化 Podman 虚拟机..."

# 1. 修改 WSL 配置
cat > ~/.wslconfig << 'WSLEOF'
[wsl2]
memory=16GB
processors=4
swap=2GB
localhostForwarding=true
WSLEOF

# 2. 【关键】关闭 WSL，让配置生效
echo "⏹️  关闭 WSL..."
wsl --shutdown
sleep 10

# 3. 清理旧虚拟机
podman machine stop 2>/dev/null || true
podman machine rm podman-machine-default -f 2>/dev/null || true

# 4. 创建新虚拟机
podman machine init --memory 8192 --cpus 4

# 5. 设置为 rootful
podman machine set --rootful

# 6. 启动
podman machine start

# 7. 验证
echo ""
echo "✅ 虚拟机配置完成！"
echo "=== 虚拟机资源 ==="
podman machine inspect | grep -A 5 Resources
echo ""
echo "=== Rootful 状态 ==="
podman machine inspect | grep Rootful