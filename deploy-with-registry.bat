@echo off
setlocal enabledelayedexpansion

echo === 1. 部署本地 Docker Registry ===
kubectl apply -f registry-deployment.yml
if %errorlevel% neq 0 (
    echo Registry 部署失败
    exit /b 1
)
echo Registry 部署完成

echo.
echo === 2. 等待 Registry 就绪 ===
kubectl wait --for=condition=ready pod -l app=docker-registry -n docker-registry --timeout=60s
if %errorlevel% neq 0 (
    echo 等待超时
    exit /b 1
)
echo Registry 已就绪

echo.
echo === 3. 构建 WeatherApi 镜像 ===
cd src\Lab.Api
docker build -t localhost:5000/weather-api:latest .
if %errorlevel% neq 0 (
    echo 镜像构建失败
    exit /b 1
)
echo 镜像构建完成: localhost:5000/weather-api:latest

echo.
echo === 4. 推送镜像到本地 Registry ===
docker push localhost:5000/weather-api:latest
if %errorlevel% neq 0 (
    echo 镜像推送失败
    exit /b 1
)
echo 镜像推送完成

echo.
echo === 5. 部署应用到 Kubernetes ===
cd ..\..\
kubectl apply -f deployment.yml
kubectl apply -f service.yml
kubectl apply -f ingress.yml
echo 应用部署完成

echo.
echo === 部署完成！ ===
echo Registry 地址: localhost:5000
echo 应用地址: http://localhost
echo.
echo 验证命令:
echo   kubectl get pods -n derek-local
echo   kubectl get svc -n derek-local
