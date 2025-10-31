# Docker 部署指南

## 快速开始

### 1. 准备配置文件

```bash
# 复制环境变量示例文件
cp env.example .env

# 编辑 .env 文件，配置必要的参数
nano .env  # 或使用您喜欢的编辑器
```

必需的配置项：

```env
# 至少配置一个通知渠道
WECHAT_WEBHOOK_URL=https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_WEBHOOK_KEY

# 或配置 Telegram
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=your_chat_id
```

### 2. 构建并启动

```bash
# 构建 Docker 镜像
make build

# 启动所有服务
make up

# 访问 Web 界面
# http://localhost:5010
```

就这么简单！🎉

## 常用命令

### 使用 Makefile（推荐）

```bash
make build         # 构建 Docker 镜像
make up            # 启动所有服务
make down          # 停止所有服务
make restart       # 重启所有服务
make logs          # 查看所有日志
make logs-monitor  # 查看监控服务日志
make logs-web      # 查看 Web 服务日志
make test          # 测试通知功能
make status        # 查看服务状态
make shell         # 进入容器 shell
make help          # 查看所有命令
```

### 直接使用 Docker Compose

```bash
# 构建
docker-compose build

# 启动所有服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down

# 重启服务
docker-compose restart
```

## 架构说明

### 服务结构

项目使用 Docker Compose 编排两个服务：

#### 1. monitor 服务（监控服务）

- **功能**: 定时获取持仓数据，分析变化并发送通知
- **执行频率**: 每分钟一次
- **数据文件**: `current.json`, `last.json`
- **日志**: `logs/trading_monitor.log`

#### 2. web 服务（Web 展示服务）

- **功能**: 提供持仓表格 Web 界面
- **端口**: 5010
- **访问地址**: http://localhost:5010
- **数据来源**: 只读访问 `current.json`, `last.json`
- **特性**: 
  - 中英文切换
  - 15秒自动刷新
  - 响应式设计

### 数据流

```
API (nof1.ai)
    ↓
monitor 服务
    ↓
[current.json] ←→ [last.json]
    ↑                ↑
    │                │
    └────────────────┘
           ↓
      web 服务
           ↓
       浏览器 (http://localhost:5010)
```

### 文件挂载

以下文件/目录挂载到宿主机，实现数据持久化：

- `./data:/app/data` - 历史数据（如果启用）
- `./logs:/app/logs` - 日志文件
- `./last.json:/app/last.json` - 上次数据
- `./current.json:/app/current.json` - 当前数据

## 环境变量配置

在 `.env` 文件中配置以下变量：

### 通知配置

```env
# 企业微信机器人（可选）
WECHAT_WEBHOOK_URL=https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY

# Telegram 机器人（可选）
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=your_chat_id
TELEGRAM_PROXY=127.0.0.1:7890
```

### 监控配置

```env
# API 地址
API_URL=https://nof1.ai/api

# 监控的模型列表（可选，为空则监控所有模型）
MONITORED_MODELS=model1,model2

# 日志级别
LOG_LEVEL=INFO

# 是否保存历史数据
SAVE_HISTORY_DATA=False
```

### Web 服务配置

```env
# Flask 服务配置
FLASK_ENV=production
HOST=0.0.0.0
PORT=5010
```

## 部署场景

### 场景 1: 本地开发

```bash
# 启动所有服务
make up

# 查看实时日志
make logs

# 测试通知
make test
```

### 场景 2: 生产环境

```bash
# 1. 确保 .env 文件配置正确
# 2. 构建镜像
make build

# 3. 启动服务（后台运行）
make up

# 4. 检查状态
make status

# 5. 查看日志
make logs
```

### 场景 3: 仅运行监控（无 Web）

```bash
# 只启动监控服务
make up-monitor

# 查看监控日志
make logs-monitor
```

### 场景 4: 仅运行 Web（调试）

```bash
# 只启动 Web 服务
make up-web

# 查看 Web 日志
make logs-web
```

## 故障排除

### 问题 1: 构建失败

```bash
# 检查 Docker 是否安装
docker --version

# 检查 Docker Compose 是否安装
docker-compose --version

# 清理缓存后重新构建
docker-compose build --no-cache
make build
```

### 问题 2: 服务无法启动

```bash
# 检查配置文件
make validate

# 检查环境变量
make env-show

# 查看详细日志
make logs
```

### 问题 3: 通知发送失败

```bash
# 测试通知功能
make test

# 进入容器检查配置
make shell

# 在容器内测试
python main.py --test
```

### 问题 4: Web 页面无法访问

```bash
# 检查端口是否被占用
netstat -tlnp | grep 5010

# 检查 Web 服务状态
make logs-web

# 检查防火墙设置
```

### 问题 5: 数据文件权限问题

```bash
# 如果遇到权限问题，修改文件所有者
sudo chown -R $USER:$USER current.json last.json data/ logs/
```

## 性能优化

### 资源限制

docker-compose.yml 中已配置资源限制：

```yaml
deploy:
  resources:
    limits:
      cpus: "1.0"      # 限制最大 CPU
      memory: 512M     # 限制最大内存
    reservations:
      cpus: "0.25"     # 预留 CPU
      memory: 128M     # 预留内存
```

### 日志管理

自动限制日志文件大小，防止磁盘空间耗尽：

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"    # 单个日志文件最大 10MB
    max-file: "3"      # 最多保留 3 个日志文件
```

## 数据备份

### 备份命令

```bash
# 使用 Makefile
make backup

# 手动备份
cp current.json backups/current_$(date +%Y%m%d_%H%M%S).json
cp last.json backups/last_$(date +%Y%m%d_%H%M%S).json
tar -czf backups/data_$(date +%Y%m%d_%H%M%S).tar.gz data/
```

### 恢复数据

```bash
# 停止服务
make down

# 恢复数据文件
cp backups/current_20250101_120000.json current.json
cp backups/last_20250101_120000.json last.json

# 重启服务
make up
```

## 更新升级

```bash
# 方法 1: 拉取最新代码并重建
git pull
make rebuild

# 方法 2: 使用 update 命令（自动拉取并重建）
make update

# 方法 3: 仅更新代码，手动重建
git pull
docker-compose down
docker-compose build
docker-compose up -d
```

## 监控和维护

### 健康检查

```bash
# 检查服务健康状态
make health

# 查看容器状态
docker-compose ps
```

### 日志分析

```bash
# 实时查看日志
make logs

# 查看最后 50 行
make tail

# 只查看错误日志
docker-compose logs | grep ERROR
```

### 清理空间

```bash
# 清理停止的容器
docker-compose down

# 清理所有资源（包括数据卷）
make clean

# 深度清理（包括镜像）
make clean-all
```

## 安全建议

1. ✅ **使用非 root 用户**: Dockerfile 中已配置
2. ✅ **资源限制**: docker-compose.yml 中已配置
3. ✅ **日志限制**: 防止日志文件过大
4. ✅ **健康检查**: 自动检测服务状态
5. ⚠️ **生产环境**: 
   - 使用 HTTPS（建议配置 Nginx 反向代理）
   - 限制端口访问
   - 定期更新镜像和依赖包

## 常见问题

### Q: 可以用 Docker Swarm 或 Kubernetes 吗？

A: 可以。当前 docker-compose.yml 已包含 `deploy` 配置，可直接用于 Docker Swarm。

### Q: 如何自定义端口？

A: 修改 docker-compose.yml 中的端口映射：

```yaml
web:
  ports:
    - "8080:5010"  # 宿主机:容器
```

### Q: 如何添加更多服务？

A: 在 docker-compose.yml 中添加新服务定义，例如：

```yaml
services:
  # 现有服务...
  
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    depends_on:
      - web
```

### Q: 数据会丢失吗？

A: 不会。通过 volume 挂载，数据持久化到宿主机。

### Q: 如何调试容器内的代码？

A: 使用 `make shell` 进入容器，或使用 `docker-compose exec monitor bash`。

## 技术支持

如有问题，请：

1. 查看日志: `make logs`
2. 检查配置: `make env-show`
3. 提交 Issue: [GitHub Issues](https://github.com/okay456okay/nof1.ai.monitor/issues)
4. 查看文档: [README.md](README.md)

---

**提示**: 使用 `make help` 可以查看所有可用命令。