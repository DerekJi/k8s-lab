@echo off
REM 一键部署脚本（Windows）

set "PROJECT_ROOT=%~dp0..\.."

echo.
echo ================================
echo 开始部署 K8s 应用
echo ================================

REM 1. 安装 nginx-ingress-controller
echo.
echo 1. 正在部署 nginx-ingress-controller...
kubectl apply -f "%PROJECT_ROOT%\k8s\infrastructure\ingress-nginx.yml"
echo ✓ nginx-ingress-controller 部署完成，请等待 Pod 启动（约 1-2 分钟）

REM 2. 等待 nginx 启动
echo.
echo 2. 等待 nginx-ingress 就绪...
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
if errorlevel 1 echo ⚠ nginx 启动超时，请手动检查

REM 3. 部署应用
echo.
echo 3. 正在部署你的应用...
kubectl apply -f "%PROJECT_ROOT%\k8s\app\deployment.yml"
kubectl apply -f "%PROJECT_ROOT%\k8s\app\service.yml"
kubectl apply -f "%PROJECT_ROOT%\k8s\app\ingress.yml"
echo ✓ 应用部署完成

REM 4. 查看状态
echo.
echo 4. 资源状态：
echo --- Deployments ---
kubectl get deployment -n derek-local
echo.
echo --- Pods ---
kubectl get pods -n derek-local
echo.
echo --- Services ---
kubectl get service -n derek-local
echo.
echo --- Ingress ---
kubectl get ingress -n derek-local

echo.
echo ================================
echo 部署完成！
echo ================================
echo.
echo 下一步：
echo 1. 编辑你的 hosts 文件（C:\Windows\System32\drivers\etc\hosts），添加：
echo    127.0.0.1 k8s-local
echo.
echo 2. 访问你的应用：
echo    http://k8s-local/swagger/index.html
echo.
pause
