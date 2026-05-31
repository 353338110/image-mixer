# ImageMixer（Flutter + Python，本地离线）

`ImageMixer` 是一个本地批量图片处理工具：

1. 前端：Flutter 桌面端（Windows / macOS）
2. 后端：Python FastAPI + Pillow + NumPy
3. 全流程：选择目录 -> 选择输出目录 -> 一键批量处理

## 功能概览

- 本地离线处理，不上传图片
- 批量处理图片（支持递归）
- 批量处理管线：裁剪、旋转、缩放、放大、颜色扰动、噪声、压缩、EXIF 修改
- 默认预设为“不可见”，处理后肉眼几乎无差异
- 批量处理支持“自定义参数”勾选与手工输入
- 固定随机种子时处理结果可复现
- 递归处理时会自动跳过输出目录，避免重复处理已生成图片

## 项目结构

```text
ImageMixer/
  backend/
    app/
      main.py          # API 入口
      processor.py     # 批量图片处理管线
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

## API（可选）

健康检查：

```bash
curl http://127.0.0.1:8765/health
```

批量处理：

```bash
curl -X POST http://127.0.0.1:8765/process-images \
  -H "Content-Type: application/json" \
  -d '{
    "input_dir": "/path/to/images",
    "output_dir": "/path/to/images_processed",
    "recursive": true,
    "preset": "invisible",
    "output_format": "keep",
    "custom_enabled": false,
    "seed": 42
  }'
```

## 注意事项

1. `run_backend` 会自动创建 `.venv` 并安装依赖
2. `run_frontend` 依赖本机已安装 Flutter 且可用 desktop
3. 默认处理输出目录为：`<输入目录>/_processed`

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
