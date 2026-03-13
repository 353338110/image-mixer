import "dart:io";

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";

import "api_client.dart";
import "backend_manager.dart";

void main() {
  runApp(const ImageMixerApp());
}

class ImageMixerApp extends StatelessWidget {
  const ImageMixerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "ImageMixer",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A84FF)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _backendUrlController = TextEditingController(text: "http://127.0.0.1:8765");
  final _inputDirController = TextEditingController();
  final _processOutputDirController = TextEditingController();

  bool _recursive = true;
  int _maxWorkers = 0;
  String _processPreset = "invisible";
  String _processOutputFormat = "keep";
  int? _processSeed;
  bool _processCustomEnabled = true;
  bool _enableCrop = true;
  double _cropRatio = 0.995;
  bool _enableRotate = true;
  double _rotateDeg = 0.2;
  bool _enableResize = true;
  int _maxSize = 6000;
  bool _enableZoom = true;
  double _zoomFactor = 1.01;
  bool _enableColor = true;
  double _brightness = 0.01;
  double _contrast = 0.01;
  double _saturation = 0.01;
  bool _enableNoise = true;
  double _noiseSigma = 0.3;
  bool _enableCompress = true;
  int _jpegQuality = 97;
  bool _enableExif = true;

  late final TextEditingController _cropRatioController;
  late final TextEditingController _rotateDegController;
  late final TextEditingController _maxSizeController;
  late final TextEditingController _zoomFactorController;
  late final TextEditingController _brightnessController;
  late final TextEditingController _contrastController;
  late final TextEditingController _saturationController;
  late final TextEditingController _noiseSigmaController;
  late final TextEditingController _jpegQualityController;

  bool _isLoading = false;
  String _status = "Ready";
  List<String> _failedSamples = [];
  Process? _backendProcess;

  @override
  void initState() {
    super.initState();
    _cropRatioController = TextEditingController(text: _cropRatio.toStringAsFixed(3));
    _rotateDegController = TextEditingController(text: _rotateDeg.toStringAsFixed(2));
    _maxSizeController = TextEditingController(text: _maxSize.toString());
    _zoomFactorController = TextEditingController(text: _zoomFactor.toStringAsFixed(3));
    _brightnessController = TextEditingController(text: _brightness.toStringAsFixed(3));
    _contrastController = TextEditingController(text: _contrast.toStringAsFixed(3));
    _saturationController = TextEditingController(text: _saturation.toStringAsFixed(3));
    _noiseSigmaController = TextEditingController(text: _noiseSigma.toStringAsFixed(2));
    _jpegQualityController = TextEditingController(text: _jpegQuality.toString());
    _initBackend();
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    _inputDirController.dispose();
    _processOutputDirController.dispose();
    _cropRatioController.dispose();
    _rotateDegController.dispose();
    _maxSizeController.dispose();
    _zoomFactorController.dispose();
    _brightnessController.dispose();
    _contrastController.dispose();
    _saturationController.dispose();
    _noiseSigmaController.dispose();
    _jpegQualityController.dispose();
    _backendProcess?.kill();
    super.dispose();
  }

  Future<void> _initBackend() async {
    final api = ApiClient(_backendUrlController.text.trim());
    final manager = BackendManager(api);
    setState(() {
      _status = "初始化后端中...";
    });

    try {
      final process = await manager.ensureRunning();
      if (process == null) {
        final ok = await _safeHealth(api);
        setState(() {
          _status = ok ? "后端在线" : "未检测到后端，请确认已打包并放入应用目录";
        });
        return;
      }

      _backendProcess = process;
      final ok = await _waitForBackend(api);
      if (!ok) {
        final exitCode = await _backendProcess?.exitCode;
        final logHint =
            manager.lastLogPath == null ? "" : "，日志: ${manager.lastLogPath}";
        setState(() {
          _status = "后端启动失败(退出码: ${exitCode ?? "unknown"})$logHint";
        });
        return;
      }
      setState(() {
        _status = "后端已启动";
      });
    } catch (err) {
      setState(() {
        _status = "启动后端异常: $err";
      });
    }
  }

  Future<bool> _safeHealth(ApiClient api) async {
    try {
      return await api.health();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _waitForBackend(ApiClient api) async {
    const retries = 12;
    for (var i = 0; i < retries; i++) {
      if (await _safeHealth(api)) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    return false;
  }

  Future<void> _pickDir(TextEditingController controller) async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) {
      return;
    }
    setState(() {
      controller.text = dir;
    });
  }

  Future<void> _pickInputDir() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) {
      return;
    }
    setState(() {
      _inputDirController.text = dir;
      if (_processOutputDirController.text.trim().isEmpty) {
        _processOutputDirController.text = "$dir${Platform.pathSeparator}_processed";
      }
    });
  }

  Future<void> _healthCheck() async {
    final api = ApiClient(_backendUrlController.text.trim());
    setState(() {
      _status = "检查后端连接中...";
    });
    try {
      final ok = await api.health();
      setState(() {
        _status = ok ? "后端在线" : "后端不可用";
      });
    } catch (err) {
      setState(() {
        _status = "连接失败: $err";
      });
    }
  }

  Future<void> _processImages() async {
    final inputDir = _inputDirController.text.trim();
    final outputDir = _processOutputDirController.text.trim();
    if (inputDir.isEmpty) {
      setState(() {
        _status = "请选择图片目录";
      });
      return;
    }
    if (outputDir.isEmpty) {
      setState(() {
        _status = "请选择处理输出目录";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = "正在批量处理图片...";
    });
    final api = ApiClient(_backendUrlController.text.trim());
    try {
      final cropRatio = double.tryParse(_cropRatioController.text.trim());
      final rotateDeg = double.tryParse(_rotateDegController.text.trim());
      final maxSize = int.tryParse(_maxSizeController.text.trim());
      final zoomFactor = double.tryParse(_zoomFactorController.text.trim());
      final brightness = double.tryParse(_brightnessController.text.trim());
      final contrast = double.tryParse(_contrastController.text.trim());
      final saturation = double.tryParse(_saturationController.text.trim());
      final noiseSigma = double.tryParse(_noiseSigmaController.text.trim());
      final jpegQuality = int.tryParse(_jpegQualityController.text.trim());

      if (_processCustomEnabled) {
        if (cropRatio == null ||
            rotateDeg == null ||
            maxSize == null ||
            zoomFactor == null ||
            brightness == null ||
            contrast == null ||
            saturation == null ||
            noiseSigma == null ||
            jpegQuality == null) {
          setState(() {
            _status = "自定义参数格式不正确，请检查输入值。";
          });
          _isLoading = false;
          return;
        }
      }

      final result = await api.processImages(
        inputDir: inputDir,
        outputDir: outputDir,
        recursive: _recursive,
        maxWorkers: _maxWorkers,
        preset: _processPreset,
        outputFormat: _processOutputFormat,
        customEnabled: _processCustomEnabled,
        enableCrop: _enableCrop,
        cropRatio: cropRatio ?? _cropRatio,
        enableRotate: _enableRotate,
        rotateDeg: rotateDeg ?? _rotateDeg,
        enableResize: _enableResize,
        maxSize: maxSize ?? _maxSize,
        enableZoom: _enableZoom,
        zoomFactor: zoomFactor ?? _zoomFactor,
        enableColor: _enableColor,
        brightness: brightness ?? _brightness,
        contrast: contrast ?? _contrast,
        saturation: saturation ?? _saturation,
        enableNoise: _enableNoise,
        noiseSigma: noiseSigma ?? _noiseSigma,
        enableCompress: _enableCompress,
        jpegQuality: jpegQuality ?? _jpegQuality,
        enableExif: _enableExif,
        seed: _processSeed,
      );
      final failedNote = result.failedSamples.isEmpty
          ? ""
          : "，示例错误: ${result.failedSamples.first}";
      setState(() {
        _status =
            "处理完成: ${result.stats.processedFiles}/${result.stats.totalFiles}，失败 ${result.stats.failedFiles}$failedNote";
        _failedSamples = result.failedSamples;
      });
    } catch (err) {
      setState(() {
        _status = "处理失败: $err";
        _failedSamples = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetDefaults() {
    setState(() {
      _recursive = true;
      _maxWorkers = 0;

      _processPreset = "invisible";
      _processOutputFormat = "keep";
      _processSeed = null;
      _processCustomEnabled = true;
      _enableCrop = true;
      _cropRatio = 0.995;
      _enableRotate = true;
      _rotateDeg = 0.2;
      _enableResize = true;
      _maxSize = 6000;
      _enableZoom = true;
      _zoomFactor = 1.01;
      _enableColor = true;
      _brightness = 0.01;
      _contrast = 0.01;
      _saturation = 0.01;
      _enableNoise = true;
      _noiseSigma = 0.3;
      _enableCompress = true;
      _jpegQuality = 97;
      _enableExif = true;

      _cropRatioController.text = _cropRatio.toStringAsFixed(3);
      _rotateDegController.text = _rotateDeg.toStringAsFixed(2);
      _maxSizeController.text = _maxSize.toString();
      _zoomFactorController.text = _zoomFactor.toStringAsFixed(3);
      _brightnessController.text = _brightness.toStringAsFixed(3);
      _contrastController.text = _contrast.toStringAsFixed(3);
      _saturationController.text = _saturation.toStringAsFixed(3);
      _noiseSigmaController.text = _noiseSigma.toStringAsFixed(2);
      _jpegQualityController.text = _jpegQuality.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ImageMixer 本地图片处理"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _backendUrlController,
              decoration: const InputDecoration(
                labelText: "后端地址",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputDirController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "图片目录",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _pickInputDir, child: const Text("选择")),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Checkbox(
                  value: _recursive,
                  onChanged: (value) => setState(() {
                    _recursive = value ?? true;
                  }),
                ),
                const Text("递归扫描"),
                const SizedBox(width: 8),
                const Text("线程数(0自动)"),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: _maxWorkers.toString(),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed >= 0) {
                        _maxWorkers = parsed;
                      }
                    },
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _isLoading ? null : _healthCheck,
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text("检查后端"),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _resetDefaults,
                  icon: const Icon(Icons.refresh),
                  label: const Text("恢复默认设置"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("批量处理", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _processOutputDirController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: "批量处理输出目录",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _pickDir(_processOutputDirController),
                          child: const Text("选择"),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: _processCustomEnabled,
                              onChanged: (value) => setState(() {
                                _processCustomEnabled = value ?? true;
                              }),
                            ),
                            const Text("自定义参数（勾选后可手动改数值）"),
                          ],
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _processPreset,
                          onChanged: (value) => setState(() {
                            _processPreset = value ?? "invisible";
                          }),
                          items: const [
                            DropdownMenuItem(value: "invisible", child: Text("不可见（几乎无变化）")),
                            DropdownMenuItem(value: "mild", child: Text("轻度（轻微变化）")),
                            DropdownMenuItem(value: "standard", child: Text("标准（中等变化）")),
                            DropdownMenuItem(value: "strong", child: Text("强度（明显变化）")),
                          ],
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _processOutputFormat,
                          onChanged: (value) => setState(() {
                            _processOutputFormat = value ?? "keep";
                          }),
                          items: const [
                            DropdownMenuItem(value: "jpg", child: Text("JPG（有损压缩）")),
                            DropdownMenuItem(value: "png", child: Text("PNG（无损）")),
                            DropdownMenuItem(value: "webp", child: Text("WEBP（体积更小）")),
                            DropdownMenuItem(value: "keep", child: Text("保持原格式")),
                          ],
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 140,
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: "随机种子（可选）",
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              _processSeed = int.tryParse(value);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _processImages,
                          icon: const Icon(Icons.auto_fix_high),
                          label: const Text("一键处理"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_processCustomEnabled)
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _enableCrop,
                                onChanged: (value) => setState(() {
                                  _enableCrop = value ?? true;
                                }),
                              ),
                              const Text("裁剪（比例，1=不裁剪）"),
                            ],
                          ),
                          SizedBox(
                            width: 130,
                            child: TextField(
                              decoration: const InputDecoration(labelText: "比例（0.5-1.0）"),
                              controller: _cropRatioController,
                              keyboardType: TextInputType.number,
                              onChanged: (value) =>
                                  _cropRatio = double.tryParse(value) ?? _cropRatio,
                            ),
                          ),
                          Row(
                            children: [
                              Checkbox(
                                value: _enableRotate,
                                onChanged: (value) => setState(() {
                                  _enableRotate = value ?? true;
                                }),
                              ),
                              const Text("旋转（±角度°）"),
                            ],
                          ),
                          SizedBox(
                            width: 90,
                            child: TextField(
                              decoration: const InputDecoration(labelText: "角度°"),
                              controller: _rotateDegController,
                              keyboardType: TextInputType.number,
                              onChanged: (value) =>
                                  _rotateDeg = double.tryParse(value) ?? _rotateDeg,
                            ),
                          ),
                          Row(
                            children: [
                              Checkbox(
                                value: _enableResize,
                                onChanged: (value) => setState(() {
                                  _enableResize = value ?? true;
                                }),
                              ),
                              const Text("缩放（限制最大边）"),
                            ],
                          ),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              decoration: const InputDecoration(labelText: "最大边（像素）"),
                              controller: _maxSizeController,
                              keyboardType: TextInputType.number,
                              onChanged: (value) => _maxSize = int.tryParse(value) ?? _maxSize,
                            ),
                          ),
                          Row(
                            children: [
                              Checkbox(
                                value: _enableZoom,
                                onChanged: (value) => setState(() {
                                  _enableZoom = value ?? true;
                                }),
                              ),
                              const Text("放大（倍数）"),
                            ],
                          ),
                          SizedBox(
                            width: 110,
                            child: TextField(
                              decoration: const InputDecoration(labelText: "倍数（>=1）"),
                              controller: _zoomFactorController,
                              keyboardType: TextInputType.number,
                              onChanged: (value) =>
                                  _zoomFactor = double.tryParse(value) ?? _zoomFactor,
                            ),
                          ),
                          Row(
                            children: [
                              Checkbox(
                                value: _enableColor,
                                onChanged: (value) => setState(() {
                                  _enableColor = value ?? true;
                                }),
                              ),
                              const Text("颜色扰动（亮度/对比/饱和）"),
                            ],
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              decoration: const InputDecoration(labelText: "亮度（±）"),
                              controller: _brightnessController,
                              keyboardType: TextInputType.number,
                              onChanged: (value) =>
                                  _brightness = double.tryParse(value) ?? _brightness,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              decoration: const InputDecoration(labelText: "对比度（±）"),
                              controller: _contrastController,
                              keyboardType: TextInputType.number,
                              onChanged: (value) =>
                                  _contrast = double.tryParse(value) ?? _contrast,
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: TextField(
                              decoration: const InputDecoration(labelText: "饱和度（±）"),
                              controller: _saturationController,
                              keyboardType: TextInputType.number,
                              onChanged: (value) =>
                                  _saturation = double.tryParse(value) ?? _saturation,
                            ),
                          ),
                          Row(
                            children: [
                              Checkbox(
                                value: _enableNoise,
                                onChanged: (value) => setState(() {
                                  _enableNoise = value ?? true;
                                }),
                              ),
                              const Text("噪声（σ）"),
                            ],
                          ),
                          SizedBox(
                            width: 90,
                            child: TextField(
                              decoration: const InputDecoration(labelText: "σ"),
                              controller: _noiseSigmaController,
                              keyboardType: TextInputType.number,
                              onChanged: (value) =>
                                  _noiseSigma = double.tryParse(value) ?? _noiseSigma,
                            ),
                          ),
                          Row(
                            children: [
                              Checkbox(
                                value: _enableCompress,
                                onChanged: (value) => setState(() {
                                  _enableCompress = value ?? true;
                                }),
                              ),
                              const Text("压缩（JPG/WEBP 质量）"),
                            ],
                          ),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              decoration: const InputDecoration(labelText: "质量(60-100)"),
                              controller: _jpegQualityController,
                              keyboardType: TextInputType.number,
                              onChanged: (value) =>
                                  _jpegQuality = int.tryParse(value) ?? _jpegQuality,
                            ),
                          ),
                          Row(
                            children: [
                              Checkbox(
                                value: _enableExif,
                                onChanged: (value) => setState(() {
                                  _enableExif = value ?? true;
                                }),
                              ),
                              const Text("EXIF修改（时间/设备信息）"),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (_failedSamples.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("失败样例（最多10条）", style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      for (final item in _failedSamples)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: SelectableText(item),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            Text(_status, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
