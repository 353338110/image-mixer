import "dart:convert";

import "package:http/http.dart" as http;

import "models.dart";

class ApiClient {
  ApiClient(this.baseUrl);

  final String baseUrl;

  Future<bool> health() async {
    final response = await http
        .get(Uri.parse("$baseUrl/health"))
        .timeout(const Duration(seconds: 6));
    return response.statusCode == 200;
  }

  Future<ProcessResponse> processImages({
    required String inputDir,
    required String outputDir,
    required bool recursive,
    required int maxWorkers,
    required String preset,
    required String outputFormat,
    required bool customEnabled,
    required bool enableCrop,
    required double cropRatio,
    required bool enableRotate,
    required double rotateDeg,
    required bool enableResize,
    required int maxSize,
    required bool enableZoom,
    required double zoomFactor,
    required bool enableColor,
    required double brightness,
    required double contrast,
    required double saturation,
    required bool enableNoise,
    required double noiseSigma,
    required bool enableCompress,
    required int jpegQuality,
    required bool enableExif,
    int? seed,
  }) async {
    final response = await http
        .post(
          Uri.parse("$baseUrl/process-images"),
          headers: const {"Content-Type": "application/json"},
          body: jsonEncode({
            "input_dir": inputDir,
            "output_dir": outputDir,
            "recursive": recursive,
            "max_workers": maxWorkers,
            "preset": preset,
            "output_format": outputFormat,
            "custom_enabled": customEnabled,
            "enable_crop": enableCrop,
            "crop_ratio": cropRatio,
            "enable_rotate": enableRotate,
            "rotate_deg": rotateDeg,
            "enable_resize": enableResize,
            "max_size": maxSize,
            "enable_zoom": enableZoom,
            "zoom_factor": zoomFactor,
            "enable_color": enableColor,
            "brightness": brightness,
            "contrast": contrast,
            "saturation": saturation,
            "enable_noise": enableNoise,
            "noise_sigma": noiseSigma,
            "enable_compress": enableCompress,
            "jpeg_quality": jpegQuality,
            "enable_exif": enableExif,
            "seed": seed,
          }),
        )
        .timeout(const Duration(minutes: 30));

    if (response.statusCode != 200) {
      throw Exception("HTTP ${response.statusCode}: ${response.body}");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ProcessResponse.fromJson(data);
  }
}
