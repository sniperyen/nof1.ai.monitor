#!/bin/bash
# Docker 环境快速测试脚本

set -e

echo "🧪 Docker 环境测试脚本"
echo ""

# 检查 Docker 是否安装
echo "1️⃣ 检查 Docker 环境..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装"
    exit 1
fi
echo "✅ Docker: $(docker --version)"

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose 未安装"
    exit 1
fi
echo "✅ Docker Compose: $(docker-compose --version)"
echo ""

# 检查 .env 文件
echo "2️⃣ 检查配置文件..."
if [ ! -f .env ]; then
    echo "⚠️  .env 文件不存在，从示例文件创建..."
    cp env.example .env
    echo "✅ 已创建 .env 文件，请编辑配置"
else
    echo "✅ .env 文件存在"
fi
echo ""

# 检查 Dockerfile
echo "3️⃣ 检查 Docker 文件..."
if [ ! -f Dockerfile ]; then
    echo "❌ Dockerfile 不存在"
    exit 1
fi
echo "✅ Dockerfile 存在"

if [ ! -f docker-compose.yml ]; then
    echo "❌ docker-compose.yml 不存在"
    exit 1
fi
echo "✅ docker-compose.yml 存在"
echo ""

# 清理旧的容器和镜像
echo "4️⃣ 清理旧资源（可选）..."
read -p "是否清理旧的 Docker 资源？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker-compose down -v 2>/dev/null || true
    echo "✅ 清理完成"
fi
echo ""

# 构建镜像
echo "5️⃣ 构建 Docker 镜像..."
docker-compose build
echo "✅ 镜像构建完成"
echo ""

# 测试启动
echo "6️⃣ 测试启动服务..."
echo "提示: 按 Ctrl+C 停止测试（不会影响正式运行）"
echo ""

timeout=30
if docker-compose up -d; then
    echo "✅ 服务启动成功"
    echo "等待 $timeout 秒查看服务状态..."
    sleep 5
    
    # 显示服务状态
    docker-compose ps
    
    echo ""
    echo "📋 查看日志（最后10行）:"
    docker-compose logs --tail=10
    
    echo ""
    echo "⏱️  继续运行 $timeout 秒后自动停止..."
    sleep $timeout
    
    # 停止服务
    docker-compose down
    echo "✅ 测试完成，服务已停止"
else
    echo "❌ 服务启动失败"
    echo "查看日志："
    docker-compose logs
    exit 1
fi

echo ""
echo "🎉 Docker 环境测试完成！"
echo ""
echo "下一步："
echo "  1. 编辑 .env 文件配置参数"
echo "  2. 运行 'make up' 启动服务"
echo "  3. 访问 http://localhost:5010"
