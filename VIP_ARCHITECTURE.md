# 用户级AI配置分离与会员体系架构文档

## 1. 核心重构目标与实现方案
为支持未来的商业化运营，本项目对后端的 AI 配置和调用架构进行了深度重构，实现了“平台/系统”配置与“用户个人”配置的分离，并引入了多层级会员系统。

### 1.1 架构设计
- **混合回退机制**：AI服务调用核心 (`_call_ai`, `_call_embedding`) 现在接受动态的 `config` 字典，而非原先写死的全局 `AI_CFG`。
- **权限与配额拦截**：每次调用 AI 接口前，系统会通过 `get_user_ai_context` 方法进行鉴权：
  1. 检查用户是否配置了个人 API Key（BYOK - Bring Your Own Key）。
  2. 检查用户的会员等级 (`free`, `plus`, `pro`)。
  3. 如果用户是 Plus/Pro 会员且没有配置个人 Key，系统允许其回退使用平台配置（`id="default"`），并记录今日调用次数（在 `UserUsage` 表中统计 `ai_calls`）。
  4. 如果用户是 Free 会员且未配置个人 Key，直接拒绝请求（HTTP 403）。

## 2. 数据库设计 (Database Schema)
新增了以下 SQLAlchemy 模型以支持该体系（详见 `app/models.py`）：

### 2.1 会员状态 (`user_memberships`)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 主键 |
| user_id | String | 关联 `users.id`，唯一且建立索引 |
| tier | String | 会员等级，默认为 `free`，支持 `plus`, `pro` |
| expires_at | DateTime | 会员过期时间 |

### 2.2 使用统计 (`user_usages`)
用于记录会员使用平台 AI 服务的频次，便于后续实施调用限制。
| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 主键 (格式为 `{user_id}_{YYYY-MM-DD}`) |
| user_id | String | 关联 `users.id` |
| date_str | String | 日期字符串，建立索引 |
| ai_calls | Integer | 当日 AI 接口调用次数 |

### 2.3 自定义指令集 (`user_ai_prompts`)
支持用户创建、管理个性化 AI 指令（Plus 特权）。
| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 主键 |
| user_id | String | 关联 `users.id` |
| name | String | 指令名称 |
| prompt_type| String | 指令类型（如 `summary`, `translate` 等）|
| content | Text | 指令具体内容 |

### 2.4 用户 AI 配置复用 (`ai_configs`)
原有全局 `ai_configs` 表通过 `id` 字段区分平台配置（`id="default"`）与用户配置（`id="{user_id}"`）。

## 3. API 接口文档 (API Endpoints)

### 3.1 会员订阅模块 (Membership API)
- `GET /api/membership/status`
  - 功能：获取当前用户的会员状态、过期时间及今日已调用的平台 AI 次数。
  - 返回示例：`{"tier": "plus", "expires_at": "2024-12-31T00:00:00Z", "is_active": true, "today_ai_calls": 5}`
- `POST /api/membership/subscribe`
  - 功能：订阅或升级会员。
  - 请求体：`{"tier": "plus", "months": 1}`
  - 返回：成功状态及新的过期时间。

### 3.2 个人 AI 配置模块 (User AI Config API)
- `GET /api/ai/user/config`
  - 功能：获取当前用户的个人 AI 密钥及模型配置（如果为空，代表未配置）。
- `PUT /api/ai/user/config`
  - 功能：更新用户的个人 AI 配置（如填入自己的 API Key）。

### 3.3 自定义指令集模块 (Custom Prompts API)
- `GET /api/ai/prompts`：获取当前用户的所有自定义指令。
- `POST /api/ai/prompts`：创建新的自定义指令 (`name`, `prompt_type`, `content`)。
- `PUT /api/ai/prompts/{prompt_id}`：更新指令。
- `DELETE /api/ai/prompts/{prompt_id}`：删除指令。

## 4. 后续演进规划 (Pro 会员框架)
- **调用额度限制**：在 `get_user_ai_context` 处，可基于 `tier` (Plus / Pro) 定义硬性限制（如 Plus 每日 50 次，Pro 每日 500 次），超出后抛出 429 错误。
- **高级主题定制**：计划在前端 Flutter 工程及后端 `users` / `settings` 配置中增加 `theme_config` 字段。
- **商业化支付集成**：目前的 `/api/membership/subscribe` 预留了支付处理位，未来将接入 Stripe / 微信 / 支付宝等实际网关。
