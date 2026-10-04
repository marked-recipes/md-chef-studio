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

  static Future<bool> isModelDownloaded(String modelId) async => false;

  static Future<List<String>> getDownloadedModels([List<String>? knownModelIds]) async => [];

  static Future<bool> deleteDownloadedModel(String modelId) async => false;

  static Future<Map<String, dynamic>?> pickModelFile([String? modelId]) async => null;

  static bool registerModelFileUrl(String modelId, String url) => false;

  static Future<void> loadWebLlmModel({
    required String modelId,
    bool fromDiskOnly = false,
    required void Function(double progress, String status) onProgress,
  }) async {
    onProgress(1.0, fromDiskOnly ? 'Ready (Loaded from disk - VM/Stub mode)' : 'Ready (VM/Stub mode)');
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
