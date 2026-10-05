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
      isModelLoaded = false;
      loadedModelId = null;
      isLoadedFromDisk = false;
      rethrow;
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
        rethrow;
      }
    }

    throw Exception(
      'In-browser AI (WebGPU) is not available or failed to generate. '
      'Please ensure WebGPU is supported, switch to a local/remote AI provider in settings, '
      'or manually enter the recipe.',
    );
  }
}

