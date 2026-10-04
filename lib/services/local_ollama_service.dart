import 'dart:convert';
import 'package:http/http.dart' as http;

class LocalOllamaService {
  /// Fetches available local models from Ollama /api/tags
  static Future<List<String>> fetchInstalledModels(String baseUrl) async {
    final cleanUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final url = Uri.parse('$cleanUrl/api/tags');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final models = (data['models'] as List<dynamic>? ?? []);
        return models.map((m) => m['name'] as String).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Sends extraction prompt to local Ollama instance
  static Future<String> generate({
    required String baseUrl,
    required String model,
    required String prompt,
    String? systemPrompt,
  }) async {
    final cleanUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final url = Uri.parse('$cleanUrl/api/generate');

    final body = {
      'model': model,
      'prompt': prompt,
      'system': systemPrompt ?? '',
      'stream': false,
      'options': {
        'temperature': 0.2,
        'num_ctx': 8192,
        'num_predict': 4096,
      },
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['response'] as String? ?? '';
    } else {
      throw Exception('Ollama error (${response.statusCode}): ${response.body}');
    }
  }
}
