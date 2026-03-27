# 移动端分析报告

> 审查日期：2026-03-26
> 审查范围：`tan_rss_mobile/lib/` 全部 32 个 Dart 源文件

---

## 严重问题 (Critical)

| # | 问题 | 位置 | 状态 |
|---|------|------|------|
| 1 | `SearchResult` 类重复定义 — `models.dart` 和 `feed_repository.dart` 各定义一次，导入歧义 | `models.dart:501`, `feed_repository.dart:1042` | 待修复 |
| 2 | `path_provider` 依赖缺失 — `opml_settings_screen.dart` 导入但 `pubspec.yaml` 未声明，编译报错 | `opml_settings_screen.dart:5` | 待修复 |
| 3 | 默认 API 地址硬编码私有 IP `10.45.1.180:27496` | `api_client.dart:7` | 待修复 |

## 高优先级缺陷

| # | 问题 | 位置 | 状态 |
|---|------|------|------|
| 4 | `colorSchemeStyle` 设置保存但从未生效 | `appearance_settings_screen.dart:147-189` | 待修复 |
| 5 | 搜索结果不可点击 — `onTap` 空实现 | `discovery_screen.dart:665` | 待修复 |
| 6 | 频道未读数永远为 0 — 硬编码 `unread = 0` | `feeds_screen.dart:310` | 待修复 |
| 7 | 无 Token 刷新机制 — JWT 过期必须重新登录 | 整体架构 | 待开发 |
| 8 | 错误信息中英混杂 — UI 中文但 repository 错误提示英文 | `feed_repository.dart` 多处 | 待修复 |

## 未开发 / Stub 功能

| 功能 | 状态 | 位置 |
|------|------|------|
| 语言设置 (App语言/AI生成语言/翻译语言) | 3 个 TODO，全部 "Coming Soon" | `language_settings_screen.dart:27,39,51` |
| 高亮设置 | Stub | `settings_screen.dart:139` |
| TTS 朗读 | Stub | `settings_screen.dart:145`, `channel_synthesis_screen.dart:213` |
| 会员升级按钮 | TODO 无跳转 | `ai_settings_screen.dart:354` |
| 分享频道 | 显示"已复制"但未调用 clipboard | `channel_square_screen.dart:1481` |

## 后端 API 未对接

| 模块 | 可用端点 | 建议优先级 |
|------|----------|-----------|
| 图标系统 | `/api/icons`, `/api/icons/proxy` | 中 |
| RSSHub 管理 | `/api/rsshub/configs` 等 | 低 |
| 标签管理 | `/api/admin/tags` CRUD | 中 |
| 分类管理 | `/api/admin/categories` CRUD | 中 |
| 健康检查 | `/api/health` | 高 |
| 定时任务管理 | `/api/tasks/{id}/toggle` 等 | 低 |
| 收藏统计 | `/api/entries/starred/stats` | 中 |

## 代码质量问题

| 问题 | 位置 |
|------|------|
| `EntryDetailScreen` 和 `StarredScreen` 各有两份定义（死代码） | `home_shell_screen.dart:213,308` |
| about 页写着 "Dart 后端"，实际后端是 Python/FastAPI | `about_screen.dart:74` |
| 版本号 `v1.0.0` 硬编码 | `about_screen.dart:39` |
| 提供商列表、模型名、价格等多处硬编码 | `ai_settings_screen.dart`, `membership_screen.dart` |
| `_loadMore()` catch 静默吞掉错误 | `feed_list_screen.dart:145` |

## 开发优先级

1. 修复编译问题 — 添加 `path_provider` 依赖、清理重复类定义
2. 修复 `colorSchemeStyle` 未生效
3. 实现搜索结果跳转
4. 接入 favicon API
5. 实现语言设置
6. 添加服务器健康检查
7. Token 刷新机制
8. 频道未读数同步
9. **i18n 国际化模块** — 见下方详细规划

---

## i18n 国际化模块规划

### 现状

- 所有 UI 文案硬编码为中文，散布在 32 个 Dart 文件中
- 无 Flutter 国际化框架（无 `flutter_localizations`、无 ARB 文件、无 `localizationsDelegates`）
- `language_settings_screen.dart` 完全 stub（3 个 TODO）
- `MaterialApp` 未配置 `supportedLocales` / `localeResolutionCallback`
- `timeago` 已注册中文 locale，但硬编码 `locale: 'zh'`

### 实现方案

| 阶段 | 内容 | 产出 |
|------|------|------|
| **1. 基础设施** | 引入 `flutter_localizations` + `intl`；配置 `l10n.yaml`；生成 ARB 模板 | `lib/l10n/app_zh.arb`、`app_en.arb` |
| **2. 提取文案** | 逐文件将硬编码中文替换为 `S.of(context).xxx` 调用；覆盖全部 32 个文件 | ~300+ key |
| **3. 语言切换** | 实现 `language_settings_screen.dart` 的应用语言选择；`MaterialApp` 添加 `locale` / `localeResolutionCallback`；SharedPreferences 持久化 | 运行时切换 |
| **4. AI 语言配置** | 独立于 UI 语言的 AI 生成语言 / 翻译语言设置；读写 SharedPreferences 并传递给后端 API | 设置页可用 |
| **5. timeago 适配** | 根据当前 locale 动态选择 `timeago` locale，移除硬编码 `'zh'` | 多语言时间格式 |

### 支持语言

| 语言 | Locale | 优先级 |
|------|--------|--------|
| 简体中文 | `zh` | P0（默认） |
| English | `en` | P0 |
| 繁体中文 | `zh_TW` | P1 |
| 日本語 | `ja` | P2 |

### 涉及文件（估算）

- 新增：`l10n.yaml`、`lib/l10n/` 目录（ARB 文件 + 生成代码）
- 修改：`pubspec.yaml`（依赖）、`main.dart`（locale 配置）、`language_settings_screen.dart`（完整重写）、`feed_providers.dart`（locale provider）、以及所有 32 个含硬编码文案的 Dart 文件

---

## 开发日志

| 日期 | 任务 | 状态 |
|------|------|------|
| 2026-03-26 | 编写分析报告 | ✅ 完成 |
| 2026-03-26 | 添加 `path_provider` 依赖 | ✅ 完成 |
| 2026-03-26 | 清理重复 `SearchResult` 类 | ✅ 完成 |
| 2026-03-26 | 修复 `colorSchemeStyle` 未生效 (HSL色相变换方案) | ✅ 完成 |
| 2026-03-26 | 实现搜索结果跳转到文章详情 | ✅ 完成 |
| 2026-03-26 | 默认 API 地址改为 `localhost` 占位符 | ✅ 完成 |
| 2026-03-26 | 52条英文错误信息统一为中文 | ✅ 完成 |
| 2026-03-26 | 修复 about 页 "Dart 后端" 为 "Python FastAPI 后端" | ✅ 完成 |
| 2026-03-26 | 清理 home_shell 中死代码 (stub EntryDetailScreen) | ✅ 完成 |
| 2026-03-26 | i18n Stage 1: 基础设施 — `l10n.yaml` + `app_zh.arb`(480+ key) + `app_en.arb` + pubspec 配置 | ✅ 完成 |
| 2026-03-26 | i18n Stage 2: ARB 文件覆盖全部屏幕文案 (about/login/feed/discovery/channel/settings/AI/membership/opml/admin/user) | ✅ 完成 |
| 2026-03-26 | i18n Stage 3: `LocaleNotifier` + MaterialApp `localizationsDelegates`/`supportedLocales`/`locale` 配置 | ✅ 完成 |
| 2026-03-26 | i18n Stage 4: `language_settings_screen.dart` 完整重写 — 应用语言/AI语言/翻译语言三栏可选 | ✅ 完成 |
| 2026-03-26 | i18n Stage 5: `TimeHelper` 工具类 + timeago 7 语言 locale 注册 (zh/en/ja/ko/fr/de/es) | ✅ 完成 |
| — | 接入 favicon API | 🔲 待开发 |
| — | Token 刷新机制 | 🔲 待开发 |
| — | 频道未读数同步 | 🔲 待开发 |
| — | 运行 `flutter pub get && flutter gen-l10n` 生成本地化代码 | 🔲 用户操作 |
| — | 逐文件替换硬编码文案为 `S.of(context).xxx` (32 个文件) | 🔲 待开发 |
