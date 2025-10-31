#!/bin/bash
#
# nof1.ai 监控系统快速启动脚本
# 自动检查环境、构建镜像并启动服务
#

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        return 1
    fi
    return 0
}

# 主函数
main() {
    echo ""
    echo "🚀 nof1.ai 监控系统快速启动"
    echo "================================"
    echo ""

    # 1. 检查 Docker 是否安装
    print_info "检查 Docker 环境..."
    if ! check_command docker; then
        print_error "Docker 未安装，请先安装 Docker"
        echo "访问: https://docs.docker.com/get-docker/"
        exit 1
    fi
    print_success "Docker 已安装: $(docker --version)"

    # 2. 检查 Docker Compose 是否安装
    if ! check_command docker-compose; then
        print_error "Docker Compose 未安装，请先安装 Docker Compose"
        echo "访问: https://docs.docker.com/compose/install/"
        exit 1
    fi
    print_success "Docker Compose 已安装: $(docker-compose --version)"
    echo ""

    # 3. 检查 .env 文件
    print_info "检查配置文件..."
    if [ ! -f .env ]; then
        print_warning ".env 文件不存在"
        if [ -f env.example ]; then
            print_info "从 env.example 创建 .env 文件..."
            cp env.example .env
            print_success ".env 文件已创建"
            print_warning "请编辑 .env 文件配置通知渠道等参数"
            echo ""
            echo "重要配置项："
            echo "  - WECHAT_WEBHOOK_URL: 企业微信机器人地址"
            echo "  - TELEGRAM_BOT_TOKEN: Telegram 机器人 Token"
            echo "  - TELEGRAM_CHAT_ID: Telegram 聊天 ID"
            echo ""
            read -p "按回车键继续，或 Ctrl+C 取消..."
        else
            print_error "env.example 文件不存在"
            exit 1
        fi
    else
        print_success ".env 文件存在"
    fi
    echo ""

    # 4. 检查必要的配置
    if grep -q "YOUR_WEBHOOK_KEY\|your_bot_token" .env; then
        print_warning "请先配置 .env 文件中的通知参数"
        read -p "是否继续启动？[y/N]: " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "已取消"
            exit 0
        fi
    fi

    # 5. 创建必要的目录
    print_info "创建必要的目录..."
    mkdir -p data logs backups
    print_success "目录准备完成"
    echo ""

    # 6. 检查是否已有运行中的容器
    print_info "检查是否有运行中的服务..."
    if docker-compose ps | grep -q "Up"; then
        print_warning "已有服务正在运行"
        read -p "是否重启服务？[y/N]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "停止现有服务..."
            docker-compose down
            print_success "服务已停止"
        fi
    fi
    echo ""

    # 7. 构建镜像
    print_info "构建 Docker 镜像..."
    if docker-compose build; then
        print_success "镜像构建完成"
    else
        print_error "镜像构建失败"
        exit 1
    fi
    echo ""

    # 8. 启动服务
    print_info "启动服务..."
    if docker-compose up -d; then
        print_success "服务启动成功"
    else
        print_error "服务启动失败"
        exit 1
    fi
    echo ""

    # 9. 等待服务就绪
    print_info "等待服务就绪..."
    sleep 5

    # 10. 检查服务状态
    print_info "检查服务状态..."
    if docker-compose ps | grep -q "Up"; then
        print_success "服务运行正常"
    else
        print_warning "部分服务可能未正常启动"
        echo ""
        print_info "查看日志: docker-compose logs"
    fi
    echo ""

    # 11. 显示信息
    echo "================================"
    print_success "启动完成！"
    echo "================================"
    echo ""
    echo "📊 Web 界面: http://localhost:5010"
    echo "📋 查看日志: docker-compose logs -f"
    echo "🛑 停止服务: docker-compose down"
    echo ""
    echo "或使用 make 命令："
    echo "  make logs      # 查看日志"
    echo "  make status    # 查看状态"
    echo "  make down      # 停止服务"
    echo "  make help      # 查看帮助"
    echo ""

    # 12. 测试通知（可选）
    read -p "是否测试通知功能？[y/N]: " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "发送测试通知..."
        docker-compose run --rm monitor python main.py --test
        echo ""
    fi

    echo ""
    print_info "启动完成！请访问 http://localhost:5010 查看持仓信息"
    echo ""
}

# 运行主函数
main

