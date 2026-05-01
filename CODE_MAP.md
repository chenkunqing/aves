# Code Map — Aves Photo Album

基于 [aves](https://github.com/deckerst/aves) 的 Flutter 照片相册应用，Android 平台。

---

## 项目入口

| 文件 | 说明 |
|------|------|
| `lib/main_libre.dart` | Libre flavor 入口（日常开发用） |
| `lib/main_play.dart` | Google Play flavor 入口 |
| `lib/main_izzy.dart` | IzzyOnDroid flavor 入口 |
| `lib/main_common.dart` | 各 flavor 共享的初始化逻辑 |
| `lib/app_flavor.dart` | Flavor 枚举定义 |
| `lib/app_mode.dart` | 应用模式（正常、屏保、壁纸等） |
| `lib/widgets/aves_app.dart` | MaterialApp 根 Widget，路由注册 |

---

## lib/ 目录结构

```
lib/
├── model/          数据模型层
├── services/       平台通道 & 业务服务层
├── widgets/        UI 组件层（最大模块）
├── view/           视图枚举、格式化辅助
├── convert/        数据转换（日期字段来源等）
├── ref/            静态参考数据（MIME、EXIF、语言等）
├── theme/          颜色、图标、字体、主题
├── utils/          通用工具函数
├── geo/            地理位置
├── image_providers/ 图片加载 provider
├── l10n/           国际化资源 (ARB)
└── l10ngen/        生成的国际化代码
```

---

## Model 层 (`lib/model/`)

### 核心实体
| 路径 | 说明 |
|------|------|
| `model/entry/entry.dart` | **AvesEntry** — 照片/视频条目，核心数据对象 |
| `model/entry/extensions/` | Entry 扩展：catalog、favourites、images、location、props 等 |
| `model/entry/sort.dart` | 条目排序逻辑 |
| `model/person.dart` | Person 人物模型 |
| `model/face_embedding.dart` | 人脸 embedding 数据行模型 |
| `model/face_clustering.dart` | 人脸聚类工具（余弦相似度计算） |
| `model/entry_faces.dart` | 条目-人脸关联 |

### 筛选器 (Filters)
| 路径 | 说明 |
|------|------|
| `model/filters/filters.dart` | CollectionFilter 基类 |
| `model/filters/aspect_ratio.dart` | 宽高比筛选 |
| `model/filters/color.dart` | 颜色筛选 |
| `model/filters/coordinate.dart` | 地理坐标筛选 |
| `model/filters/date.dart` | 日期筛选 |
| `model/filters/face_count.dart` | 人脸数量筛选（合影/单人/无人脸） |
| `model/filters/favourite.dart` | 收藏筛选 |
| `model/filters/mime.dart` | MIME 类型筛选 |
| `model/filters/missing.dart` | 缺失元数据筛选 |
| `model/filters/path.dart` | 路径筛选 |
| `model/filters/person.dart` | 人物筛选 |
| `model/filters/placeholder.dart` | 占位筛选 |
| `model/filters/query.dart` | 搜索查询筛选 |
| `model/filters/rating.dart` | 评分筛选 |
| `model/filters/recent.dart` | 最近添加筛选 |
| `model/filters/trash.dart` | 回收站筛选 |
| `model/filters/type.dart` | 类型筛选（图片/视频等） |
| `model/filters/weekday.dart` | 星期筛选 |
| `model/filters/covered/stored_album.dart` | 相册筛选 |
| `model/filters/covered/tag.dart` | 标签筛选 |
| `model/filters/container/` | 复合筛选 (AND/OR/Group) |

### 数据源 (Source)
| 路径 | 说明 |
|------|------|
| `model/source/collection_source.dart` | **CollectionSource** — 所有条目的中央数据源 |
| `model/source/collection_lens.dart` | **CollectionLens** — 带筛选/排序的视图 |
| `model/source/media_store_source.dart` | 从 Android MediaStore 加载数据 |
| `model/source/album.dart` | 相册管理 |
| `model/source/analysis_controller.dart` | 分析流程控制器 |
| `model/source/events.dart` | 数据源事件定义 |
| `model/source/face.dart` | 人脸数据源 |
| `model/source/person.dart` | 人物数据源 |
| `model/source/section_keys.dart` | 分段键（分组排序标识） |
| `model/source/tag.dart` | 标签数据源 |
| `model/source/trash.dart` | 回收站数据源 |
| `model/source/location/` | 位置分级（国家/省/地点） |

### 数据库
| 路径 | 说明 |
|------|------|
| `model/db/db.dart` | 数据库抽象接口 |
| `model/db/db_sqflite.dart` | SQLite 实现 |
| `model/db/db_sqflite_schema.dart` | 表结构定义 |
| `model/db/db_sqflite_upgrade.dart` | 数据库迁移 |

### 设置
| 路径 | 说明 |
|------|------|
| `model/settings/settings.dart` | Settings 单例 |
| `model/settings/modules/` | 按功能分模块的设置项 |
| `model/settings/enums/` | 设置枚举值 |

### 自定义功能模型
| 路径 | 说明 |
|------|------|
| `model/candidate_basket.dart` | 候选篮模型 |
| `model/organize_basket.dart` | 整理模式篮子 |
| `model/selection.dart` | 多选状态管理 |
| `model/favourites.dart` | 收藏管理 |
| `model/covers.dart` | 封面管理 |
| `model/dynamic_albums.dart` | 动态相册 |
| `model/highlight.dart` | 高亮/聚焦条目 |

---

## Services 层 (`lib/services/`)

| 路径 | 说明 |
|------|------|
| `services/common/services.dart` | 服务注册中心 |
| `services/common/channel.dart` | Platform Channel 基础封装 |
| `services/face_detection_service.dart` | 人脸检测服务（调用 Android 原生） |
| `services/analysis_service.dart` | 媒体分析服务（扫描元数据） |
| `services/media/media_fetch_service.dart` | 媒体获取 |
| `services/media/media_edit_service.dart` | 媒体编辑 |
| `services/media/media_store_service.dart` | MediaStore 操作 |
| `services/metadata/metadata_fetch_service.dart` | 元数据读取 |
| `services/metadata/metadata_edit_service.dart` | 元数据编辑 |
| `services/geocoding_service.dart` | 地理编码 |
| `services/storage_service.dart` | 存储管理 |
| `services/intent_service.dart` | Intent 处理（分享等） |

---

## Widgets 层 (`lib/widgets/`)

### 顶层页面
| 路径 | 说明 |
|------|------|
| `widgets/aves_app.dart` | App 根 Widget，路由 |
| `widgets/home/home_page.dart` | 首页（含 Drawer） |
| `widgets/welcome_page.dart` | 欢迎/权限引导页 |

### 图片浏览集合 (`widgets/collection/`)
| 路径 | 说明 |
|------|------|
| `collection/collection_page.dart` | 图片集合主页面 |
| `collection/collection_grid.dart` | 网格视图 |
| `collection/app_bar.dart` | 集合页 AppBar（搜索、筛选等） |
| `collection/filter_bar.dart` | 筛选条（Chip 行） |
| `collection/candidate_basket_bar.dart` | 候选篮 Bar |
| `collection/entry_set_action_delegate.dart` | 批量操作代理 |
| `collection/grid/` | 网格布局细节（section、tile、headers） |

### 图片查看器 (`widgets/viewer/`)
| 路径 | 说明 |
|------|------|
| `viewer/entry_viewer_page.dart` | 查看器主页面 |
| `viewer/entry_viewer_stack.dart` | 查看器 Stack 布局 |
| `viewer/entry_horizontal_pager.dart` | 水平翻页 |
| `viewer/organize_page.dart` | 整理模式页面 |
| `viewer/overlay/top.dart` | 顶部 Overlay（AppBar） |
| `viewer/overlay/bottom.dart` | 底部 Overlay |
| `viewer/overlay/details/` | 详情区（日期、位置、拍摄参数等） |
| `viewer/overlay/video/` | 视频控件 |
| `viewer/info/info_page.dart` | 信息面板页 |
| `viewer/action/entry_action_delegate.dart` | 单图操作代理 |
| `viewer/action/printer.dart` | 打印功能 |
| `viewer/visual/` | 图片/视频渲染 |
| `viewer/organize/` | 整理模式 UI（卡片堆叠、缩放预览） |

### 筛选网格 (`widgets/filter_grids/`)
| 路径 | 说明 |
|------|------|
| `filter_grids/albums_page.dart` | 相册列表页 |
| `filter_grids/tags_page.dart` | 标签列表页 |
| `filter_grids/states_page.dart` | 省/州列表页 |
| `filter_grids/countries_page.dart` | 国家列表 |
| `filter_grids/places_page.dart` | 地点列表 |
| `filter_grids/common/` | 通用筛选网格组件 |

### 导航 (`widgets/navigation/`)
| 路径 | 说明 |
|------|------|
| `navigation/drawer/app_drawer.dart` | 侧边栏 Drawer |
| `navigation/drawer/page_nav_tile.dart` | Drawer 导航项 |
| `navigation/nav_bar/nav_bar.dart` | 底部导航栏 |

### 设置 (`widgets/settings/`)
| 路径 | 说明 |
|------|------|
| `settings/settings_page.dart` | 设置主页 |
| `settings/settings_definition.dart` | 设置项定义 |
| `settings/navigation/` | 导航相关设置（Drawer 编辑等） |
| `settings/display/` | 显示设置 |
| `settings/viewer/` | 查看器设置 |
| `settings/video/` | 视频设置 |
| `settings/thumbnails/` | 缩略图设置 |

### 对话框 (`widgets/dialogs/`)
| 路径 | 说明 |
|------|------|
| `dialogs/filter_editors/custom_aspect_ratio_dialog.dart` | 自定义宽高比对话框 |
| `dialogs/entry_editors/` | 条目编辑对话框（日期、描述、位置、标签等） |
| `dialogs/pick_dialogs/` | 选择器（相册、标签、位置等） |

### 通用组件 (`widgets/common/`)
| 路径 | 说明 |
|------|------|
| `common/action_controls/` | 操作按钮/快捷选择器 |
| `common/action_mixins/` | 操作 Mixin（删除、移动、分享等） |
| `common/grid/` | 网格通用布局 |
| `common/thumbnail/` | 缩略图组件 |
| `common/map/` | 地图组件 |
| `common/search/` | 搜索组件 |

---

## Android 原生层 (`android/`)

路径前缀：`android/app/src/main/kotlin/deckers/thibault/aves/`

### 入口 & 服务
| 路径 | 说明 |
|------|------|
| `MainActivity.kt` | 主 Activity，注册 Method/Event Channel |
| `AnalysisWorker.kt` | 后台分析 Worker |
| `MediaPlaybackService.kt` | 媒体播放服务 |

### Platform Channel Handlers (`channel/calls/`)
| 路径 | 说明 |
|------|------|
| `FaceDetectionHandler.kt` | 人脸检测（TFLite 模型） |
| `MediaStoreHandler.kt` | MediaStore 查询 |
| `MediaEditHandler.kt` | 媒体编辑操作 |
| `MetadataFetchHandler.kt` | 元数据读取 |
| `StorageHandler.kt` | 存储操作 |
| `AnalysisHandler.kt` | 分析控制 |

### 模型 (`model/`)
| 路径 | 说明 |
|------|------|
| `model/AvesEntry.kt` | 原生 Entry 模型 |
| `model/provider/MediaStoreImageProvider.kt` | MediaStore 图片提供者 |

### 元数据 (`metadata/`)
| 路径 | 说明 |
|------|------|
| `metadata/Metadata.kt` | 元数据提取主逻辑 |
| `metadata/xmp/XMP.kt` | XMP 处理 |

---

## 插件 (`plugins/`)

| 插件 | 说明 |
|------|------|
| `aves_magnifier` | 图片缩放查看器 |
| `aves_map` | 地图组件 |
| `aves_model` | 共享数据模型 |
| `aves_services` / `aves_services_google` / `aves_services_none` | 服务抽象（Google/无服务） |
| `aves_video` / `aves_video_exo` | 视频播放（ExoPlayer） |
| `aves_ui` | UI 通用组件 |
| `aves_utils` | 工具函数 |
| `aves_report` / `aves_report_console` / `aves_report_crashlytics` | 日志/崩溃上报 |
| `aves_screen_state` | 屏幕状态 |

---

## 其他关键文件

| 路径 | 说明 |
|------|------|
| `lib/view/view.dart` | 导出所有 view 层枚举/辅助 |
| `lib/theme/icons.dart` | 自定义图标常量 |
| `lib/theme/themes.dart` | 明暗主题定义 |
| `pubspec.yaml` | 依赖声明（Flutter 3.41.8） |
| `l10n.yaml` | 国际化配置 |
| `lib/l10n/app_en.arb` | 英文翻译源文件 |
| `scripts/` | 构建/辅助脚本 |
| `CHANGELOG.md` | 版本更新日志 |
| `MY_README.md` | 自定义功能记录 |

---

## 数据流概览

```
Android MediaStore / 文件系统
        ↓ (Platform Channel)
    Services 层 (Dart)
        ↓
    CollectionSource → 保存到 SQLite DB
        ↓
    CollectionLens (筛选/排序/分组)
        ↓
    Widgets (Collection Grid / Viewer / Filter Grids)
```

## 人脸检测流程

```
图片 → FaceDetectionService (TFLite SSD) → 人脸坐标 & 数量
     → FaceEmbeddingRow (数据存储)
     → FaceClustering (余弦相似度) → Person 分组
     → PersonSource → UI 展示
```

> 注：本地人脸识别（MobileFaceNet embedding 提取）已移除，仅保留人脸检测和基于已有 embedding 的聚类。
