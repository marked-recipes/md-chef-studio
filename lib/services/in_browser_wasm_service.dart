import 'dart:async';
import 'package:flutter/foundation.dart';
import 'web_interop/web_bridge.dart';
import 'storage_service.dart';

class InBrowserWasmService {
  static bool isModelLoaded = false;
  static String? loadedModelId;
  static bool isLoadedFromDisk = false;

  /// Checks if browser supports WebGPU
  static bool isWebGPUSupported() {
    if (!kIsWeb) return false;
    return WebBridge.isWebGpuSupported();
  }

  /// Checks if a model is stored/cached on disk
  static Future<bool> isModelDownloaded(String modelId) async {
    if (kIsWeb) {
      final inBrowserCache = await WebBridge.isModelDownloaded(modelId);
      if (inBrowserCache) {
        await StorageService.saveDownloadedModel(modelId);
        return true;
      }
    }
    final savedModels = await StorageService.loadDownloadedModels();
    return savedModels.contains(modelId);
  }

  /// Returns list of all model IDs stored on disk
  static Future<List<String>> getDownloadedModels([List<String>? knownModelIds]) async {
    final results = <String>{};
    if (kIsWeb) {
      final webModels = await WebBridge.getDownloadedModels(knownModelIds);
      results.addAll(webModels);
    }
    final saved = await StorageService.loadDownloadedModels();
    results.addAll(saved);
    return results.toList();
  }

  /// Deletes a downloaded model from disk storage
  static Future<bool> deleteDownloadedModel(String modelId) async {
    bool ok = true;
    if (kIsWeb) {
      ok = await WebBridge.deleteDownloadedModel(modelId);
    }
    await StorageService.removeDownloadedModel(modelId);
    if (loadedModelId == modelId) {
      isModelLoaded = false;
      loadedModelId = null;
      isLoadedFromDisk = false;
    }
    return ok;
  }

  /// Allows user to select a model .task file from disk
  static Future<Map<String, dynamic>?> pickModelFile([String? modelId]) async {
    if (kIsWeb) {
      final res = await WebBridge.pickModelFile(modelId);
      if (res != null && res['name'] != null) {
        final name = res['name'] as String;
        await StorageService.saveDownloadedModel(name);
        if (modelId != null) {
          await StorageService.saveDownloadedModel(modelId);
        }
        return res;
      }
    }
    return null;
  }

  /// Loads an In-Browser LLM (Gemma 4 MediaPipe / WebGPU)
  /// If [fromDiskOnly] is true, it strictly loads from the locally downloaded disk cache.
  static Future<void> loadModel({
    required String modelId,
    bool fromDiskOnly = false,
    required void Function(double progress, String status) onProgress,
  }) async {
    if (!kIsWeb) {
      isModelLoaded = true;
      loadedModelId = modelId;
      isLoadedFromDisk = fromDiskOnly;
      await StorageService.saveDownloadedModel(modelId);
      onProgress(1.0, fromDiskOnly ? 'Ready (Loaded from disk - Simulated VM)' : 'Ready (Simulated VM Mode)');
      return;
    }

    final isDownloaded = await isModelDownloaded(modelId);
    if (fromDiskOnly && !isDownloaded) {
      throw Exception('Model "$modelId" is not saved on disk. Please download it first.');
    }

    if (isDownloaded) {
      onProgress(0.05, 'Loading model from local disk storage...');
    } else {
      onProgress(0.05, 'Checking browser WebGPU acceleration...');
    }

    try {
      await WebBridge.loadWebLlmModel(
        modelId: modelId,
        fromDiskOnly: fromDiskOnly,
        onProgress: onProgress,
      );
      isModelLoaded = true;
      loadedModelId = modelId;
      isLoadedFromDisk = isDownloaded;
      await StorageService.saveDownloadedModel(modelId);
    } catch (e) {
      debugPrint('WebLLM load failed: $e');
      if (fromDiskOnly) {
        rethrow;
      }
      isModelLoaded = true;
      loadedModelId = modelId;
      isLoadedFromDisk = false;
      onProgress(1.0, 'Ready (In-Browser rule-based WASM extractor active)');
    }
  }

  /// Generates recipe extraction using loaded in-browser model
  static Future<String> generate({
    required String prompt,
    String? systemPrompt,
  }) async {
    if (kIsWeb) {
      try {
        final res = await WebBridge.generateWebLlm(
          prompt: prompt,
          systemPrompt: systemPrompt,
        );
        if (res != null && res.isNotEmpty) return res;
      } catch (e) {
        debugPrint('WebLLM generate error: $e');
      }
    }

    // Fallback: In-browser heuristic recipe structuring if WebLLM GPU runtime wasn't activated
    return semanticRecipeExtractorFallback(prompt);
  }

  /// Rule-based fallback parser when WebGPU is disabled
  static String semanticRecipeExtractorFallback(String text) {
    final lines = text.split('\n');

    // 1. Extract metadata via regexes
    String title = 'Extracted Recipe';
    for (final l in lines) {
      final clean = l.trim();
      if (clean.isEmpty) continue;
      if (clean.startsWith('---') ||
          clean.startsWith('http') ||
          RegExp(r'^\d{1,2}/\d{1,2}/\d{2,4}').hasMatch(clean)) {
        continue;
      }
      if (clean.contains(' - ') && clean.length < 80) {
        title = clean.split(' - ').first.trim();
        break;
      } else if (clean.length > 5 &&
          clean.length < 70 &&
          !clean.contains(':') &&
          !clean.startsWith('-')) {
        title = clean;
        break;
      }
    }

    // Prep time
    int prepTime = 15;
    final prepMatch = RegExp(r'Prep\s*Time\s*[:\s]\s*(\d+)', caseSensitive: false).firstMatch(text);
    if (prepMatch != null) {
      prepTime = int.tryParse(prepMatch.group(1)!) ?? 15;
    }

    // Cook time
    int cookTime = 25;
    final cookMatch = RegExp(r'Cook\s*Time\s*[:\s]\s*(\d+)', caseSensitive: false).firstMatch(text);
    if (cookMatch != null) {
      cookTime = int.tryParse(cookMatch.group(1)!) ?? 25;
    }

    // Servings
    int servings = 4;
    final servMatch = RegExp(r'Servings\s*[:\s]\s*(\d+)(?:\s*-\s*(\d+))?', caseSensitive: false).firstMatch(text);
    if (servMatch != null) {
      servings = int.tryParse(servMatch.group(2) ?? servMatch.group(1)!) ?? 4;
    }

    // Author / credit
    String? credit;
    final authorMatch = RegExp(r'(?:Author|Credit)\s*[:\s]\s*([^\n\r]+)', caseSensitive: false).firstMatch(text);
    if (authorMatch != null) {
      credit = authorMatch.group(1)!.trim();
    }

    // Cuisine, Course, Keyword for tags
    final tags = <String>{};
    final cuisineMatch = RegExp(r'Cuisine\s*[:\s]\s*([^\n\r]+)', caseSensitive: false).firstMatch(text);
    if (cuisineMatch != null) {
      final cVal = cuisineMatch.group(1)!.trim().toLowerCase();
      if (cVal.contains('greek')) {
        tags.add('greek');
      } else if (cVal.contains('italian')) {
        tags.add('italian');
      } else {
        tags.add(cVal.replaceAll(' ', '-'));
      }
    }
    final courseMatch = RegExp(r'Course\s*[:\s]\s*([^\n\r]+)', caseSensitive: false).firstMatch(text);
    if (courseMatch != null) {
      tags.add(courseMatch.group(1)!.trim().toLowerCase().replaceAll(' ', '-'));
    }
    final kwMatch = RegExp(r'Keyword\s*[:\s]\s*([^\n\r]+)', caseSensitive: false).firstMatch(text);
    if (kwMatch != null) {
      final kws = kwMatch.group(1)!.split(RegExp(r'[,;]'));
      for (final k in kws) {
        final cleanK = k.trim().toLowerCase().replaceAll(' ', '-');
        if (cleanK.isNotEmpty) tags.add(cleanK);
      }
    }
    if (tags.isEmpty) {
      tags.addAll(['dinner', 'extracted']);
    }

    // 2. State-machine line parsing
    final ingredientBlocks = <String>[];
    final instructionBlocks = <String>[];
    final noteLines = <String>[];

    String currentSection = 'none'; // 'none', 'ingredients', 'instructions', 'notes', 'nutrition'

    final quantityStartRegex = RegExp(
      r'^(\d+|[½⅓⅔¼¾⅛⅜⅝⅞]|a\s+|an\s+|pinch|dash|to\s+taste|handful|drizzle|few|some)',
      caseSensitive: false,
    );
    final unitRegex = RegExp(
      r'\b(tbsp|tablespoon|tsp|teaspoon|cup|cups|g|gram|grams|kg|oz|ounce|ounces|lb|lbs|pound|pounds|ml|liter|liters|pinch|clove|cloves|can|cans|package|pkg|slice|slices|bunch|sprig|sprigs)\b',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Check for section transitions
      if (RegExp(r'^#*\s*ingredients\s*$', caseSensitive: false).hasMatch(line)) {
        currentSection = 'ingredients';
        continue;
      }
      if (RegExp(r'^#*\s*(?:instructions|directions|method|steps|preparation)\s*$', caseSensitive: false).hasMatch(line)) {
        currentSection = 'instructions';
        continue;
      }
      if (RegExp(r'^#*\s*(?:notes|chef(?:\x27s)?\s*notes|tips|variations)\s*$', caseSensitive: false).hasMatch(line)) {
        currentSection = 'notes';
        continue;
      }
      if (RegExp(r'^#*\s*(?:nutrition|nutrition\s*facts)\b', caseSensitive: false).hasMatch(line)) {
        currentSection = 'nutrition';
        continue;
      }

      // Ignore page markers, URLs, dates, repeated headers, page fractions
      if (line.startsWith('---') ||
          line.startsWith('http://') ||
          line.startsWith('https://') ||
          RegExp(r'^\d+\s*/\s*\d+$').hasMatch(line) ||
          RegExp(r'^\d{1,2}/\d{1,2}/\d{2,4}').hasMatch(line) ||
          (title.length > 5 && line.toLowerCase().contains(title.toLowerCase()))) {
        continue;
      }

      if (currentSection == 'nutrition') {
        continue;
      }

      if (currentSection == 'ingredients') {
        final isBulleted = RegExp(r'^[-*•]\s*').hasMatch(line);
        final startsWithQty = quantityStartRegex.hasMatch(line);
        final hasUnits = unitRegex.hasMatch(line);
        final isHeaderKeyword = RegExp(
          r'\b(sauce|topping|crust|dough|filling|dressing|garnishes?|glaze|marinade|dip|rub|batter|for\s+the)\b',
          caseSensitive: false,
        ).hasMatch(line) || line.endsWith(':');

        if (!startsWithQty && !hasUnits && !isBulleted && isHeaderKeyword && line.length < 50) {
          final groupTitle = line.replaceAll(':', '').trim();
          ingredientBlocks.add('### $groupTitle');
        } else {
          final item = line.replaceAll(RegExp(r'^[-*•]\s*'), '').trim();
          if (item.isNotEmpty && item.length < 150) {
            ingredientBlocks.add('- [ ] $item');
          }
        }
      } else if (currentSection == 'instructions') {
        final isNumbered = RegExp(r'^\s*(?:\d+[\.\)]|\(\d+\)|Step\s*\d+[:\.]?)\s*', caseSensitive: false).hasMatch(line);
        final isStageHeader = !isNumbered && (
          RegExp(r'^(?:make\s+the|assemble|prepare|bake|cook|for\s+the|to\s+make|step\s*\d+:|part\s*\d+:)\b', caseSensitive: false).hasMatch(line) ||
          (line.endsWith(':') && line.length < 50)
        );

        if (isStageHeader) {
          final stageTitle = line.replaceAll(':', '').trim();
          instructionBlocks.add('### $stageTitle');
        } else if (isNumbered) {
          final stepText = line.replaceAll(RegExp(r'^\s*(?:\d+[\.\)]|\(\d+\)|Step\s*\d+[:\.]?|[-*•])\s*', caseSensitive: false), '').trim();
          if (stepText.isNotEmpty) {
            instructionBlocks.add('- [ ] $stepText');
          }
        } else {
          // Continuation of previous step or unnumbered step
          if (instructionBlocks.isNotEmpty && instructionBlocks.last.startsWith('- [ ]')) {
            final last = instructionBlocks.removeLast();
            instructionBlocks.add('$last $line');
          } else if (line.length > 10) {
            instructionBlocks.add('- [ ] $line');
          }
        }
      } else if (currentSection == 'notes') {
        if (RegExp(r'\b(calories|foodbymaria\.com)\b', caseSensitive: false).hasMatch(line)) {
          continue;
        }
        final cleanNote = line.replaceAll(RegExp(r'^[-*•]\s*'), '').trim();
        if (cleanNote.isNotEmpty) {
          if (noteLines.isNotEmpty &&
              !noteLines.last.endsWith('.') &&
              !noteLines.last.endsWith('!') &&
              RegExp(r'^[a-z]').hasMatch(cleanNote)) {
            final last = noteLines.removeLast();
            noteLines.add('$last $cleanNote');
          } else {
            noteLines.add('* $cleanNote');
          }
        }
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('title: $title');
    buffer.writeln('prep_time: $prepTime');
    buffer.writeln('cook_time: $cookTime');
    buffer.writeln('servings: $servings');
    buffer.writeln('difficulty: Medium');
    buffer.writeln('tags:');
    for (final tag in tags) {
      buffer.writeln('  - $tag');
    }
    if (credit != null && credit.isNotEmpty) {
      buffer.writeln('credit: $credit');
    }
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('## Ingredients');
    buffer.writeln();

    if (ingredientBlocks.isNotEmpty) {
      for (final block in ingredientBlocks) {
        if (block.startsWith('###') && !buffer.toString().endsWith('## Ingredients\n\n')) {
          buffer.writeln();
        }
        buffer.writeln(block);
      }
    } else {
      buffer.writeln('- [ ] Ingredients to be added.');
    }

    buffer.writeln();
    buffer.writeln('## Instructions');
    buffer.writeln();

    if (instructionBlocks.isNotEmpty) {
      for (final block in instructionBlocks) {
        if (block.startsWith('###') && !buffer.toString().endsWith('## Instructions\n\n')) {
          buffer.writeln();
        }
        buffer.writeln(block);
      }
    } else {
      buffer.writeln('- [ ] Follow recipe instructions.');
    }

    if (noteLines.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Notes');
      buffer.writeln();
      for (final note in noteLines) {
        buffer.writeln(note);
      }
    }

    return buffer.toString().trim();
  }
}
