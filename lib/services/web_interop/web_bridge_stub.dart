import 'dart:typed_data';

class WebBridge {
  static bool isWebGpuSupported() => false;

  static Future<String?> extractTextFromPdf(Uint8List bytes) async {
    return null;
  }

  static Future<String?> extractTextFromHtml(String html) async {
    return null;
  }

  static Future<String?> fetchUrlContent(String url) async {
    return null;
  }

  static Future<void> loadWebLlmModel({
    required String modelId,
    required void Function(double progress, String status) onProgress,
  }) async {
    onProgress(1.0, 'Ready (VM/Stub mode)');
  }

  static Future<String?> generateWebLlm({
    required String prompt,
    String? systemPrompt,
  }) async {
    return null;
  }

  static bool downloadBlob(String filename, String content) {
    return false;
  }
}
