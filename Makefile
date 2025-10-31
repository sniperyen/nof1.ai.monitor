.PHONY: help build up down restart logs logs-monitor logs-web test status clean shell up-monitor up-web rebuild install

# 颜色定义
COLOR_RESET   := \033[0m
COLOR_BOLD    := \033[1m
COLOR_GREEN   := \033[32m
COLOR_YELLOW  := \033[33m
COLOR_BLUE    := \033[34m
COLOR_RED     := \033[31m

# 默认目标
.DEFAULT_GOAL := help

# 帮助信息
help: ## 显示帮助信息
	@echo "$(COLOR_BOLD)Makefile 命令列表$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)基本操作:$(COLOR_RESET)"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOR_GREEN)%-20s$(COLOR_RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(COLOR_YELLOW)示例:$(COLOR_RESET)"
	@echo "  make build    # 构建 Docker 镜像"
	@echo "  make up       # 启动所有服务"
	@echo "  make logs     # 查看日志"
	@echo ""

# 检查 .env 文件是否存在
check-env:
	@if [ ! -f .env ]; then \
		echo "$(COLOR_RED)❌ 未找到 .env 文件$(COLOR_RESET)"; \
		echo "$(COLOR_YELLOW)📋 请复制环境变量示例文件:$(COLOR_RESET)"; \
		echo "   cp env.example .env"; \
		echo ""; \
		echo "然后编辑 .env 文件配置必要的参数"; \
		exit 1; \
	fi

# 构建 Docker 镜像
build: ## 构建 Docker 镜像
	@echo "$(COLOR_BLUE)🔨 构建 Docker 镜像...$(COLOR_RESET)"
	docker-compose build
	@echo "$(COLOR_GREEN)✅ 镜像构建完成$(COLOR_RESET)"

# 启动所有服务
up: check-env ## 启动所有服务（监控 + Web）
	@echo "$(COLOR_BLUE)🚀 启动所有服务...$(COLOR_RESET)"
	docker-compose up -d
	@echo "$(COLOR_GREEN)✅ 服务已启动$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_YELLOW)📊 Web 界面: http://localhost:5010$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)📋 查看日志: make logs$(COLOR_RESET)"

# 停止所有服务
down: ## 停止所有服务
	@echo "$(COLOR_BLUE)🛑 停止所有服务...$(COLOR_RESET)"
	docker-compose down
	@echo "$(COLOR_GREEN)✅ 服务已停止$(COLOR_RESET)"

# 重启所有服务
restart: ## 重启所有服务
	@echo "$(COLOR_BLUE)🔄 重启所有服务...$(COLOR_RESET)"
	docker-compose restart
	@echo "$(COLOR_GREEN)✅ 服务已重启$(COLOR_RESET)"

# 查看所有服务日志
logs: ## 查看所有服务日志
	docker-compose logs -f

# 查看监控服务日志
logs-monitor: ## 查看监控服务日志
	docker-compose logs -f monitor

# 查看 Web 服务日志
logs-web: ## 查看 Web 服务日志
	docker-compose logs -f web

# 测试通知功能
test: check-env ## 测试通知功能
	@echo "$(COLOR_BLUE)🧪 测试通知功能...$(COLOR_RESET)"
	docker-compose run --rm monitor python main.py --test
	@echo "$(COLOR_GREEN)✅ 测试完成$(COLOR_RESET)"

# 查看服务状态
status: ## 查看服务状态
	@echo "$(COLOR_BLUE)📊 服务状态:$(COLOR_RESET)"
	docker-compose ps
	@echo ""
	@echo "$(COLOR_BLUE)💾 资源使用情况:$(COLOR_RESET)"
	@docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" $$(docker-compose ps -q 2>/dev/null) 2>/dev/null || echo "暂无运行中的服务"

# 清理 Docker 资源
clean: ## 清理 Docker 资源（停止服务并删除容器、网络）
	@echo "$(COLOR_YELLOW)⚠️  这将停止所有服务并删除容器和网络$(COLOR_RESET)"
	@read -p "是否继续? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		echo "$(COLOR_GREEN)✅ 清理完成$(COLOR_RESET)"; \
	else \
		echo "$(COLOR_YELLOW)取消清理$(COLOR_RESET)"; \
	fi

# 深度清理（包括镜像）
clean-all: clean ## 深度清理（包括停止服务、删除容器、网络和镜像）
	@echo "$(COLOR_YELLOW)⚠️  这将删除 Docker 镜像$(COLOR_RESET)"
	@read -p "是否继续? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v --rmi all; \
		echo "$(COLOR_GREEN)✅ 深度清理完成$(COLOR_RESET)"; \
	else \
		echo "$(COLOR_YELLOW)取消清理$(COLOR_RESET)"; \
	fi

# 进入监控服务容器 shell
shell: ## 进入监控服务容器 shell
	docker-compose exec monitor /bin/bash

# 只启动监控服务
up-monitor: check-env ## 只启动监控服务
	@echo "$(COLOR_BLUE)🚀 启动监控服务...$(COLOR_RESET)"
	docker-compose up -d monitor
	@echo "$(COLOR_GREEN)✅ 监控服务已启动$(COLOR_RESET)"

# 只启动 Web 服务
up-web: check-env ## 只启动 Web 服务
	@echo "$(COLOR_BLUE)🚀 启动 Web 服务...$(COLOR_RESET)"
	docker-compose up -d web
	@echo "$(COLOR_GREEN)✅ Web 服务已启动$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_YELLOW)📊 Web 界面: http://localhost:5010$(COLOR_RESET)"

# 查看容器状态
ps:
	@echo "$(COLOR_BLUE)📊 容器状态:$(COLOR_RESET)"
	@docker-compose ps

# 重新构建并启动
rebuild: clean ## 重新构建镜像并启动所有服务
	@echo "$(COLOR_BLUE)🔨 重新构建并启动...$(COLOR_RESET)"
	make build
	make up

# 本地安装（不使用 Docker）
install: ## 本地安装依赖
	@echo "$(COLOR_BLUE)📦 检查 Python 版本...$(COLOR_RESET)"
	@python3 --version
	@echo ""
	@echo "$(COLOR_BLUE)📦 创建虚拟环境...$(COLOR_RESET)"
	python3 -m venv venv
	@echo ""
	@echo "$(COLOR_BLUE)📦 安装依赖包...$(COLOR_RESET)"
	./venv/bin/pip install --upgrade pip
	./venv/bin/pip install -r requirements.txt
	@echo ""
	@echo "$(COLOR_GREEN)✅ 安装完成$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_YELLOW)激活虚拟环境: source venv/bin/activate$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)运行程序: python main.py$(COLOR_RESET)"

# 健康检查
health: ## 检查服务健康状态
	@echo "$(COLOR_BLUE)🏥 健康检查:$(COLOR_RESET)"
	@docker-compose ps --format json | jq -r '.[] | "\(.Name): \(.State) - \(.Status)"' 2>/dev/null || docker-compose ps

# 备份数据
backup: ## 备份数据文件
	@echo "$(COLOR_BLUE)💾 备份数据文件...$(COLOR_RESET)"
	@mkdir -p backups
	@if [ -f current.json ]; then cp current.json backups/current_$$(date +%Y%m%d_%H%M%S).json; fi
	@if [ -f last.json ]; then cp last.json backups/last_$$(date +%Y%m%d_%H%M%S).json; fi
	@if [ -d data ]; then cp -r data backups/data_$$(date +%Y%m%d_%H%M%S); fi
	@if [ -d logs ]; then cp -r logs backups/logs_$$(date +%Y%m%d_%H%M%S); fi
	@echo "$(COLOR_GREEN)✅ 备份完成: backups/$(COLOR_RESET)"

# 查看最新日志（最后 50 行）
tail: ## 查看最新日志（最后 50 行）
	docker-compose logs --tail=50

# 更新代码并重启
update: ## 拉取最新代码并重启服务
	@echo "$(COLOR_BLUE)📥 拉取最新代码...$(COLOR_RESET)"
	git pull
	@echo ""
	@echo "$(COLOR_BLUE)🔨 重新构建...$(COLOR_RESET)"
	make rebuild

# 显示环境变量
env-show: ## 显示当前配置的环境变量（隐藏敏感信息）
	@echo "$(COLOR_BLUE)📋 环境变量配置:$(COLOR_RESET)"
	@if [ -f .env ]; then \
		grep -v "^\s*#" .env | grep -v "^\s*$$" | sed 's/=.*/=***/'; \
	else \
		echo "$(COLOR_RED)未找到 .env 文件$(COLOR_RESET)"; \
	fi

# 验证配置
validate: check-env ## 验证配置文件
	@echo "$(COLOR_BLUE)✅ 验证配置文件...$(COLOR_RESET)"
	@docker-compose config > /dev/null
	@echo "$(COLOR_GREEN)✅ 配置文件有效$(COLOR_RESET)"