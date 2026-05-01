# My Fork Notes

Fork from: [deckerst/aves](https://github.com/deckerst/aves)

## Git Remote 配置

```
origin    git@github.com:chenkunqing/aves.git   (我的仓库)
upstream  git@github.com:deckerst/aves.git      (原作者仓库)
```

## 常用操作

### 推送改动到我的仓库

```bash
git push origin <分支名>
```

### 同步原作者的更新

```bash
git fetch upstream
git merge upstream/main
```

### 提交并推送改动（完整流程）

```bash
# 1. 查看改动了哪些文件
git status

# 2. 暂存改动的文件（指定文件名，或用 . 暂存全部）
git add <文件名>

# 3. 创建提交
git commit -m "提交说明"

# 4. 推送到我的仓库
git push origin <分支名>
```

> 也可以直接告诉 Claude："帮我提交并推送到我的仓库"，会自动完成上述流程。

### 查看远程仓库配置

```bash
git remote -v
```

## 开发环境搭建

### 前置条件


| 工具          | 说明                                                        |
| ----------- | --------------------------------------------------------- |
| Git         | 用于管理代码和拉取 Flutter SDK 子模块                                 |
| Android SDK | 路径：`D:\Android\Sdk`，环境变量 `ANDROID_HOME` 指向该目录             |
| JDK 17      | 路径：`C:\Program Files\Zulu\zulu-17`，环境变量 `JAVA_HOME` 指向该目录 |


### 首次克隆项目（推荐）

```bash
git clone --recursive git@github.com:deckerst/aves.git
```

`--recursive` 会自动拉取 `.flutter/` 子模块（即项目内嵌的 Flutter SDK），无需全局安装 Flutter。

### 如果是下载 ZIP 解压的项目

ZIP 不包含 `.git` 目录和子模块内容，需要手动补上：

```bash
cd e:\DevProjects\10_photo_album
git init
git remote add origin git@github.com:deckerst/aves.git
git fetch origin
git checkout -f -b main origin/main
git submodule update --init
```

### 应用构建 flavor（构建版本）

这个项目可以打包成不同的版本（称为 flavor），区别在于是否依赖 Google 服务：


| Flavor    | 说明                          | 适用场景               |
| --------- | --------------------------- | ------------------ |
| **libre** | 纯开源版，不需要任何 Google 配置        | **日常开发用这个就行**      |
| play      | Google Play 版，需要配置 Firebase | 发布到 Google Play 商店 |
| izzy      | IzzyOnDroid 版               | 发布到 IzzyOnDroid 平台 |


切换 flavor 只需执行一次对应的脚本，它会自动修改 `pubspec.yaml` 中的依赖并重新下载包。

**如何执行：**

PowerShell 不支持直接运行 `.sh` 脚本，有以下三种方式：

```powershell
# 方式一：在 VS Code 终端中，点右上角下拉箭头 → 选择 "Git Bash"，然后输入：
./scripts/apply_flavor_libre.sh

# 方式二：在 PowerShell 中用 Git 自带的 bash 来执行：
& "C:\Program Files\Git\bin\bash.exe" scripts/apply_flavor_libre.sh

# 方式三：让 Claude 代为执行（直接说"帮我执行 apply_flavor_libre"即可）
```

### 检查环境

```powershell
# PowerShell 中使用
.\.flutter\bin\flutter doctor
```

```bash
# Git Bash 中使用
./flutterw doctor
```

确保输出中 Android toolchain 显示 `√`。如果提示 license 未接受：

```powershell
.\.flutter\bin\flutter doctor --android-licenses
```

## 运行项目

### 1. 连接 Android 设备

二选一：

- **真机**：手机通过 USB 连接电脑 → 手机设置 → 开发者选项 → 打开"USB 调试"
- **模拟器**：通过 Android Studio 的 AVD Manager 创建并启动一个 Android 模拟器

### 2. 检查设备是否已连接

```powershell
# PowerShell
.\.flutter\bin\flutter devices
```

```bash
# Git Bash
./flutterw devices
```

看到设备列表中有你的手机或模拟器即可。

### 3. 运行应用

```powershell
# PowerShell（libre 版本，连接 MuMu 模拟器）
.\.flutter\bin\flutter run --flavor libre -t lib/main_libre.dart
```

```bash
# Git Bash（libre 版本，连接 MuMu 模拟器）
./flutterw run --flavor libre -t lib/main_libre.dart
```

> 首次编译较慢（约 5 分钟），后续使用 hot reload 秒级生效。

### 4. 连接 MuMu 模拟器

```bash
adb connect 127.0.0.1:7555
```

### 5. 与 Claude 协作开发的热更新流程

1. **你先开一个终端**，运行 `flutter run`（上面的命令），保持它一直运行
2. 告诉 Claude 要改什么功能
3. Claude 改好代码后会说"改好了"
4. **你在终端里按 `r`**（hot reload）或 `R`（hot restart）即可看到效果

> 不需要每次都重新编译安装，按 `r` 就是秒级更新。
> 如果 hot reload 不生效（比如改了 native 代码），按 `R` 做 hot restart。
> 如果连 hot restart 也不行，按 `q` 退出后重新 `flutter run`。

### 关于 flutterw 和 flutter 的区别

- `flutterw` 是项目自带的 bash 脚本（见项目根目录 `flutterw` 文件），它会自动使用项目内 `.flutter/` 子模块中的 Flutter SDK
- `.flutter\bin\flutter` 是直接调用子模块中的 Flutter 二进制文件
- 两者效果相同，只是 `flutterw` 是 bash 脚本，不能在 PowerShell 中直接运行
- **不需要全局安装 Flutter SDK**，项目自带了

## 打包安装包

```bash
flutter build apk --flavor libre --release --split-per-abi
```

打完后装机包在 `build/app/outputs/flutter-apk/app-libre-arm64-v8a-release.apk`。

> 以后跟 Claude 说"打个安装包"就行。

## 功能更新记录

| 日期         | 类型   | 更新内容                                     |
| ---------- | ---- | ---------------------------------------- |
| 2026-04-29 | 新增功能 | 候选篮功能（长按选图、底栏展示、批量操作）                    |
| 2026-04-29 | 新增功能 | 打印尺寸显示（图片详情页展示实际打印尺寸）                    |
| 2026-04-29 | 功能优化 | 宽高比筛选增强（预设常用比例 + 自定义比例输入）                 |
| 2026-04-29 | 功能优化 | 信息页元数据目录默认隐藏，点击按钮展开                       |
| 2026-04-29 | 功能优化 | 图片浏览底部工具栏样式更新，固定布局：分享/收藏/整理/删除/更多         |
| 2026-04-29 | 功能优化 | 导航栏菜单设置页面可见性图标改为 Switch 开关，状态更直观           |
| 2026-04-29 | 功能优化 | 宽高比筛选排序调整，横向、纵向、XPAN、自定义优先显示              |
| 2026-04-29 | 修改bug | 修复相册删除需要两次才能清除干净的问题                        |
| 2026-04-29 | 新增功能 | 相册长按多选删除，支持系统层面永久删除相册目录及所有文件               |
| 2026-04-29 | 新增功能 | 地图多瓦片源支持与自动切换（高德国内、ArcGIS全球），根据GPS坐标自动选择  |
| 2026-04-30 | 新增功能 | 人脸识别与人物分组，自动检测人脸、提取特征向量、聚类分组，侧边栏"人物"页面    |
| 2026-04-30 | 功能优化 | 人脸检测准确性提升，增加 landmark 和分类校验过滤误检            |
| 2026-04-30 | 修改bug | 修复人脸 embedding 保存并增加模型版本化                  |
| 2026-04-30 | 功能优化 | 移除整理模式上滑删除时的红色背景遮罩，简化删除视觉反馈               |
| 2026-04-30 | 修改bug | 整理模式：上滑删除或剪切到文件夹后，左右滑动跳过已处理的照片            |
| 2026-05-01 | 功能优化 | 移除保险箱(Vault)功能全部残留代码，精简代码体积                 |
| 2026-05-02 | 修改bug | 整理模式完成后返回查看器时不再闪现已删除照片                    |
| 2026-05-02 | 功能优化 | 清理数据库升级脚本中 vaults 表残留迁移代码                    |
| 2026-05-02 | 功能优化 | 重构数据源层，合并 Location mixin、拆分 DB 仓库、提取 EntryCache |
| 2026-05-02 | 功能优化 | 提取 AnalysisStep 配置类，统一分析步骤执行逻辑              |
| 2026-05-02 | 功能优化 | 整理模式：已收藏照片再次下滑收藏时保持收藏状态且不离开当前卡片    |

