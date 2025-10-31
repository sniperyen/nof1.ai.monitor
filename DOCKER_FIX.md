# Docker 文件挂载问题修复

## 问题描述

**错误**: `[Errno 21] Is a directory: 'current.json'`

**原因**: Docker Compose 的卷挂载配置中直接挂载 `current.json` 和 `last.json` 文件，当宿主机上这些文件不存在时，Docker 会创建空目录而不是文件。

## 修复方案

### 1. 修复 Docker Compose 配置 ✅

**文件**: `docker-compose.yml`

**修改前**:

```yaml
volumes:
  - ./data:/app/data
  - ./logs:/app/logs
  - ./last.json:/app/last.json # 问题：文件不存在时会创建目录
  - ./current.json:/app/current.json # 问题：文件不存在时会创建目录
```

**修改后**:

```yaml
volumes:
  - ./data:/app/data
  - ./logs:/app/logs
  # 移除文件级别的挂载，让容器内自行管理 JSON 文件
```

**Web 服务** (只读访问):

```yaml
volumes:
  - ./data:/app/data:ro
  - ./logs:/app/logs:ro
  # 移除 JSON 文件挂载，通过 data 目录共享
```

### 2. 添加代码安全检查 ✅

**文件**: `position_fetcher.py:268-271`

```python
def save_positions(self, data: Dict[str, Any], filename: str = "current.json") -> bool:
    try:
        # 安全检查：如果目标是一个目录，先删除它
        if os.path.exists(filename) and os.path.isdir(filename):
            self.logger.warning(f"{filename} 是一个目录，将删除并重建为文件")
            os.rmdir(filename)

        # 继续保存...
```

## 修复逻辑

### 为什么移除文件挂载？

1. **Docker 行为**: Docker 挂载不存在的文件时会创建空目录
2. **自动创建**: 让应用在容器内自动创建和管理 JSON 文件
3. **数据持久化**: 通过 `data` 目录挂载实现持久化
4. **简化配置**: 减少卷挂载配置，降低出错概率

### 数据持久化方案

**监控服务**:

- `./data:/app/data` - 历史数据持久化
- `./logs:/app/logs` - 日志持久化
- `current.json` 和 `last.json` 在容器内自动管理

**Web 服务**:

- `./data:/app/data:ro` - 只读访问历史数据
- `./logs:/app/logs:ro` - 只读访问日志
- 通过 `data` 目录共享的数据文件可访问

## 部署步骤

### 1. 清理宿主机上的目录

```bash
# 删除错误创建的目录
rm -rf current.json last.json
```

### 2. 重新构建和启动

```bash
# 停止服务
make down

# 清理旧的容器和网络
docker-compose down -v

# 重新构建
make build

# 启动服务
make up

# 查看日志
make logs
```

### 3. 验证修复

```bash
# 检查文件是否正常创建
docker-compose exec monitor ls -la /app/ | grep -E "(current|last).json"

# 应该看到正常的文件（不是目录）
# -rw-r--r-- 1 appuser appuser 1234 Oct 30 16:40 current.json
```

## 优势

- ✅ 避免目录创建错误
- ✅ 简化 Docker 配置
- ✅ 自动文件管理
- ✅ 保持数据持久化
- ✅ 代码自动修复遗留问题

## 注意事项

1. **首次运行**: 应用会在容器内自动创建 `current.json` 和 `last.json`
2. **数据持久化**: 历史数据保存在 `data` 目录中
3. **Web 访问**: Web 服务通过 `data` 目录可以访问需要的数据
4. **向后兼容**: 如果有遗留的目录问题，代码会自动修复

## 推荐的数据管理方式

### 方案 A: 完全容器内管理（推荐）

- JSON 文件在容器内
- 历史数据通过 `data` 目录持久化
- Web 服务通过共享卷访问数据

### 方案 B: 如果需要宿主机直接访问

如果需要从宿主机直接访问 `current.json` 和 `last.json`，可以在启动前创建空文件：

```bash
# 创建空文件
touch current.json last.json

# 然后启动服务
make up
```

但更推荐方案 A，更符合 Docker 最佳实践。
