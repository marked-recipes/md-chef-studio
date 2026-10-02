import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ai_config.dart';
import '../../models/recipe.dart';
import '../../providers/extraction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/in_browser_wasm_service.dart';
import '../../theme/app_theme.dart';
import 'recipe_editor_dialog.dart';

class AiExtractorDialog extends StatefulWidget {
  const AiExtractorDialog({super.key});

  @override
  State<AiExtractorDialog> createState() => _AiExtractorDialogState();
}

class _AiExtractorDialogState extends State<AiExtractorDialog> with SingleTickerProviderStateMixin {
  late TabController _inputTabController;

  // Controllers
  final TextEditingController _urlController = TextEditingController(text: 'https://www.gimmesomeoven.com/cacio-e-pepe/');
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController(text: 'Pasta');

  PlatformFile? _selectedFile;
  Uint8List? _selectedFileBytes;
  int? _selectedFileSize;
  AIServiceType _selectedProvider = AIServiceType.inBrowserWasm;
  String _selectedWasmModel = 'gemma-2-2b-it-q4f16_1-MLC';
  String _selectedOllamaModel = 'gemma4';

  @override
  void initState() {
    super.initState();
    _inputTabController = TabController(length: 3, vsync: this);
    final aiConfig = context.read<SettingsProvider>().aiConfig;
    _selectedProvider = aiConfig.activeType;
    _selectedWasmModel = aiConfig.wasmModelId;
    _selectedOllamaModel = aiConfig.ollamaModel;
  }

  @override
  void dispose() {
    _inputTabController.dispose();
    _urlController.dispose();
    _textController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'html', 'htm', 'txt', 'md'],
    );

    if (result != null) {
      final bytes = await result.readAsBytes();
      setState(() {
        _selectedFile = result;
        _selectedFileBytes = bytes;
        _selectedFileSize = bytes.length;
      });
    }
  }

  AIConfig _buildActiveConfig(SettingsProvider settings) {
    return settings.aiConfig.copyWith(
      activeType: _selectedProvider,
      wasmModelId: _selectedWasmModel,
      ollamaModel: _selectedOllamaModel,
    );
  }

  Future<void> _triggerExtraction() async {
    final extraction = context.read<ExtractionProvider>();
    final settings = context.read<SettingsProvider>();
    final config = _buildActiveConfig(settings);
    final categoryHint = _categoryController.text.trim();

    final tabIndex = _inputTabController.index;

    if (tabIndex == 0) {
      // Document / File
      if (_selectedFile == null || _selectedFileBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a file first (PDF, HTML, or TXT)')),
        );
        return;
      }

      final ext = _selectedFile!.extension?.toLowerCase() ?? '';
      if (ext == 'pdf') {
        await extraction.extractFromPdf(
          bytes: _selectedFileBytes!,
          fileName: _selectedFile!.name,
          config: config,
          categoryHint: categoryHint,
        );
      } else if (ext == 'html' || ext == 'htm') {
        final html = utf8.decode(_selectedFileBytes!);
        await extraction.extractFromHtml(
          htmlContent: html,
          config: config,
          categoryHint: categoryHint,
          sourceUrl: 'File: ${_selectedFile!.name}',
        );
      } else {
        final text = utf8.decode(_selectedFileBytes!);
        await extraction.extractFromText(
          text: text,
          config: config,
          categoryHint: categoryHint,
          sourceUrl: 'File: ${_selectedFile!.name}',
        );
      }
    } else if (tabIndex == 1) {
      // URL
      final url = _urlController.text.trim();
      if (url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid recipe URL')),
        );
        return;
      }
      await extraction.extractFromUrl(
        url: url,
        config: config,
        categoryHint: categoryHint,
      );
    } else {
      // Paste Text / HTML
      final text = _textController.text.trim();
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please paste some recipe text or HTML content')),
        );
        return;
      }
      if (text.contains('<html') || text.contains('<div') || text.contains('<body')) {
        await extraction.extractFromHtml(
          htmlContent: text,
          config: config,
          categoryHint: categoryHint,
        );
      } else {
        await extraction.extractFromText(
          text: text,
          config: config,
          categoryHint: categoryHint,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.primaryAmber : AppTheme.primaryTerracotta;
    final extraction = context.watch<ExtractionProvider>();
    final settings = context.watch<SettingsProvider>();
    final hasWebGpu = InBrowserWasmService.isWebGPUSupported();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 880),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.auto_awesome, color: primaryColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Recipe Studio Extractor',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Extract recipes from PDFs, HTML, Web URLs, & text via WASM, Ollama, or Cloud AI',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      extraction.clear();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),

            // Main Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step 1: Input Source Selector
                    Text(
                      '1. Select Recipe Source',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _inputTabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: isDark ? Colors.white : Colors.black,
                        unselectedLabelColor: Colors.grey,
                        tabs: const [
                          Tab(icon: Icon(Icons.upload_file_outlined), text: 'Upload PDF / HTML / TXT'),
                          Tab(icon: Icon(Icons.link_outlined), text: 'From Web URL / URI'),
                          Tab(icon: Icon(Icons.edit_note_outlined), text: 'Paste Text / HTML'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Input Sub-views
                    SizedBox(
                      height: 160,
                      child: TabBarView(
                        controller: _inputTabController,
                        children: [
                          // Tab 1: File Upload
                          _buildFileUploadTab(isDark, primaryColor),
                          // Tab 2: URL Input
                          _buildUrlInputTab(isDark, primaryColor),
                          // Tab 3: Text Paste
                          _buildTextInputTab(isDark),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Step 2: AI Engine & Model Selector
                    Text(
                      '2. Choose AI Engine',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildProviderChoiceChip(
                          type: AIServiceType.inBrowserWasm,
                          title: 'In-Browser WASM',
                          subtitle: 'Gemma 4 / Granite 4.2 WebGPU',
                          icon: Icons.public,
                          isDark: isDark,
                          primaryColor: primaryColor,
                        ),
                        _buildProviderChoiceChip(
                          type: AIServiceType.localOllama,
                          title: 'Local AI (Ollama)',
                          subtitle: 'localhost:11434',
                          icon: Icons.terminal_outlined,
                          isDark: isDark,
                          primaryColor: primaryColor,
                        ),
                        _buildProviderChoiceChip(
                          type: AIServiceType.remoteGemini,
                          title: 'Google Gemini',
                          subtitle: 'Gemini 1.5/2.0 Flash',
                          icon: Icons.cloud_outlined,
                          isDark: isDark,
                          primaryColor: primaryColor,
                        ),
                        _buildProviderChoiceChip(
                          type: AIServiceType.remoteOpenAI,
                          title: 'OpenAI / OpenRouter',
                          subtitle: 'Granite / Gemma API',
                          icon: Icons.api_outlined,
                          isDark: isDark,
                          primaryColor: primaryColor,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Engine-specific options & diagnostics
                    _buildEngineSpecificSettings(isDark, primaryColor, settings, hasWebGpu, extraction),

                    const SizedBox(height: 20),

                    // Category Hint Input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _categoryController,
                            decoration: const InputDecoration(
                              labelText: 'Target Cuisine / Category',
                              hintText: 'e.g. Pasta, Soup, Main, Dessert',
                              prefixIcon: Icon(Icons.folder_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Action Button or Loading Progress
                    if (extraction.isExtracting) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryColor.withAlpha(76)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    extraction.statusMessage,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                                Text(
                                  '${(extraction.progress * 100).toInt()}%',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: extraction.progress,
                              color: primaryColor,
                              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(4),
                              minHeight: 8,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Extract & Structure Recipe', style: TextStyle(fontSize: 16)),
                          onPressed: _triggerExtraction,
                        ),
                      ),
                    ],

                    // Error Message
                    if (extraction.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withAlpha(76)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                extraction.errorMessage!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Step 3: Extracted Recipe Result Card
                    if (extraction.extractedRecipe != null) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        '3. Recipe Extracted Successfully!',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accentSage),
                      ),
                      const SizedBox(height: 12),
                      _buildExtractedPreviewCard(context, extraction.extractedRecipe!, isDark, primaryColor),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileUploadTab(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      _selectedFile != null ? Icons.check_circle : Icons.file_present_outlined,
                      color: _selectedFile != null ? AppTheme.accentSage : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedFile != null ? _selectedFile!.name : 'No file selected yet',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedFile != null
                      ? 'Size: ${((_selectedFileSize ?? 0) / 1024).toStringAsFixed(1)} KB'
                      : 'Upload a cookbook PDF, recipe HTML page, or text transcript',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_open, size: 18),
            label: Text(_selectedFile != null ? 'Change File' : 'Choose File'),
            onPressed: _pickFile,
          ),
        ],
      ),
    );
  }

  Widget _buildUrlInputTab(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Recipe Web Address / URI',
              hintText: 'https://example.com/recipe-post',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Direct fetch and CORS proxy fallbacks are automatically handled.',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInputTab(bool isDark) {
    return TextField(
      controller: _textController,
      maxLines: 5,
      decoration: const InputDecoration(
        labelText: 'Paste Recipe Text or HTML source',
        hintText: 'Paste ingredients, cooking steps, or raw web page content here...',
      ),
    );
  }

  Widget _buildProviderChoiceChip({
    required AIServiceType type,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    required Color primaryColor,
  }) {
    final isSelected = _selectedProvider == type;
    return InkWell(
      onTap: () => setState(() => _selectedProvider = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2E3D59) : const Color(0xFFEFF6FF))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: isSelected ? primaryColor : Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isSelected ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineSpecificSettings(
    bool isDark,
    Color primaryColor,
    SettingsProvider settings,
    bool hasWebGpu,
    ExtractionProvider extraction,
  ) {
    if (_selectedProvider == AIServiceType.inBrowserWasm) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasWebGpu ? AppTheme.accentSage.withAlpha(38) : Colors.amber.withAlpha(38),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(hasWebGpu ? Icons.speed : Icons.warning_amber_outlined, size: 14, color: hasWebGpu ? AppTheme.accentSage : Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        hasWebGpu ? 'WebGPU Hardware Accelerated' : 'WebGPU Disabled (WASM Fallback Active)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasWebGpu ? AppTheme.accentSage : Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Preload Model'),
                  onPressed: () => extraction.prepareWasmModel(_selectedWasmModel),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedWasmModel,
              decoration: const InputDecoration(labelText: 'In-Browser Model (WASM / WebGPU)'),
              items: AIConfig.wasmModelOptions.map((opt) {
                return DropdownMenuItem(
                  value: opt['id'],
                  child: Text('${opt['name']} (${opt['size']})'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedWasmModel = val);
              },
            ),
          ],
        ),
      );
    } else if (_selectedProvider == AIServiceType.localOllama) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: settings.aiConfig.ollamaUrl,
                decoration: const InputDecoration(labelText: 'Ollama Host URL'),
                onChanged: (val) => settings.updateAIConfig(settings.aiConfig.copyWith(ollamaUrl: val)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedOllamaModel,
                decoration: const InputDecoration(labelText: 'Ollama Model'),
                items: AIConfig.ollamaModelOptions.map((opt) {
                  return DropdownMenuItem(value: opt['id'], child: Text(opt['name']!));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedOllamaModel = val);
                },
              ),
            ),
          ],
        ),
      );
    } else if (_selectedProvider == AIServiceType.remoteGemini) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                initialValue: settings.aiConfig.geminiApiKey,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Google Gemini API Key',
                  hintText: 'AIzaSy...',
                ),
                onChanged: (val) => settings.updateAIConfig(settings.aiConfig.copyWith(geminiApiKey: val)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: settings.aiConfig.geminiModel,
                decoration: const InputDecoration(labelText: 'Model'),
                items: const [
                  DropdownMenuItem(value: 'gemini-1.5-flash', child: Text('Gemini 1.5 Flash')),
                  DropdownMenuItem(value: 'gemini-2.0-flash', child: Text('Gemini 2.0 Flash')),
                  DropdownMenuItem(value: 'gemini-1.5-pro', child: Text('Gemini 1.5 Pro')),
                ],
                onChanged: (val) {
                  if (val != null) settings.updateAIConfig(settings.aiConfig.copyWith(geminiModel: val));
                },
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: settings.aiConfig.openAiUrl,
                    decoration: const InputDecoration(labelText: 'API Base URL'),
                    onChanged: (val) => settings.updateAIConfig(settings.aiConfig.copyWith(openAiUrl: val)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: settings.aiConfig.openAiApiKey,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'API Key (Optional for local)'),
                    onChanged: (val) => settings.updateAIConfig(settings.aiConfig.copyWith(openAiApiKey: val)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: settings.aiConfig.openAiModel,
              decoration: const InputDecoration(
                labelText: 'Model Name',
                hintText: 'ibm/granite-3-8b-instruct or google/gemma-2-9b-it',
              ),
              onChanged: (val) => settings.updateAIConfig(settings.aiConfig.copyWith(openAiModel: val)),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildExtractedPreviewCard(BuildContext context, Recipe recipe, bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentSage.withAlpha(76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  recipe.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentSage, foregroundColor: Colors.white),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Review & Save to Git Repo'),
                onPressed: () {
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => RecipeEditorDialog(recipe: recipe),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text('📁 Category: ${recipe.category}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text('⏱️ Prep: ${recipe.prepTime ?? "15"}m', style: const TextStyle(fontSize: 12)),
              Text('🔥 Cook: ${recipe.cookTime ?? "20"}m', style: const TextStyle(fontSize: 12)),
              Text('🥗 ${recipe.ingredients.length} Ingredients', style: const TextStyle(fontSize: 12)),
              Text('📋 ${recipe.instructions.length} Steps', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
