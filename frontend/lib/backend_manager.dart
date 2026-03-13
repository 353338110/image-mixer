import "dart:async";
import "dart:io";

import "api_client.dart";

class BackendManager {
  BackendManager(this.apiClient);

  final ApiClient apiClient;
  String? lastLogPath;

  Future<Process?> ensureRunning() async {
    final ok = await _healthCheck();
    if (ok) {
      return null;
    }
    final executable = _resolveBackendExecutable();
    if (executable == null) {
      return null;
    }
    return _startProcess(executable);
  }

  Future<bool> _healthCheck() async {
    try {
      return await apiClient.health();
    } catch (_) {
      return false;
    }
  }

  String? _resolveBackendExecutable() {
    final resolved = File(Platform.resolvedExecutable);
    final exeDir = resolved.parent;

    if (Platform.isWindows) {
      final candidates = [
        exeDir.uri.resolve("backend/imagemixer_backend.exe").toFilePath(),
        exeDir.uri.resolve("imagemixer_backend.exe").toFilePath(),
      ];
      return _pickExisting(candidates);
    }

    if (Platform.isMacOS) {
      final candidates = [
        exeDir.uri.resolve("../Frameworks/imagemixer_backend").toFilePath(),
        exeDir.uri.resolve("../Resources/imagemixer_backend").toFilePath(),
      ];
      return _pickExisting(candidates);
    }

    return null;
  }

  String? _pickExisting(List<String> candidates) {
    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  Future<Process> _startProcess(String executable) async {
    final args = ["--host", "127.0.0.1", "--port", "8765"];
    final process = await Process.start(
      executable,
      args,
      mode: ProcessStartMode.normal,
      runInShell: false,
    );

    try {
      final logFile = File("${Directory.systemTemp.path}/imagemixer_backend.log");
      lastLogPath = logFile.path;
      final sink = logFile.openWrite(mode: FileMode.writeOnlyAppend);
      process.stdout.listen(sink.add);
      process.stderr.listen(sink.add);
      process.exitCode.whenComplete(() => sink.close());
    } catch (_) {
      // If logging is not available, continue without log capture.
    }

    return process;
  }
}
