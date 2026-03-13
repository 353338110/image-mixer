class ProcessStats {
  ProcessStats({
    required this.inputDir,
    required this.outputDir,
    required this.totalFiles,
    required this.processedFiles,
    required this.failedFiles,
    required this.elapsedSeconds,
  });

  final String inputDir;
  final String outputDir;
  final int totalFiles;
  final int processedFiles;
  final int failedFiles;
  final double elapsedSeconds;

  factory ProcessStats.fromJson(Map<String, dynamic> json) {
    return ProcessStats(
      inputDir: json["input_dir"] as String,
      outputDir: json["output_dir"] as String,
      totalFiles: (json["total_files"] as num).toInt(),
      processedFiles: (json["processed_files"] as num).toInt(),
      failedFiles: (json["failed_files"] as num).toInt(),
      elapsedSeconds: (json["elapsed_seconds"] as num).toDouble(),
    );
  }
}

class ProcessResponse {
  ProcessResponse({
    required this.stats,
    required this.failedSamples,
  });

  final ProcessStats stats;
  final List<String> failedSamples;

  factory ProcessResponse.fromJson(Map<String, dynamic> json) {
    return ProcessResponse(
      stats: ProcessStats.fromJson(json["stats"] as Map<String, dynamic>),
      failedSamples: (json["failed_samples"] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
