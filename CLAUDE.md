# Project Rules

本文件是 Claude Code 的项目级指令，与 `AGENTS.md` 配合使用。

## MUST

- 修改代码前，先阅读 `CODE_MAP.md` 了解项目结构和文件定位，确保修改目标准确。
- 遵循 `AGENTS.md` 中的所有通用规则。
- 回复语言：中文。

## 开发环境

- Flutter 项目，Android 平台
- 构建 flavor：libre
- 构建目标：仅 arm64-v8a（不构建其他架构）
- 测试设备：MuMu 模拟器，支持 hot reload
- 构建命令参考：`flutter run --flavor libre -t lib/main_libre.dart`

## 提交规范

- 提交信息前缀：`新增功能`、`修改bug`、`功能优化`
- 提交到 master 时同步更新 `MY_README.md` 功能更新记录表格

## 项目关键文档

| 文件 | 说明 |
|------|------|
| `CODE_MAP.md` | 代码地图，模块定位索引 |
| `AGENTS.md` | 通用协作规则 |
| `MY_README.md` | 自定义功能更新记录 |
| `CHANGELOG.md` | 版本更新日志 |
