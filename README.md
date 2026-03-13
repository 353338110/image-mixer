# ImageMixer（Flutter + Python，本地离线）

`ImageMixer` 是一个本地图片去重工具：

1. 前端：Flutter 桌面端（Windows / macOS）
2. 后端：Python FastAPI + OpenCV + NumPy + ONNX Runtime
3. 全流程：选择目录 -> 扫描预览 -> 一键去重（移动）-> 一键回滚

## 功能概览

- 本地离线处理，不上传图片
- 批量扫描（支持递归）
- 多特征去重：SHA-256、dHash、aHash、HSV 直方图
- CLIP ONNX 向量召回（可选增强相似图召回）
- 保留策略：质量最佳 / 最新 / 最早
- 导出报告：CSV + Excel（XLSX）
- 一键回滚：误操作可恢复
- SQLite 特征缓存：重复扫描更快
- 批量处理管线：裁剪、旋转、缩放、放大、颜色扰动、噪声、压缩、EXIF 修改
- 默认预设为“不可见”，处理后肉眼几乎无差异
- 批量处理支持“自定义参数”勾选与手工输入

## 项目结构

```text
ImageMixer/
  backend/
    app/
      main.py          # API 入口
      scanner.py       # 去重算法与移动记录
      reporter.py      # CSV/XLSX 报告导出
      rollback.py      # 回滚逻辑
      models.py        # 请求/响应模型
    requirements.txt
  frontend/
    lib/
      main.dart        # Flutter 主界面
      api_client.dart  # 后端接口调用
      models.dart      # 前端数据模型
    pubspec.yaml
  scripts/
    bootstrap_frontend.sh|.bat
    run_backend.sh|.bat
    run_frontend.sh|.bat
    run_all.sh|.bat
```

## 环境要求

1. Python 3.10+
2. Flutter SDK（已开启 desktop 支持）
3. macOS 或 Windows

## 快速启动

### 1) 启动后端

macOS:

```bash
./scripts/run_backend.sh
```

Windows:

```bat
scripts\run_backend.bat
```

默认地址：`http://127.0.0.1:8765`

### 2) 首次初始化 Flutter 宿主工程

macOS:

```bash
./scripts/bootstrap_frontend.sh
```

Windows:

```bat
scripts\bootstrap_frontend.bat
```

### 3) 启动前端

macOS:

```bash
./scripts/run_frontend.sh
```

Windows:

```bat
scripts\run_frontend.bat
```

或一键启动前后端：

```bash
./scripts/run_all.sh
```

```bat
scripts\run_all.bat
```

## CLIP ONNX 向量召回说明

在 UI 中勾选 `启用 CLIP ONNX 向量召回` 后，需要选择本地 ONNX 模型文件（`.onnx`）。

建议：

1. 使用图像编码器 ONNX（输出为单个图像向量）
2. 输入尺寸为 `224x224`
3. 开始可用默认阈值：`0.90`

说明：

1. CLIP 模型用于增强“视觉相似但哈希差异大”的召回
2. 数据量大时可降低 `CLIP 全量比对上限` 控制耗时

## 报告导出

前端点击 `导出 CSV/XLSX` 后，会生成：

1. `xxx_summary.csv`：总体统计
2. `xxx_details.csv`：逐组逐图片明细
3. `xxx.xlsx`：Summary + Details 两个工作表

## 一键回滚

执行去重后，工具会在移动目录下写入操作记录：

1. `<重复图目录>/.imagemixer_ops/<operation_id>.json`

点击 `一键回滚` 会优先回滚最近一次去重操作（或当前会话中的操作 ID）。

回滚策略：

1. 将移动后的文件恢复到原路径
2. 若原路径已存在同名文件，自动添加 `_restored_N` 防冲突

## API（可选）

健康检查：

```bash
curl http://127.0.0.1:8765/health
```

扫描：

```bash
curl -X POST http://127.0.0.1:8765/scan \
  -H "Content-Type: application/json" \
  -d '{
    "input_dir": "/path/to/images",
    "recursive": true,
    "dhash_hamming_threshold": 10,
    "ahash_hamming_threshold": 10,
    "histogram_threshold": 0.90,
    "clip_enabled": false,
    "keep_strategy": "best_quality",
    "dry_run": true,
    "action": "none"
  }'
```

导出报告：

```bash
curl -X POST http://127.0.0.1:8765/export-report \
  -H "Content-Type: application/json" \
  -d '{"output_dir":"/tmp","base_name":"dedup_report","formats":["csv","xlsx"],"scan_result":{...}}'
```

回滚：

```bash
curl -X POST http://127.0.0.1:8765/rollback \
  -H "Content-Type: application/json" \
  -d '{"moved_to":"/path/to/_duplicates_review","operation_id":null}'
```

## 注意事项

1. `run_backend` 会自动创建 `.venv` 并安装依赖
2. `run_frontend` 依赖本机已安装 Flutter 且可用 desktop
3. 默认重复图移动目录为：`<输入目录>/_duplicates_review`

## 打包为可安装文件（Windows / macOS）

### 打包后端（生成可执行文件）

macOS:

```bash
./scripts/build_backend.sh
```

Windows:

```bat
scripts\build_backend.bat
```

产物：

- macOS: `backend/dist/imagemixer_backend`
- Windows: `backend/dist/imagemixer_backend.exe`

### 构建 Flutter Release

```bash
cd frontend
flutter build windows --release
flutter build macos --release
```

### 将后端复制进应用包

macOS:

```bash
./scripts/copy_backend_to_app.sh
```

Windows:

```bat
scripts\copy_backend_to_app.bat
```

### 生成安装包

Windows（Inno Setup）：

```bat
scripts\build_windows_installer.bat
```

生成文件：`dist/ImageMixer-Setup.exe`

macOS（DMG）：

```bash
./scripts/build_macos_dmg.sh
```

生成文件：`dist/ImageMixer-macos.dmg`

### 说明

1. Flutter 端已内置自动启动后端的逻辑
2. 后端会读取 `imagemixer_backend` 文件并在 `127.0.0.1:8765` 启动
3. 如需代码签名或公证，请在打包完成后进行
4. macOS 下脚本会对后端二进制和 App 做 ad-hoc 签名

### 一键打包

Windows：

```bat
scripts\package_all.bat
```

macOS：

```bash
./scripts/package_all.sh
```

### 启动失败排查（macOS）

如果界面提示 `Connection refused`，请查看后端日志：

- 日志路径：`/var/folders/.../imagemixer_backend.log`（系统临时目录）

在终端执行：

```bash
cat "$(python3 - <<'PY'
import tempfile
print(f"{tempfile.gettempdir()}/imagemixer_backend.log")
PY
)"
```
