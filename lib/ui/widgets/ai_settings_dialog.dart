import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ai_config.dart';
import '../../providers/settings_provider.dart';
import '../../services/in_browser_wasm_service.dart';
import '../../theme/app_theme.dart';

class AiSettingsDialog extends StatefulWidget {
  const AiSettingsDialog({super.key});

  @override
  State<AiSettingsDialog> createState() => _AiSettingsDialogState();
}

class _AiSettingsDialogState extends State<AiSettingsDialog> {
  late AIServiceType _activeType;
  late String _wasmModelId;
  late bool _loadWasmFromDisk;
  List<String> _downloadedModels = [];
  late TextEditingController _ollamaUrlController;
  late TextEditingController _ollamaModelController;
  late TextEditingController _geminiKeyController;
  late String _geminiModel;
  late TextEditingController _openAiUrlController;
  late TextEditingController _openAiKeyController;
  late TextEditingController _openAiModelController;

  @override
  void initState() {
    super.initState();
    final cfg = context.read<SettingsProvider>().aiConfig;
    _activeType = cfg.activeType;
    _wasmModelId = cfg.wasmModelId;
    _loadWasmFromDisk = cfg.loadWasmFromDisk;
    _ollamaUrlController = TextEditingController(text: cfg.ollamaUrl);
    _ollamaModelController = TextEditingController(text: cfg.ollamaModel);
    _geminiKeyController = TextEditingController(text: cfg.geminiApiKey);
    _geminiModel = cfg.geminiModel;
    _openAiUrlController = TextEditingController(text: cfg.openAiUrl);
    _openAiKeyController = TextEditingController(text: cfg.openAiApiKey);
    _openAiModelController = TextEditingController(text: cfg.openAiModel);

    _refreshDownloadedModels();
  }

  Future<void> _refreshDownloadedModels() async {
    final list = await InBrowserWasmService.getDownloadedModels();
    if (mounted) {
      setState(() {
        _downloadedModels = list;
        // If user has downloaded models and current model is downloaded, default to loading from disk
        if (_downloadedModels.contains(_wasmModelId) && !_loadWasmFromDisk) {
          _loadWasmFromDisk = true;
        }
      });
    }
  }

  Future<void> _deleteDownloadedModel(String modelId) async {
    await InBrowserWasmService.deleteDownloadedModel(modelId);
    await _refreshDownloadedModels();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed $modelId from local disk storage.')),
      );
    }
  }

  @override
  void dispose() {
    _ollamaUrlController.dispose();
    _ollamaModelController.dispose();
    _geminiKeyController.dispose();
    _openAiUrlController.dispose();
    _openAiKeyController.dispose();
    _openAiModelController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final settings = context.read<SettingsProvider>();
    final newCfg = AIConfig(
      activeType: _activeType,
      wasmModelId: _wasmModelId,
      loadWasmFromDisk: _loadWasmFromDisk,
      ollamaUrl: _ollamaUrlController.text.trim(),
      ollamaModel: _ollamaModelController.text.trim(),
      geminiApiKey: _geminiKeyController.text.trim(),
      geminiModel: _geminiModel,
      openAiUrl: _openAiUrlController.text.trim(),
      openAiApiKey: _openAiKeyController.text.trim(),
      openAiModel: _openAiModelController.text.trim(),
    );

    await settings.updateAIConfig(newCfg);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI Engine settings saved!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.primaryAmber : AppTheme.primaryTerracotta;
    final hasWebGpu = InBrowserWasmService.isWebGPUSupported();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune, color: primaryColor, size: 24),
                  const SizedBox(width: 10),
                  const Text('AI Engine Configuration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Default Engine Selector
              const Text('Default Active AI Provider', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<AIServiceType>(
                initialValue: _activeType,
                decoration: const InputDecoration(labelText: 'Primary Engine'),
                items: const [
                  DropdownMenuItem(value: AIServiceType.inBrowserWasm, child: Text('🌐 In-Browser WASM (WebGPU - Gemma / Granite)')),
                  DropdownMenuItem(value: AIServiceType.localOllama, child: Text('💻 Local Ollama (http://localhost:11434)')),
                  DropdownMenuItem(value: AIServiceType.remoteGemini, child: Text('☁️ Google Gemini API (Flash)')),
                  DropdownMenuItem(value: AIServiceType.remoteOpenAI, child: Text('☁️ OpenAI / OpenRouter (Granite/Gemma/Claude)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _activeType = val);
                },
              ),
              const SizedBox(height: 20),

              // In-Browser WASM Card
              _buildSectionCard(
                isDark: isDark,
                title: 'In-Browser WASM / WebGPU Settings',
                icon: Icons.public,
                primaryColor: primaryColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: hasWebGpu ? AppTheme.accentSage.withAlpha(25) : Colors.amber.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(hasWebGpu ? Icons.check_circle : Icons.info_outline, size: 16, color: hasWebGpu ? AppTheme.accentSage : Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasWebGpu ? 'WebGPU Supported on this browser' : 'WebGPU not detected; rule-based WASM fallback will be used',
                              style: TextStyle(fontSize: 12, color: hasWebGpu ? AppTheme.accentSage : Colors.amber),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Model Loading Mode: Load from Disk vs Download
                    Row(
                      children: [
                        const Text('Model Loading Source:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        ChoiceChip(
                          avatar: const Icon(Icons.storage, size: 14),
                          label: const Text('Load from Disk', style: TextStyle(fontSize: 12)),
                          selected: _loadWasmFromDisk,
                          selectedColor: primaryColor.withAlpha(50),
                          onSelected: (val) {
                            setState(() => _loadWasmFromDisk = true);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          avatar: const Icon(Icons.download, size: 14),
                          label: const Text('Download / CDN', style: TextStyle(fontSize: 12)),
                          selected: !_loadWasmFromDisk,
                          selectedColor: primaryColor.withAlpha(50),
                          onSelected: (val) {
                            setState(() => _loadWasmFromDisk = false);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _wasmModelId,
                      decoration: const InputDecoration(labelText: 'Default In-Browser Model'),
                      items: AIConfig.wasmModelOptions.map((opt) {
                        final isDownloaded = _downloadedModels.contains(opt['id']);
                        final statusPrefix = isDownloaded ? '💾 [On Disk]' : '⬇️ [Download]';
                        return DropdownMenuItem(
                          value: opt['id'],
                          child: Text('$statusPrefix ${opt['name']} (${opt['size']})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _wasmModelId = val;
                            if (_downloadedModels.contains(val)) {
                              _loadWasmFromDisk = true;
                            }
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text('Select Model File (.task) from Disk'),
                          onPressed: () async {
                            final res = await InBrowserWasmService.pickModelFile(_wasmModelId);
                            if (res != null && res['name'] != null) {
                              final name = res['name'] as String;
                              setState(() {
                                _wasmModelId = name;
                                _loadWasmFromDisk = true;
                              });
                              await _refreshDownloadedModels();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Loaded model file from disk: $name')),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Downloaded Models on Disk section
                    if (_downloadedModels.isNotEmpty) ...[
                      const Text(
                        'Models Stored on Local Disk (Ready to Load):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _downloadedModels.map((id) {
                          final opt = AIConfig.getWasmModelOption(id);
                          final displayName = opt?['name']?.split('(').first.trim() ?? id;
                          final isCurrent = _wasmModelId == id;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isCurrent ? primaryColor.withAlpha(35) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCurrent ? primaryColor : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.storage, size: 14, color: isCurrent ? primaryColor : Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _deleteDownloadedModel(id),
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(Icons.close, size: 14, color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      Text(
                        '💡 No models downloaded to disk yet. Models will be saved to disk once downloaded for offline loading.',
                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Local Ollama
              _buildSectionCard(
                isDark: isDark,
                title: 'Local Ollama Settings',
                icon: Icons.terminal_outlined,
                primaryColor: primaryColor,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _ollamaUrlController,
                        decoration: const InputDecoration(labelText: 'Ollama Base URL', hintText: 'http://localhost:11434'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _ollamaModelController,
                        decoration: const InputDecoration(labelText: 'Model (e.g. gemma4, granite4.2)'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Google Gemini
              _buildSectionCard(
                isDark: isDark,
                title: 'Google Gemini Settings',
                icon: Icons.cloud_outlined,
                primaryColor: primaryColor,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _geminiKeyController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Gemini API Key', hintText: 'AIzaSy...'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _geminiModel,
                        decoration: const InputDecoration(labelText: 'Model'),
                        items: const [
                          DropdownMenuItem(value: 'gemini-1.5-flash', child: Text('Gemini 1.5 Flash')),
                          DropdownMenuItem(value: 'gemini-2.0-flash', child: Text('Gemini 2.0 Flash')),
                          DropdownMenuItem(value: 'gemini-1.5-pro', child: Text('Gemini 1.5 Pro')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _geminiModel = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // OpenAI / OpenRouter
              _buildSectionCard(
                isDark: isDark,
                title: 'OpenAI / OpenRouter API Settings',
                icon: Icons.api_outlined,
                primaryColor: primaryColor,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _openAiUrlController,
                            decoration: const InputDecoration(labelText: 'Base URL', hintText: 'https://openrouter.ai/api/v1'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _openAiKeyController,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'API Key', hintText: 'sk-or-...'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _openAiModelController,
                      decoration: const InputDecoration(labelText: 'Model Name', hintText: 'ibm/granite-3-8b-instruct or google/gemma-2-9b-it'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('Save AI Preferences'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Color primaryColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: primaryColor),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
