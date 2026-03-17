# ImageMixer 激活码后台设计

## 目标

面向 `ImageMixer` 桌面软件，提供一套可商用的授权后台，满足：

- 后台生成激活码
- 后台批量生成激活码
- 配置生效时间、失效时间、最大激活设备数
- 记录每台激活设备的详细信息
- 支持禁用激活码、踢设备、续期
- 客户端可离线运行，但首次激活和周期性续期需要联网
- 后台部署在 Linux 服务器，域名为 `mixer.douxing.cc`
- 尽量少占用内存，依赖简单，便于单机部署

## 技术选型

选择：`Go + SQLite + Caddy`

原因：

- Go 内存占用低，单二进制部署简单
- 标准库 + 少量依赖即可完成 API 和后台页面
- SQLite 适合单机后台，运维成本低，内存占用更小
- Caddy 自动处理 HTTPS 证书，适合 `mixer.douxing.cc`

不建议首版再额外引入 Redis、前后端分离管理台。你现在最需要的是能卖、能控、能追踪，不是大而全。

## 部署结构

```text
Internet
  |
  v
Caddy (HTTPS, mixer.douxing.cc)
  |
  v
imagemixer-license-server (Go)
  |
  v
SQLite (data/license.db)
```

建议目录：

```text
/opt/imagemixer-license/
  bin/license-server
  config/.env
  scripts/Caddyfile
  data/license.db
  logs/
  backups/
```

## 系统模块

后台拆成 3 个模块：

1. 管理后台
   - 管理员登录
   - 创建激活码
   - 批量生成激活码
   - 查询激活码
   - 查看设备列表
   - 禁用激活码
   - 踢掉某台设备
   - 延长有效期

2. 客户端授权接口
   - 激活
   - 刷新授权
   - 心跳上报
   - 查询授权状态

3. 授权签名模块
   - 服务端持有私钥
   - 客户端内置公钥
   - 激活成功后下发签名授权文件

## 授权模型

建议不要让客户端直接依赖“明文激活码是否有效”的在线查询，而是：

1. 用户输入激活码
2. 客户端请求服务端激活
3. 服务端验证激活码和设备信息
4. 服务端返回一个签名后的授权文件
5. 客户端本地保存授权文件
6. 日常运行只校验签名和过期时间
7. 每隔一段时间联网刷新授权状态

这样做的好处：

- 用户可离线使用
- 服务端可以做封禁、续期、换机
- 客户端不需要内置“正确激活码列表”

## 激活码规则

每个激活码建议包含这些属性：

- `code`
- `batch_no`
- `product_code`
- `edition`
- `status`
- `valid_from`
- `valid_until`
- `max_devices`
- `allow_rebind`
- `rebind_limit`
- `features`
- `customer_name`
- `customer_email`
- `note`

`status` 建议值：

- `draft`
- `active`
- `disabled`
- `expired`

`edition` 可以先做三档：

- `personal`
- `pro`
- `business`

## 设备记录

每次激活或心跳，服务端记录设备信息。

建议记录字段：

- `device_id`
- `license_id`
- `fingerprint_hash`
- `device_name`
- `os_name`
- `os_version`
- `cpu_arch`
- `app_version`
- `ip`
- `first_activated_at`
- `last_seen_at`
- `status`

`status` 建议值：

- `active`
- `revoked`
- `replaced`

## 设备指纹建议

客户端采集多个稳定字段，拼接后再做哈希：

- Windows MachineGuid
- 主板 UUID
- 系统盘卷序列号
- CPU 信息
- 主机名

建议：

- 客户端本地先做 `SHA-256`
- 服务端保存 `fingerprint_hash`
- 不要把过多原始硬件值明文落库

这样能减少隐私风险，也够用来做设备绑定。

## 数据表设计

建议统一使用：

- `SQLite 3`
- 打开 `WAL` 模式
- 打开 `foreign_keys = ON`
- 配置合理的 `busy_timeout`
- 时间字段统一存 UTC

ID 如果希望后续对外暴露更安全，建议：

- 数据库主键使用 `INTEGER PRIMARY KEY`
- 对外显示再增加业务 ID，例如 `lic_xxx`、`dev_xxx`

### admins

- `id`
- `username`
- `password_hash`
- `role`
- `created_at`
- `last_login_at`

### licenses

- `id`
- `code`
- `batch_no`
- `product_code`
- `edition`
- `status`
- `valid_from`
- `valid_until`
- `max_devices`
- `allow_rebind`
- `rebind_limit`
- `features_json`
- `customer_name`
- `customer_email`
- `note`
- `created_at`
- `updated_at`

### devices

- `id`
- `license_id`
- `device_name`
- `fingerprint_hash`
- `os_name`
- `os_version`
- `cpu_arch`
- `app_version`
- `ip`
- `status`
- `first_activated_at`
- `last_seen_at`

### activation_events

- `id`
- `license_id`
- `device_id`
- `event_type`
- `result`
- `message`
- `request_ip`
- `created_at`

### issued_licenses

- `id`
- `license_id`
- `device_id`
- `license_payload_json`
- `expires_at`
- `created_at`

### license_batches

- `id`
- `batch_no`
- `product_code`
- `edition`
- `quantity`
- `valid_from`
- `valid_until`
- `max_devices`
- `features_json`
- `customer_name`
- `customer_email`
- `note`
- `created_by`
- `created_at`

## SQLite 索引建议

首版至少加这些索引：

- `licenses.code` 唯一索引
- `licenses.batch_no` 索引
- `licenses.status, valid_until` 组合索引
- `devices.license_id, status` 组合索引
- `devices.fingerprint_hash` 索引
- `activation_events.license_id, created_at` 组合索引
- `activation_events.device_id, created_at` 组合索引
- `issued_licenses.license_id, device_id` 组合索引
- `license_batches.batch_no` 唯一索引

推荐字段类型：

- `code`: `TEXT`
- `edition`: `TEXT`
- `status`: `TEXT`
- `customer_name`: `TEXT`
- `customer_email`: `TEXT`
- `fingerprint_hash`: `TEXT`
- `ip`: `TEXT`
- `features_json`: `TEXT`
- `license_payload_json`: `TEXT`

## 管理后台功能

首版就做这些：

- 管理员登录
- 创建激活码
- 批量创建激活码
- 编辑有效期
- 编辑最大设备数
- 查看激活设备
- 撤销单台设备
- 禁用整个激活码
- 查看激活日志

管理台不建议单独再做一个前端项目。首版直接用 Go 服务端渲染 HTML 页面，依赖更少，内存更稳。

## 客户端接口设计

### 1. 激活

`POST /api/client/activate`

请求：

```json
{
  "code": "IMX-XXXX-XXXX-XXXX",
  "device_name": "DESKTOP-001",
  "fingerprint_hash": "sha256...",
  "os_name": "windows",
  "os_version": "11",
  "cpu_arch": "x86_64",
  "app_version": "1.0.0"
}
```

响应：

```json
{
  "ok": true,
  "license_file": {
    "license_id": "lic_123",
    "edition": "pro",
    "valid_until": "2027-12-31T23:59:59Z",
    "features": ["process", "batch", "future_feature"],
    "device_id": "dev_456",
    "signature": "base64..."
  }
}
```

### 2. 刷新授权

`POST /api/client/refresh`

用于续期、封禁同步、特性同步。

### 3. 心跳

`POST /api/client/heartbeat`

用于更新 `last_seen_at` 和客户端版本。

### 4. 查询状态

`GET /api/client/license-status`

用于客户端后台检查授权状态。

## 管理后台接口

建议统一走 `/api/admin/*`：

- `POST /api/admin/login`
- `GET /api/admin/licenses`
- `POST /api/admin/licenses`
- `POST /api/admin/licenses/batch-create`
- `GET /api/admin/license-batches`
- `PATCH /api/admin/licenses/{id}`
- `POST /api/admin/licenses/{id}/disable`
- `GET /api/admin/licenses/{id}/devices`
- `POST /api/admin/devices/{id}/revoke`
- `GET /api/admin/events`

## 激活流程

```text
用户购买
  ->
后台创建激活码
  ->
用户在客户端输入激活码
  ->
客户端采集设备指纹并请求激活
  ->
服务端校验激活码状态/有效期/设备数量
  ->
服务端落库设备信息
  ->
服务端签发授权文件
  ->
客户端本地保存授权文件
  ->
客户端启动时只验签 + 查过期时间
  ->
定期联网 refresh/heartbeat
```

## 签名方案

建议使用 `Ed25519`。

原因：

- 实现简单
- 签名短
- Go 标准库支持好
- 客户端校验逻辑轻量

规则：

- 服务端只保存私钥
- 客户端只内置公钥
- 授权文件必须验签通过才可使用

## 安全建议

- 激活码不要顺序递增，使用随机码
- 后台密码必须做哈希，推荐 `bcrypt` 或 `argon2id`
- 管理后台加登录限流
- 客户端不要内置“有效激活码列表”
- 后端核心功能接口也要检查授权，不只前端按钮置灰
- refresh 时支持封禁同步和设备踢下线

## 销售与运营建议

先做最小可卖版本：

- 每个订单后台手动创建激活码或批量生成激活码
- 手工设置客户名、有效期、设备数
- 付款成功后发激活码给客户

后续再接支付平台，不要首版就把支付、发码、开票全部打通。

## 推荐迭代顺序

### 第一阶段

- Go 服务端
- SQLite
- 管理员登录
- 激活码管理
- 设备绑定
- 签名授权文件
- 客户端激活接口

### 第二阶段

- 续期
- 设备踢下线
- 激活日志检索
- 邮件通知

### 第三阶段

- 支付回调自动发码
- 多产品线
- 渠道代理管理

## 与当前项目的集成建议

当前 `ImageMixer` 是 `Flutter 桌面端 + 本地 Python 后端 exe`。

建议授权校验这样放：

1. Flutter 启动时先校验本地授权文件
2. Python 后端启动时也校验本地授权文件
3. 核心处理接口执行前，再做一次授权检查

这样别人即使绕过 Flutter，也不能直接无限制调用本地后端。

## 域名与部署建议

- 生产域名：`https://mixer.douxing.cc`
- Caddy 负责 TLS
- Go 服务监听 `127.0.0.1:18080`
- Caddy 反代到 Go 服务
- SQLite 文件位于 `/opt/imagemixer-license/data/license.db`
- 每日使用 `sqlite3 ... ".backup"` 或 `VACUUM INTO` 备份
- 定期保留全量备份和最近 7 天备份文件

## 首版结论

如果目标是尽快售卖，我建议首版就按下面这套上：

- `Go`
- `SQLite`
- `Caddy`
- `Ed25519`
- 管理后台服务端渲染
- 客户端激活 + 本地签名授权文件 + 定期 refresh

这套方案实现快、内存低、部署简单，足够支撑首批用户。
