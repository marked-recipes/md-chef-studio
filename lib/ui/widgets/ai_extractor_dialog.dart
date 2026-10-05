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
  String _selectedWasmModel = 'gemma-4-E2B-it-web.task';
  bool _loadWasmFromDisk = true;
  String _selectedOllamaModel = 'gemma4';

  @override
  void initState() {
    super.initState();
    _inputTabController = TabController(length: 3, vsync: this);
    final aiConfig = context.read<SettingsProvider>().aiConfig;
    _selectedProvider = aiConfig.activeType;
    _selectedWasmModel = aiConfig.wasmModelId;
    _loadWasmFromDisk = aiConfig.loadWasmFromDisk;
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
      loadWasmFromDisk: _loadWasmFromDisk,
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
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('Extract with AI', style: TextStyle(fontSize: 15)),
                                onPressed: _triggerExtraction,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.edit_note),
                              label: const Text('Enter Manually', style: TextStyle(fontSize: 14)),
                              onPressed: () {
                                final category = _categoryController.text.trim().isEmpty ? 'Main' : _categoryController.text.trim();
                                Navigator.of(context).pop();
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => RecipeEditorDialog(
                                    recipe: Recipe(
                                      id: '$category/new-recipe.md',
                                      category: category,
                                      fileName: 'new-recipe.md',
                                      title: 'New Recipe',
                                      rawMarkdown: '',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.edit_note, size: 16),
                                label: const Text('Manually Enter Recipe in Editor'),
                                onPressed: () {
                                  final category = _categoryController.text.trim().isEmpty ? 'Main' : _categoryController.text.trim();
                                  Navigator.of(context).pop();
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (ctx) => RecipeEditorDialog(
                                      recipe: Recipe(
                                        id: '$category/new-recipe.md',
                                        category: category,
                                        fileName: 'new-recipe.md',
                                        title: 'New Recipe',
                                        rawMarkdown: '',
                                      ),
                                    ),
                                  );
                                },
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
                      Builder(
                        builder: (ctx) {
                          final hasIssues = extraction.validationResult != null && !extraction.validationResult!.isReasonable;
                          final hasErrors = extraction.validationResult?.hasErrors ?? false;
                          return Text(
                            hasErrors
                                ? '3. Recipe Extracted (Issues Found - Review Required)'
                                : hasIssues
                                    ? '3. Recipe Extracted (Quality Warnings - Review Advised)'
                                    : '3. Recipe Extracted Successfully!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: hasErrors
                                  ? Colors.redAccent
                                  : hasIssues
                                      ? Colors.orangeAccent
                                      : AppTheme.accentSage,
                            ),
                          );
                        },
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
      final isDownloaded = extraction.isModelDownloaded(_selectedWasmModel);

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
                  icon: Icon(isDownloaded ? Icons.storage : Icons.download, size: 16),
                  label: Text(isDownloaded ? 'Load from Disk' : 'Download & Load'),
                  onPressed: () => extraction.prepareWasmModel(
                    _selectedWasmModel,
                    fromDiskOnly: _loadWasmFromDisk || isDownloaded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Source Mode Selection: Load from Disk vs Download
            Row(
              children: [
                const Text('Model Source:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
              initialValue: _selectedWasmModel,
              decoration: const InputDecoration(labelText: 'In-Browser Model (WASM / WebGPU)'),
              items: AIConfig.wasmModelOptions.map((opt) {
                final isDown = extraction.isModelDownloaded(opt['id']!);
                final prefix = isDown ? '[On Disk]' : '[Download]';
                return DropdownMenuItem(
                  value: opt['id'],
                  child: Text('$prefix ${opt['name']} (${opt['size']})'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedWasmModel = val;
                    if (extraction.isModelDownloaded(val)) {
                      _loadWasmFromDisk = true;
                    }
                  });
                }
              },
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Select Model File (.task) from Disk'),
                  onPressed: () async {
                    final res = await extraction.pickModelFile(_selectedWasmModel);
                    if (res != null && res['name'] != null) {
                      final name = res['name'] as String;
                      setState(() {
                        _selectedWasmModel = name;
                        _loadWasmFromDisk = true;
                      });
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

            const SizedBox(height: 8),

            // Disk status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDownloaded
                    ? AppTheme.accentSage.withAlpha(25)
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isDownloaded ? Icons.check_circle_outline : Icons.cloud_download_outlined,
                    size: 15,
                    color: isDownloaded ? AppTheme.accentSage : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isDownloaded
                          ? 'Model is stored on local disk and ready for offline inference.'
                          : 'Model is not yet on disk. Will download on first use and save for offline loading.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDownloaded ? AppTheme.accentSage : (isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Quick select for previously downloaded models
            if (extraction.downloadedModels.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Previously Downloaded Models on Disk:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: extraction.downloadedModels.map((id) {
                  final opt = AIConfig.getWasmModelOption(id);
                  final name = opt?['name']?.split('(').first.trim() ?? id;
                  final isCurrent = _selectedWasmModel == id;
                  return ActionChip(
                    avatar: Icon(Icons.storage, size: 13, color: isCurrent ? primaryColor : Colors.grey),
                    label: Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    backgroundColor: isCurrent ? primaryColor.withAlpha(35) : null,
                    side: BorderSide(
                      color: isCurrent ? primaryColor : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedWasmModel = id;
                        _loadWasmFromDisk = true;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
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
    final extraction = context.watch<ExtractionProvider>();
    final validation = extraction.validationResult;

    final hasErrors = validation != null && validation.hasErrors;
    final hasWarnings = validation != null && validation.hasWarnings;
    final borderColor = hasErrors
        ? Colors.redAccent.withAlpha(140)
        : hasWarnings
            ? Colors.orangeAccent.withAlpha(140)
            : AppTheme.accentSage.withAlpha(76);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasErrors
                      ? Colors.orange[800]
                      : hasWarnings
                          ? Colors.orange[700]
                          : AppTheme.accentSage,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check, size: 18),
                label: Text(hasErrors || hasWarnings ? 'Review & Fix in Editor' : 'Review & Save to Git Repo'),
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
            spacing: 16,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_outlined, size: 14, color: isDark ? Colors.white70 : Colors.black87),
                  const SizedBox(width: 4),
                  Text('Category: ${recipe.category}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: isDark ? Colors.white70 : Colors.black87),
                  const SizedBox(width: 4),
                  Text('Prep: ${recipe.prepTime ?? "15"}m', style: const TextStyle(fontSize: 12)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department_outlined, size: 14, color: isDark ? Colors.white70 : Colors.black87),
                  const SizedBox(width: 4),
                  Text('Cook: ${recipe.cookTime ?? "20"}m', style: const TextStyle(fontSize: 12)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant_menu_outlined, size: 14, color: isDark ? Colors.white70 : Colors.black87),
                  const SizedBox(width: 4),
                  Text('${recipe.ingredients.where((i) => !i.isHeader).length} Ingredients', style: const TextStyle(fontSize: 12)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.checklist_outlined, size: 14, color: isDark ? Colors.white70 : Colors.black87),
                  const SizedBox(width: 4),
                  Text('${recipe.instructions.where((s) => !s.isHeader).length} Steps', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),

          // Reasonableness Checks Banner
          if (validation != null) ...[
            const SizedBox(height: 16),
            if (hasErrors || hasWarnings) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: hasErrors
                      ? Colors.red.withAlpha(isDark ? 35 : 20)
                      : Colors.orange.withAlpha(isDark ? 35 : 20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasErrors
                        ? Colors.redAccent.withAlpha(120)
                        : Colors.orangeAccent.withAlpha(120),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          hasErrors ? Icons.error_outline : Icons.warning_amber_rounded,
                          size: 20,
                          color: hasErrors ? Colors.redAccent : Colors.orangeAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasErrors
                                ? 'Reasonableness Check: Critical Issues Found'
                                : 'Reasonableness Check: ${validation.issueCount} Quality Warning${validation.issueCount > 1 ? "s" : ""}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: hasErrors ? Colors.redAccent : (isDark ? Colors.orange[300] : Colors.orange[900]),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: hasErrors ? Colors.redAccent : (isDark ? Colors.orange[300] : Colors.orange[900]),
                            side: BorderSide(color: hasErrors ? Colors.redAccent.withAlpha(120) : Colors.orangeAccent.withAlpha(120)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          icon: const Icon(Icons.auto_fix_high, size: 15),
                          label: const Text('Auto-Fix Issues', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            extraction.applyAutoFix();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Auto-fixed duplicate ingredients and steps.')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final err in validation.errors)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.cancel, size: 14, color: Colors.redAccent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                err,
                                style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final warn in validation.warnings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 14, color: isDark ? Colors.orange[200] : Colors.orange[900]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                warn,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.orange[200] : Colors.orange[900],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final notice in validation.notices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 14, color: isDark ? Colors.white60 : Colors.black54),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                notice,
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.accentSage.withAlpha(isDark ? 25 : 15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accentSage.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_rounded, size: 18, color: AppTheme.accentSage),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Passed all reasonableness checks: Ingredients, instructions, and uniqueness verified.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
