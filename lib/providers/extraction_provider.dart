import 'package:flutter/foundation.dart';
import '../models/ai_config.dart';
import '../models/recipe.dart';
import '../models/recipe_validation_result.dart';
import '../services/ai_service.dart';
import '../services/content_extractor_service.dart';
import '../services/in_browser_wasm_service.dart';

class ExtractionProvider with ChangeNotifier {
  bool _isExtracting = false;
  double _progress = 0.0;
  String _statusMessage = '';
  Recipe? _extractedRecipe;
  RecipeValidationResult? _validationResult;
  String? _errorMessage;

  String _inputMode = 'url'; // 'file', 'url', 'text'
  String _rawSourcePreview = '';
  String _detectedUrl = '';
  List<String> _downloadedModels = [];

  bool get isExtracting => _isExtracting;
  double get progress => _progress;
  String get statusMessage => _statusMessage;
  Recipe? get extractedRecipe => _extractedRecipe;
  RecipeValidationResult? get validationResult => _validationResult;
  String? get errorMessage => _errorMessage;
  String get inputMode => _inputMode;
  String get rawSourcePreview => _rawSourcePreview;
  String get detectedUrl => _detectedUrl;
  List<String> get downloadedModels => _downloadedModels;

  ExtractionProvider() {
    refreshDownloadedModels();
  }

  bool isModelDownloaded(String modelId) => _downloadedModels.contains(modelId);

  Future<void> refreshDownloadedModels() async {
    _downloadedModels = await InBrowserWasmService.getDownloadedModels();
    notifyListeners();
  }

  void setInputMode(String mode) {
    _inputMode = mode;
    notifyListeners();
  }

  void clear() {
    _isExtracting = false;
    _progress = 0.0;
    _statusMessage = '';
    _extractedRecipe = null;
    _validationResult = null;
    _errorMessage = null;
    _rawSourcePreview = '';
    _detectedUrl = '';
    notifyListeners();
  }

  /// Automatically applies reasonableness fixes (deduplication, whitespace normalization, dropping hallucinated headers)
  void applyAutoFix() {
    if (_extractedRecipe != null) {
      _extractedRecipe = RecipeValidationResult.autoFix(_extractedRecipe!, rawSource: _rawSourcePreview);
      _validationResult = RecipeValidationResult.validate(_extractedRecipe!, rawSource: _rawSourcePreview);
      notifyListeners();
    }
  }

  /// Ensure In-Browser WASM model is ready if using InBrowser type
  Future<void> prepareWasmModel(String modelId, {bool fromDiskOnly = false}) async {
    if (InBrowserWasmService.isModelLoaded && InBrowserWasmService.loadedModelId == modelId) {
      return;
    }

    _isExtracting = true;
    _progress = 0.1;
    final isDownloaded = _downloadedModels.contains(modelId);
    _statusMessage = fromDiskOnly || isDownloaded
        ? 'Loading model from local disk storage ($modelId)...'
        : 'Initializing In-Browser WASM model ($modelId)...';
    notifyListeners();

    try {
      await InBrowserWasmService.loadModel(
        modelId: modelId,
        fromDiskOnly: fromDiskOnly,
        onProgress: (prog, status) {
          _progress = prog;
          _statusMessage = status;
          notifyListeners();
        },
      );
      await refreshDownloadedModels();
    } catch (e) {
      debugPrint('Model prepare error: $e');
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
    } finally {
      _isExtracting = false;
      notifyListeners();
    }
  }

  /// Delete a downloaded model from disk storage
  Future<void> deleteDownloadedModel(String modelId) async {
    await InBrowserWasmService.deleteDownloadedModel(modelId);
    await refreshDownloadedModels();
  }

  /// Pick model file (.task) directly from disk
  Future<Map<String, dynamic>?> pickModelFile([String? modelId]) async {
    final res = await InBrowserWasmService.pickModelFile(modelId);
    if (res != null) {
      await refreshDownloadedModels();
    }
    return res;
  }

  /// Extract from PDF bytes
  Future<void> extractFromPdf({
    required Uint8List bytes,
    required String fileName,
    required AIConfig config,
    String? categoryHint,
  }) async {
    _startExtraction('Parsing PDF document with PDF.js engine...');
    try {
      final text = await ContentExtractorService.extractTextFromPdf(bytes);
      _rawSourcePreview = text;
      _updateStatus(0.3, 'Extracted text from PDF (${text.length} chars). Sending to AI...');

      await _runAiExtraction(
        config: config,
        content: text,
        categoryHint: categoryHint,
        sourceUrl: 'Document: $fileName',
      );
    } catch (e) {
      _handleError('PDF extraction failed: $e');
    }
  }

  /// Extract from HTML text
  Future<void> extractFromHtml({
    required String htmlContent,
    required AIConfig config,
    String? categoryHint,
    String? sourceUrl,
  }) async {
    _startExtraction('Cleaning HTML and extracting article content...');
    try {
      final text = await ContentExtractorService.extractTextFromHtml(htmlContent);
      _rawSourcePreview = text;
      _updateStatus(0.3, 'Cleaned HTML content. Dispatching to ${config.activeType.name} AI...');

      await _runAiExtraction(
        config: config,
        content: text,
        categoryHint: categoryHint,
        sourceUrl: sourceUrl,
      );
    } catch (e) {
      _handleError('HTML extraction failed: $e');
    }
  }

  /// Extract from Web URL
  Future<void> extractFromUrl({
    required String url,
    required AIConfig config,
    String? categoryHint,
  }) async {
    _detectedUrl = url;
    _startExtraction('Fetching recipe web page via direct/CORS proxy...');
    try {
      _updateStatus(0.2, 'Fetching $url...');
      final text = await ContentExtractorService.extractTextFromUrl(url);
      _rawSourcePreview = text;
      _updateStatus(0.4, 'Web content fetched (${text.length} characters). Prompting AI model...');

      await _runAiExtraction(
        config: config,
        content: text,
        categoryHint: categoryHint,
        sourceUrl: url,
      );
    } catch (e) {
      _handleError(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  /// Extract from Raw Text / Notes
  Future<void> extractFromText({
    required String text,
    required AIConfig config,
    String? categoryHint,
    String? sourceUrl,
  }) async {
    _startExtraction('Processing text content with AI...');
    try {
      _rawSourcePreview = text;
      _updateStatus(0.3, 'Sending text to AI model...');

      await _runAiExtraction(
        config: config,
        content: text,
        categoryHint: categoryHint,
        sourceUrl: sourceUrl,
      );
    } catch (e) {
      _handleError('Text extraction failed: $e');
    }
  }

  Future<void> _runAiExtraction({
    required AIConfig config,
    required String content,
    String? categoryHint,
    String? sourceUrl,
  }) async {
    // If in-browser WASM, handle progress callback
    if (config.activeType == AIServiceType.inBrowserWasm &&
        (!InBrowserWasmService.isModelLoaded || InBrowserWasmService.loadedModelId != config.wasmModelId)) {
      final isDownloaded = _downloadedModels.contains(config.wasmModelId);
      final initialMsg = config.loadWasmFromDisk || isDownloaded
          ? 'Loading previously downloaded ${config.wasmModelId} from disk...'
          : 'Loading ${config.wasmModelId} into browser WebGPU/WASM...';
      _updateStatus(0.4, initialMsg);

      await InBrowserWasmService.loadModel(
        modelId: config.wasmModelId,
        fromDiskOnly: config.loadWasmFromDisk,
        onProgress: (prog, status) {
          _progress = 0.4 + (prog * 0.4);
          _statusMessage = 'In-Browser WASM: $status';
          notifyListeners();
        },
      );
      await refreshDownloadedModels();
    }

    _updateStatus(0.85, 'AI is formulating MarkedChef recipe structure...');
    final recipe = await AIService.extractRecipe(
      config: config,
      rawContent: content,
      categoryHint: categoryHint,
      sourceUrl: sourceUrl,
    );

    _extractedRecipe = recipe;
    _validationResult = RecipeValidationResult.validate(recipe, rawSource: content);
    _progress = 1.0;
    if (_validationResult!.hasErrors) {
      _statusMessage = 'Extraction completed with critical issues. Please review.';
    } else if (_validationResult!.hasWarnings) {
      _statusMessage = 'Extraction completed with warnings. Please review.';
    } else {
      _statusMessage = 'Recipe extracted successfully!';
    }
    _isExtracting = false;
    notifyListeners();
  }

  void _startExtraction(String message) {
    _isExtracting = true;
    _progress = 0.1;
    _statusMessage = message;
    _extractedRecipe = null;
    _validationResult = null;
    _errorMessage = null;
    notifyListeners();
  }

  void _updateStatus(double prog, String message) {
    _progress = prog;
    _statusMessage = message;
    notifyListeners();
  }

  void _handleError(String err) {
    _isExtracting = false;
    _progress = 0.0;
    _errorMessage = err;
    _statusMessage = '';
    notifyListeners();
  }
}
