enum AIServiceType {
  inBrowserWasm,
  localOllama,
  remoteGemini,
  remoteOpenAI,
}

class AIConfig {
  final AIServiceType activeType;

  // In-Browser WASM config
  final String wasmModelId; // e.g. "gemma-2-2b-it-q4f16_1-MLC" or "granite-3.0-2b-instruct-q4f16_1-MLC"
  
  // Local AI (Ollama / LM Studio)
  final String ollamaUrl;
  final String ollamaModel;

  // Remote Google Gemini
  final String geminiApiKey;
  final String geminiModel;

  // Remote OpenAI / OpenRouter
  final String openAiUrl;
  final String openAiApiKey;
  final String openAiModel;

  const AIConfig({
    this.activeType = AIServiceType.inBrowserWasm,
    this.wasmModelId = 'gemma-2-2b-it-q4f16_1-MLC',
    this.ollamaUrl = 'http://localhost:11434',
    this.ollamaModel = 'gemma2:2b',
    this.geminiApiKey = '',
    this.geminiModel = 'gemini-1.5-flash',
    this.openAiUrl = 'https://openrouter.ai/api/v1',
    this.openAiApiKey = '',
    this.openAiModel = 'google/gemma-2-9b-it',
  });

  static const List<Map<String, String>> wasmModelOptions = [
    {
      'id': 'gemma-2-2b-it-q4f16_1-MLC',
      'name': 'Gemma 4 / 2B (Google) - WASM/WebGPU',
      'description': 'Compact Gemma model optimized for high accuracy on cooking recipes in-browser',
      'size': '~1.4 GB',
    },
    {
      'id': 'granite-3.0-2b-instruct-q4f16_1-MLC',
      'name': 'Granite 4.2 / 3B (IBM) - WASM/WebGPU',
      'description': 'Enterprise-grade Granite instruction-tuned model running directly in browser',
      'size': '~1.6 GB',
    },
    {
      'id': 'Llama-3.2-1B-Instruct-q4f16_1-MLC',
      'name': 'Llama 3.2 1B (Ultra-Lightweight WASM)',
      'description': 'Fastest loading in-browser model for lower memory devices',
      'size': '~850 MB',
    },
  ];

  static const List<Map<String, String>> ollamaModelOptions = [
    {'id': 'gemma4', 'name': 'Gemma 4 / Gemma 2 (Ollama)'},
    {'id': 'granite4.2', 'name': 'Granite 4.2 / 3.2 (Ollama)'},
    {'id': 'granite3-dense', 'name': 'IBM Granite 3 Dense'},
    {'id': 'gemma2:2b', 'name': 'Gemma 2:2b (Ollama lightweight)'},
    {'id': 'llama3.2', 'name': 'Llama 3.2 (Ollama)'},
  ];

  AIConfig copyWith({
    AIServiceType? activeType,
    String? wasmModelId,
    String? ollamaUrl,
    String? ollamaModel,
    String? geminiApiKey,
    String? geminiModel,
    String? openAiUrl,
    String? openAiApiKey,
    String? openAiModel,
  }) {
    return AIConfig(
      activeType: activeType ?? this.activeType,
      wasmModelId: wasmModelId ?? this.wasmModelId,
      ollamaUrl: ollamaUrl ?? this.ollamaUrl,
      ollamaModel: ollamaModel ?? this.ollamaModel,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      geminiModel: geminiModel ?? this.geminiModel,
      openAiUrl: openAiUrl ?? this.openAiUrl,
      openAiApiKey: openAiApiKey ?? this.openAiApiKey,
      openAiModel: openAiModel ?? this.openAiModel,
    );
  }

  Map<String, dynamic> toJson() => {
        'activeType': activeType.name,
        'wasmModelId': wasmModelId,
        'ollamaUrl': ollamaUrl,
        'ollamaModel': ollamaModel,
        'geminiApiKey': geminiApiKey,
        'geminiModel': geminiModel,
        'openAiUrl': openAiUrl,
        'openAiApiKey': openAiApiKey,
        'openAiModel': openAiModel,
      };

  factory AIConfig.fromJson(Map<String, dynamic> json) {
    AIServiceType type = AIServiceType.inBrowserWasm;
    try {
      final typeName = json['activeType'] as String?;
      if (typeName != null) {
        type = AIServiceType.values.byName(typeName);
      }
    } catch (_) {}

    return AIConfig(
      activeType: type,
      wasmModelId: json['wasmModelId'] as String? ?? 'gemma-2-2b-it-q4f16_1-MLC',
      ollamaUrl: json['ollamaUrl'] as String? ?? 'http://localhost:11434',
      ollamaModel: json['ollamaModel'] as String? ?? 'gemma2:2b',
      geminiApiKey: json['geminiApiKey'] as String? ?? '',
      geminiModel: json['geminiModel'] as String? ?? 'gemini-1.5-flash',
      openAiUrl: json['openAiUrl'] as String? ?? 'https://openrouter.ai/api/v1',
      openAiApiKey: json['openAiApiKey'] as String? ?? '',
      openAiModel: json['openAiModel'] as String? ?? 'google/gemma-2-9b-it',
    );
  }
}
