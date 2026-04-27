# WebAPI 访问指南

## ✅ 应用状态

✅ **应用完全正常运行！**
- 2 个 Pod 副本在 derek-local namespace 正常运行
- Swagger UI 已验证可访问
- API 端点正常返回天气数据

---

## 🚀 快速开始

### 推荐方式：使用启动脚本

```bash
# 在项目根目录执行
bash start-app.sh
```

或指定自定义端口：
```bash
bash start-app.sh 8080
```

然后在浏览器或 curl 中访问：
```
# 访问 Swagger UI
http://localhost:9090/swagger/index.html

# 调用 API
curl http://localhost:9090/api/weather
```

---

## 📋 手动启动方法

### 方法 1：通过 Service

```bash
kubectl port-forward -n derek-local svc/dotnet-lab-api-service 9090:80
```

### 方法 2：直接连接 Pod

```bash
POD=$(kubectl get pods -n derek-local -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n derek-local $POD 9090:8080
```

---

## 🌐 访问应用

### Swagger UI

打开浏览器访问：
```
http://localhost:9090/swagger/index.html
```

### 使用 curl 测试

```bash
# 获取天气数据
curl http://localhost:9090/api/weather

# 返回示例
[
  {"date":"2026-04-19","temperatureC":54,"temperatureF":129,"summary":"Hot"},
  ...
]
```

---

## ✅ 验证清单

- [x] 2 个 Pod 正在运行
- [x] Swagger UI 可访问
- [x] API 端点返回正确数据
- [x] 应用监听 8080 端口
- [x] port-forward 已配置

---

## 📌 关键信息

**当前配置：**
- Namespace: `derek-local`
- Service: `dotnet-lab-api-service`
- Pod 端口: `8080`
- Service 端口: `80`
- 推荐本地端口: `9090`

**API 端点：**
- `GET /api/weather` - 获取天气预报数据
- `GET /swagger/index.html` - 访问 Swagger 文档

---

## 🔧 故障排除

### 端口已被占用

```bash
# 使用不同端口
bash start-app.sh 8888
```

### port-forward 无法连接

检查 Pod 状态：
```bash
kubectl get pods -n derek-local
kubectl describe pod -n derek-local <pod-name>
```

### 应用无响应

查看应用日志：
```bash
kubectl logs -n derek-local <pod-name>
```

---

## 📝 注意

**Ingress 说明：**
- 原计划使用 Ingress 暴露服务
- 由于 kind 环境限制，改用 port-forward
- port-forward 同样可靠稳定，适合本地开发

**生产环境：**
- 生产环境使用 Ingress/LoadBalancer
- 不需要 port-forward
- 直接通过 DNS 或 IP 访问

---

## 🎯 总结

应用已完全部署并验证可用！

**当前状态：** ✅ **就绪**

使用以下命令启动：
```bash
bash start-app.sh
```

然后访问 `http://localhost:9090/swagger/index.html`

