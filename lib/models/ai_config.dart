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
  final bool loadWasmFromDisk; // whether to load previously downloaded model from disk
  
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
    this.wasmModelId = 'gemma-4-E2B-it-web.task',
    this.loadWasmFromDisk = true,
    this.ollamaUrl = 'http://localhost:11434',
    this.ollamaModel = 'gemma4',
    this.geminiApiKey = '',
    this.geminiModel = 'gemini-1.5-flash',
    this.openAiUrl = 'https://openrouter.ai/api/v1',
    this.openAiApiKey = '',
    this.openAiModel = 'google/gemma-2-9b-it',
  });

  static const List<Map<String, String>> wasmModelOptions = [
    {
      'id': 'gemma-4-E2B-it-web.task',
      'name': 'Gemma 4-E2B IT (Google MediaPipe / WebGPU)',
      'description': 'Google 4-bit 2B Gemma model on local disk (~2.0 GB)',
      'size': '~2.0 GB',
    },
    {
      'id': 'gemma-4-E4B-it-web.task',
      'name': 'Gemma 4-E4B IT (Google MediaPipe / WebGPU)',
      'description': 'Google 4-bit 4B Gemma model on local disk (~3.0 GB)',
      'size': '~3.0 GB',
    },
  ];

  static Map<String, String>? getWasmModelOption(String id) {
    try {
      return wasmModelOptions.firstWhere((opt) => opt['id'] == id);
    } catch (_) {
      return null;
    }
  }

  static const List<Map<String, String>> ollamaModelOptions = [
    {'id': 'gemma4', 'name': 'Gemma 4 (Ollama)'},
    {'id': 'granite4.2', 'name': 'Granite 4.2 (Ollama)'},
    {'id': 'llama3.2', 'name': 'Llama 3.2 (Ollama)'},
  ];

  AIConfig copyWith({
    AIServiceType? activeType,
    String? wasmModelId,
    bool? loadWasmFromDisk,
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
      loadWasmFromDisk: loadWasmFromDisk ?? this.loadWasmFromDisk,
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
        'loadWasmFromDisk': loadWasmFromDisk,
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

    String wasmId = json['wasmModelId'] as String? ?? 'gemma-4-E2B-it-web.task';
    // Migrate legacy model IDs to the updated Gemma 4 MediaPipe models
    if (wasmId.contains('gemma-2-2b') || wasmId.contains('granite-3.0') || wasmId.contains('Llama-3.2')) {
      wasmId = 'gemma-4-E2B-it-web.task';
    }

    return AIConfig(
      activeType: type,
      wasmModelId: wasmId,
      loadWasmFromDisk: json['loadWasmFromDisk'] as bool? ?? true,
      ollamaUrl: json['ollamaUrl'] as String? ?? 'http://localhost:11434',
      ollamaModel: json['ollamaModel'] as String? ?? 'gemma4',
      geminiApiKey: json['geminiApiKey'] as String? ?? '',
      geminiModel: json['geminiModel'] as String? ?? 'gemini-1.5-flash',
      openAiUrl: json['openAiUrl'] as String? ?? 'https://openrouter.ai/api/v1',
      openAiApiKey: json['openAiApiKey'] as String? ?? '',
      openAiModel: json['openAiModel'] as String? ?? 'google/gemma-2-9b-it',
    );
  }
}
