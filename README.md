# 瓷砖SKU知识库采集系统

## 项目简介

瓷砖SKU知识库采集系统是一套面向瓷砖行业的自动化数据管线，覆盖**采集 → 解析 → 结构化 → 向量化 → 搜索**的完整链路。系统通过 Playwright 自动抓取高安产区四大陶瓷品牌（罗斯福、金泰源、华硕、瑞阳）的产品数据，利用 MinerU 解析产品 PDF 图册，借助 Qwen 大模型提取结构化 SKU 信息，最终通过 OpenCLIP 生成图像向量存入 Milvus，为微信小程序提供以图搜图、SKU 详情查询等接口。

## 技术栈

| 组件 | 技术选型 | 用途 |
| --- | --- | --- |
| 语言 | Python 3.11 | 主力开发语言 |
| Web 框架 | FastAPI | REST API 服务 |
| 关系数据库 | MySQL 8 | 品牌、系列、SKU、图片、PDF 元数据存储 |
| 向量数据库 | Milvus 2.4 | 512 维图像特征向量存储与相似度检索 |
| 浏览器自动化 | Playwright | 品牌官网产品数据抓取 |
| PDF 解析 | MinerU | PDF 图册内容提取（Markdown + 结构化 JSON） |
| 大语言模型 | Qwen3 (阿里通义千问) | PDF 内容结构化信息提取 |
| 图像向量化 | OpenCLIP (ViT-B-32) | 瓷砖产品图片特征提取 |
| 任务调度 | APScheduler | 定时全量采集与增量处理 |

## 系统架构

```
                        ┌──────────────────────────┐
                        │   微信小程序 / API 调用    │
                        └──────────┬───────────────┘
                                   │
                          FastAPI (REST)
                                   │
          ┌────────────┬───────────┼───────────┬──────────────┐
          ▼            ▼           ▼           ▼              ▼
     /api/search  /api/sku  /api/brands  /api/stats  /api/crawl/trigger
          │            │           │           │              │
          ▼            ▼           ▼           ▼              ▼
   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐
   │  Milvus  │ │  MySQL   │ │  MySQL   │ │  MySQL   │ │   任务调度    │
   │ 向量检索 │ │  SKU查询 │ │ 品牌查询 │ │ 统计查询 │ │ APScheduler  │
   └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────┬───────┘
                                                               │
                                              ┌────────────────┼────────────────┐
                                              ▼                ▼                ▼
                                       ┌────────────┐  ┌────────────┐  ┌────────────┐
                                       │ Playwright │  │   MinerU   │  │  OpenCLIP  │
                                       │ 产品抓取    │  │  PDF解析   │  │  图像向量化 │
                                       └─────┬──────┘  └─────┬──────┘  └─────┬──────┘
                                             │               │               │
                                             ▼               ▼               ▼
                                       品牌官网        PDF 图册        本地图片
                                     (罗斯福/金泰源/    (产品规格        (瓷砖产品照)
                                      华硕/瑞阳)        参数表)
```

### 数据管线流程

1. **采集阶段** — Playwright 蜘蛛访问各品牌官网，解析产品列表页、翻页、提取产品卡片信息（SKU 编码、名称、系列、规格、图片 URL、PDF 链接），通过 `BaseSpider.run_full_crawl()` 完成品牌→系列→SKU 三级数据的 MySQL upsert，并下载图片和 PDF 到本地。
2. **解析阶段** — MinerU 读取 `parse_status=0` 的待处理 PDF，调用 MinerU API 提取 Markdown 文本和结构化 JSON，结果保存到 `parser/output/` 目录，更新 `parse_status` 为 1（成功）或 2（失败）。
3. **结构化阶段** — Qwen 大模型读取已解析的 Markdown 内容，通过精心设计的 Prompt 提取 brand、series、sku、product_name、size、surface、color、thickness、material 九个字段，结果 upsert 写入 MySQL。
4. **向量化阶段** — OpenCLIP 读取 `vector_status=0` 的待处理图片，编码为 512 维归一化向量，批量插入 Milvus 的 `tile_image_vector` 集合（HNSW + COSINE 索引），更新 `vector_status` 为 1。
5. **搜索阶段** — FastAPI 接收用户上传的图片，通过 CLIP 编码后调用 Milvus 余弦相似度检索，返回 Top-10 匹配结果（品牌、系列、SKU、得分、图片路径），微信小程序展示。

## 快速开始

### 环境要求

- Docker 20.10+ / Docker Compose 2.0+
- Python 3.11+
- 推荐 8GB+ 内存（OpenCLIP 模型推理需要）

### 1. 克隆项目

```bash
git clone <repo-url> tile_ai
cd tile_ai
```

### 2. 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env` 文件，根据实际情况修改以下关键配置：

- `QWEN_API_KEY`: 阿里云通义千问 API Key（用于 PDF 结构化）
- `MINERU_API_URL`: MinerU 服务地址（若有自建服务）
- MySQL 和 Milvus 配置可使用默认值，Docker Compose 会统一管理

### 3. 启动所有服务

```bash
docker-compose up -d
```

这会启动以下容器：
- `tile_mysql` — MySQL 8 数据库（端口 3306）
- `tile_etcd` — Milvus 依赖的元数据存储
- `tile_minio` — Milvus 依赖的对象存储
- `tile_milvus` — Milvus 向量数据库（端口 19530）
- `tile_app` — FastAPI 应用 + 调度器（端口 8000）

### 4. 初始化数据库和向量集合

```bash
docker-compose exec app python db/init_db.py
```

该命令会自动创建所有 MySQL 表（brands、series、skus、images、pdf_files、crawl_errors）以及 Milvus 的 `tile_image_vector` 向量集合。

### 5. 安装 Playwright 浏览器（本地开发）

如果是在本地直接运行而非 Docker：

```bash
playwright install chromium
```

### 6. 手动采集数据

```bash
# 采集指定品牌
python scheduler/daily_update.py --brand 罗斯福

# 采集指定品牌并走完完整管线
python scheduler/daily_update.py --brand 罗斯福 --pipeline

# 采集所有品牌
python scheduler/daily_update.py --all

# 仅处理待解析/结构化/向量化的数据（不重新采集）
python scheduler/daily_update.py --incremental

# 查看已配置品牌列表
python scheduler/daily_update.py --list
```

### 7. 启动 API 服务

```bash
# Docker 方式（已在 docker-compose up -d 时启动）
docker-compose up -d

# 本地开发方式
python -m uvicorn api.main:app --host 0.0.0.0 --port 8000
```

服务启动后访问 http://localhost:8000/docs 查看 Swagger API 文档。

## API 接口文档

| 方法 | 路径 | 说明 | 鉴权 |
| --- | --- | --- | --- |
| POST | `/api/search/image` | 以图搜图 — 上传瓷砖图片返回 Top-10 相似 SKU | 无 |
| GET | `/api/sku/{id}` | 获取指定 SKU 的详细信息（含图片列表） | 无 |
| GET | `/api/stats` | 统计面板 — 品牌数、SKU 数、图片数、向量化进度等 | 无 |
| GET | `/api/brands` | 获取所有品牌列表（含各品牌 SKU/系列数量） | 无 |
| GET | `/api/series?brand_id=` | 获取指定品牌下的所有系列 | 无 |
| POST | `/api/crawl/trigger` | 手动触发指定品牌的采集任务 | 无 |
| GET | `/api/crawl/status` | 查询最近采集任务的状态 | 无 |
| GET | `/api/health` | 系统健康检查 — MySQL/Milvus 连接状态 | 无 |

## 微信小程序对接说明

### 以图搜图接口

**接口**: `POST /api/search/image`

**请求格式**: `multipart/form-data`，字段名为 `image`，支持 JPEG/PNG/WebP 格式。

```bash
curl -X POST http://localhost:8000/api/search/image \
  -F "image=@tile_photo.jpg"
```

**响应格式**:

```json
{
  "results": [
    {
      "brand": "罗斯福",
      "series": "大理石系列",
      "sku_code": "LSF-8001",
      "product_name": "意大利灰 800x800",
      "score": 0.9532,
      "images": [
        "/app/images/rosaf/LSF-8001_01.jpg",
        "/app/images/rosaf/LSF-8001_02.jpg"
      ]
    }
  ],
  "query_time_ms": 156.7
}
```

`score` 为余弦相似度，取值范围 0~1，越接近 1 越相似。结果按 `score` 降序排列，默认返回 Top-10。

## 项目目录结构

```
tile_ai/
├── api/                          # FastAPI 接口层
│   ├── main.py                   # 应用入口与路由注册
│   └── schemas.py                # Pydantic 请求/响应模型定义
├── crawler/                      # 数据采集层
│   ├── base_spider.py            # Spider 基类（浏览器管理、图片/PDF下载、错误处理）
│   ├── image_downloader.py       # 图片下载器
│   ├── pdf_downloader.py         # PDF 下载器
│   └── gaoan/                    # 高安产区品牌蜘蛛
│       ├── rosaf.py              # 罗斯福陶瓷
│       ├── jintaiyuan.py         # 金泰源陶瓷
│       ├── huashuo.py            # 华硕陶瓷
│       └── ruiyang.py            # 瑞阳陶瓷
├── parser/                       # PDF 解析层
│   ├── mineru_parser.py          # MinerU API 解析器
│   └── output/                   # 解析结果输出目录（Markdown + JSON）
├── llm/                          # 大模型层
│   └── qwen_structurer.py        # Qwen 结构化信息提取
├── vector/                       # 向量化与向量库层
│   ├── clip_embedder.py          # OpenCLIP 图像编码器
│   ├── milvus_client.py          # Milvus 客户端封装
│   ├── init_collection.py        # Milvus 集合初始化脚本
│   └── ocr_recognizer.py         # OCR 识别辅助
├── db/                           # 数据库层
│   ├── models.py                 # SQLAlchemy ORM 模型
│   ├── mysql_client.py           # MySQL 客户端（连接池、CRUD、统计）
│   ├── init_db.py                # 数据库与向量集合初始化入口
│   └── init_db.sql               # MySQL DDL 建表语句
├── config/                       # 配置
│   └── settings.py               # Pydantic Settings（.env 自动加载）
├── scheduler/                    # 任务调度
│   ├── jobs.py                   # APScheduler 定时任务定义
│   └── daily_update.py           # 命令行工具（手动采集/增量更新）
├── .env.example                  # 环境变量模板
├── requirements.txt              # Python 依赖清单
├── Dockerfile                    # Docker 镜像构建文件
├── docker-compose.yml            # Docker Compose 多服务编排
└── README.md                     # 项目文档
```

## 添加新品牌

当需要接入新的瓷砖品牌时，按以下步骤操作：

### 1. 创建爬虫文件

在 `crawler/gaoan/` 目录下创建 `<品牌拼音>.py`（如 `crawler/gaoan/xinzhongyuan.py`），继承 `BaseSpider`：

```python
from crawler.base_spider import BaseSpider
from loguru import logger

class XinzhongyuanSpider(BaseSpider):
    """新中源陶瓷品牌爬虫"""

    def __init__(self):
        super().__init__(
            brand_name="新中源",
            website="https://www.xinzhongyuan.com",
            area="高安",
        )

    def crawl_products(self) -> list[dict]:
        """实现产品列表页爬取逻辑，返回标准化的 SKU 字典列表。"""
        # 实现细节略...
        pass
```

### 2. 注册到调度系统

在 `scheduler/jobs.py` 的 `BRANDS` 列表中添加：

```python
BRANDS = [
    # ... 已有品牌 ...
    {"name": "新中源", "module": "crawler.gaoan.xinzhongyuan", "class": "XinzhongyuanSpider"},
]
```

在 `scheduler/daily_update.py` 的 `BRAND_MAP` 中添加：

```python
BRAND_MAP = {
    # ... 已有品牌 ...
    "新中源": {"module": "crawler.gaoan.xinzhongyuan", "class": "XinzhongyuanSpider"},
}
```

注册完成后，新品牌将被自动纳入每日定时全量采集和命令行手动采集。

## 增量更新机制

系统设计了基于状态码的增量更新管线，避免每次都对全量数据重新处理：

- **PDF 解析状态** (`pdf_files.parse_status`): 0=未解析 → MinerU 解析 → 1=已解析 / 2=失败
- **图片向量化状态** (`images.vector_status`): 0=未处理 → OpenCLIP 编码 → 1=已向量化 / 2=失败

调度器每小时运行一次增量任务：
- **:00** — Qwen 结构化（处理 `parse_status=1` 的已解析 PDF）
- **:15** — 图片向量化（处理 `vector_status=0` 的未处理图片）
- **:30** — PDF 解析（处理 `parse_status=0` 的未解析 PDF）

每日凌晨 2:00 执行全量采集 → 解析 → 结构化 → 向量化的完整管线。

## 日志系统

项目使用 `loguru` 作为日志框架。日志配置如下：

- **Docker 部署**: 日志文件输出到 `./logs/` 目录（通过 volume 挂载到宿主机）
- **本地开发**: 日志同时输出到终端（彩色）和 `logs/` 文件
- **MySQL 错误日志**: 爬虫和处理的异常会持久化到 `crawl_errors` 表，支持按品牌、任务类型、时间筛选
- **日志级别**: 通过 `.env` 中 `LOG_LEVEL` 环境变量控制（DEBUG / INFO / WARNING / ERROR）

## 常见问题 FAQ

### Q: 启动 Milvus 失败，日志显示 "etcd 连接超时"

Milvus standalone 模式依赖 etcd 和 MinIO，需要等待三个服务都健康后才会启动。首次启动可能需要 2-3 分钟。使用 `docker-compose ps` 确认所有容器状态为 `healthy`。

### Q: 爬虫执行时报 "Browser closed unexpectedly"

Playwright 需要安装 Chromium 浏览器和系统依赖。在 Docker 中已通过 Dockerfile 预装。本地开发时运行：

```bash
playwright install --with-deps chromium
```

### Q: 向量搜索返回结果为空

排查步骤：
1. 确认已执行 `python db/init_db.py` 初始化 Milvus 集合
2. 确认已有图片完成向量化（检查 `images` 表中 `vector_status=1` 的记录）
3. 使用 `GET /api/health` 确认 Milvus 连接正常

### Q: Qwen 结构化结果不准确

Qwen 结构化的效果依赖于 PDF 解析质量。如果 MinerU 提取的 Markdown 内容不完整，可以：
1. 检查 `parser/output/<品牌>/<PDF名>/markdown.md` 文件内容
2. 调整 `crawler/base_spider.py` 中的爬虫策略，确保下载到完整的 PDF 文件
3. 如果 MinerU 服务不可用，可考虑改用 MinerU 本地部署方案

### Q: 如何修改定时采集时间？

编辑 `scheduler/jobs.py` 中的 `start_scheduler()` 函数，修改 `CronTrigger` 参数：

```python
# 改为每天凌晨 3:30 全量更新
CronTrigger(hour=3, minute=30)

# 改为每 2 小时解析一次
CronTrigger(hour="*/2")
```

### Q: 如何导出采集的 SKU 数据？

查询 MySQL 数据库：

```sql
-- 导出所有 SKU
SELECT b.name AS 品牌, s.series_name AS 系列, sk.sku_code AS SKU编码,
       sk.product_name AS 产品名称, sk.size AS 规格, sk.surface AS 工艺,
       sk.color AS 颜色, sk.material AS 材质
FROM skus sk
JOIN brands b ON sk.brand_id = b.id
LEFT JOIN series s ON sk.series_id = s.id
ORDER BY b.name, s.series_name;
```

### Q: 系统支持哪些图片格式？

以图搜图接口接受 JPEG、PNG、WebP 格式。建议上传清晰的瓷砖产品正面照片，尺寸无严格限制，OpenCLIP 会自动缩放到 224x224 进行特征提取。