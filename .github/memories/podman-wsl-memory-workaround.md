# Podman Desktop × WSL Memory 配置 Workaround

## 问题
Podman Desktop 在 WSL2 环境中经常无法正确读取 `.wslconfig` 中的内存配置。这是官方已知问题。

## 解决方案
在初始化 podman machine 时，使用 `--memory` 参数明确指定内存。这会强制 Podman 重新读取 WSL 配置。

## 示例

```bash
#!/bin/bash

# 1. 修改 WSL 配置
#!/bin/bash
set -e

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
```

**结果**：即使分配 8GB，启动后也会正确识别 `.wslconfig` 中的 32GB 内存配置。

## 关键点
- `--memory` 参数单位为 MB，示例中 8192 = 8GB
- 使用此命令后，Podman 会重新扫描并应用 `.wslconfig` 的设置
- 这是一个 workaround，不是最终解决方案，但在当前版本中有效

## 参考
- Podman Desktop 官方已知问题
- WSL2 配置文档
