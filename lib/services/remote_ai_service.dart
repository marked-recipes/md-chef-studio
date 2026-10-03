import 'dart:convert';
import 'package:http/http.dart' as http;

class RemoteAIService {
  /// Google Gemini REST API execution
  static Future<String> generateGemini({
    required String apiKey,
    required String model,
    required String prompt,
    String? systemInstruction,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('Gemini API Key is required. Please configure it in AI Settings.');
    }

    final cleanModel = model.trim().isEmpty ? 'gemini-1.5-flash' : model.trim();
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$cleanModel:generateContent',
    );

    final contents = <Map<String, dynamic>>[
      {
        'role': 'user',
        'parts': [
          {'text': prompt}
        ]
      }
    ];

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 4096,
      },
    };

    if (systemInstruction != null && systemInstruction.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemInstruction}
        ]
      };
    }

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey.trim(),
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 90));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>? ?? [];
      if (candidates.isNotEmpty) {
        final content = candidates.first['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>? ?? [];
        if (parts.isNotEmpty) {
          return parts.first['text'] as String? ?? '';
        }
      }
      return '';
    } else {
      final err = jsonDecode(response.body);
      throw Exception('Gemini API Error (${response.statusCode}): ${err['error']?['message'] ?? response.body}');
    }
  }

  /// OpenAI / OpenRouter REST API execution
  static Future<String> generateOpenAI({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String prompt,
    String? systemPrompt,
  }) async {
    final cleanUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final url = cleanUrl.endsWith('/chat/completions')
        ? Uri.parse(cleanUrl)
        : Uri.parse('$cleanUrl/chat/completions');

    final messages = <Map<String, String>>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    final body = {
      'model': model.trim().isEmpty ? 'gpt-4o-mini' : model.trim(),
      'messages': messages,
      'temperature': 0.2,
      'max_tokens': 3000,
    };

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 90));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>? ?? [];
      if (choices.isNotEmpty) {
        return choices.first['message']?['content'] as String? ?? '';
      }
      return '';
    } else {
      throw Exception('OpenAI/OpenRouter error (${response.statusCode}): ${response.body}');
    }
  }
}
