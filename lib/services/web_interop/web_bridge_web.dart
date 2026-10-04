import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop' as js;
import 'dart:js_interop_unsafe' as jsu;
import 'package:web/web.dart' as web;

class WebBridge {
  static bool isWebGpuSupported() {
    try {
      final jsWindow = web.window as js.JSObject;
      if (jsu.JSObjectUnsafeUtilExtension(jsWindow).has('chefWebLLM')) {
        final chefObj = jsu.JSObjectUnsafeUtilExtension(jsWindow).getProperty('chefWebLLM'.toJS) as js.JSObject;
        final res = jsu.JSObjectUnsafeUtilExtension(chefObj).callMethod('isWebGPUSupported'.toJS) as js.JSBoolean;
        return res.toDart;
      }
    } catch (_) {}
    return false;
  }

  static Future<String?> extractTextFromPdf(Uint8List bytes) async {
    try {
      final jsWindow = web.window as js.JSObject;
      if (jsu.JSObjectUnsafeUtilExtension(jsWindow).has('extractTextFromPdfBytes')) {
        final jsArray = bytes.toJS;
        final promise = jsu.JSObjectUnsafeUtilExtension(jsWindow).callMethod(
          'extractTextFromPdfBytes'.toJS,
          jsArray,
        ) as js.JSPromise;
        final result = await promise.toDart;
        return (result as js.JSString).toDart;
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> extractTextFromHtml(String html) async {
    try {
      final jsWindow = web.window as js.JSObject;
      if (jsu.JSObjectUnsafeUtilExtension(jsWindow).has('extractTextFromHtml')) {
        final result = jsu.JSObjectUnsafeUtilExtension(jsWindow).callMethod(
          'extractTextFromHtml'.toJS,
          html.toJS,
        ) as js.JSString;
        return result.toDart;
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> fetchUrlContent(String url) async {
    try {
      final jsWindow = web.window as js.JSObject;
      if (jsu.JSObjectUnsafeUtilExtension(jsWindow).has('fetchUrlContent')) {
        final promise = jsu.JSObjectUnsafeUtilExtension(jsWindow).callMethod(
          'fetchUrlContent'.toJS,
          url.toJS,
        ) as js.JSPromise;
        final result = await promise.toDart;
        return (result as js.JSString).toDart;
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> isModelDownloaded(String modelId) async {
    try {
      final jsWindow = web.window as js.JSObject;
      if (jsu.JSObjectUnsafeUtilExtension(jsWindow).has('chefWebLLM')) {
        final chefObj = jsu.JSObjectUnsafeUtilExtension(jsWindow).getProperty('chefWebLLM'.toJS) as js.JSObject;
        if (jsu.JSObjectUnsafeUtilExtension(chefObj).has('isModelDownloaded')) {
          final promise = jsu.JSObjectUnsafeUtilExtension(chefObj).callMethod(
            'isModelDownloaded'.toJS,
            modelId.toJS,
          ) as js.JSPromise;
          final result = await promise.toDart;
          return (result as js.JSBoolean).toDart;
        }
      }
    } catch (_) {}
    return false;
  }

  static Future<List<String>> getDownloadedModels([List<String>? knownModelIds]) async {
    try {
      final jsWindow = web.window as js.JSObject;
      if (jsu.JSObjectUnsafeUtilExtension(jsWindow).has('chefWebLLM')) {
        final chefObj = jsu.JSObjectUnsafeUtilExtension(jsWindow).getProperty('chefWebLLM'.toJS) as js.JSObject;
        if (jsu.JSObjectUnsafeUtilExtension(chefObj).has('getDownloadedModels')) {
          final jsKnown = (knownModelIds ?? []).map((e) => e.toJS).toList().toJS;
          final promise = jsu.JSObjectUnsafeUtilExtension(chefObj).callMethod(
            'getDownloadedModels'.toJS,
            jsKnown,
          ) as js.JSPromise;
          final result = await promise.toDart;
          final jsArray = result as js.JSArray;
          final list = <String>[];
          for (int i = 0; i < jsArray.length; i++) {
            final item = jsArray[i];
            if (item != null) {
              list.add((item as js.JSString).toDart);
            }
          }
          return list;
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> deleteDownloadedModel(String modelId) async {
    try {
      final jsWindow = web.window as js.JSObject;
      if (jsu.JSObjectUnsafeUtilExtension(jsWindow).has('chefWebLLM')) {
        final chefObj = jsu.JSObjectUnsafeUtilExtension(jsWindow).getProperty('chefWebLLM'.toJS) as js.JSObject;
        if (jsu.JSObjectUnsafeUtilExtension(chefObj).has('deleteDownloadedModel')) {
          final promise = jsu.JSObjectUnsafeUtilExtension(chefObj).callMethod(
            'deleteDownloadedModel'.toJS,
            modelId.toJS,
          ) as js.JSPromise;
          final result = await promise.toDart;
          return (result as js.JSBoolean).toDart;
        }
      }
    } catch (_) {}
    return false;
  }

  static Future<Map<String, dynamic>?> pickModelFile([String? modelId]) async {
    try {
      final jsWindow = web.window as js.JSObject;
      if (jsu.JSObjectUnsafeUtilExtension(jsWindow).has('chefWebLLM')) {
        final chefObj = jsu.JSObjectUnsafeUtilExtension(jsWindow).getProperty('chefWebLLM'.toJS) as js.JSObject;
        if (jsu.JSObjectUnsafeUtilExtension(chefObj).has('pickModelFile')) {
          final arg = modelId != null ? modelId.toJS : ''.toJS;
          final promise = jsu.JSObjectUnsafeUtilExtension(chefObj).callMethod(
            'pickModelFile'.toJS,
            arg,
          ) as js.JSPromise;
          final result = await promise.toDart;
          if (result != null) {
            final obj = result as js.JSObject;
            final name = (jsu.JSObjectUnsafeUtilExtension(obj).getProperty('name'.toJS) as js.JSString).toDart;
            final url = (jsu.JSObjectUnsafeUtilExtension(obj).getProperty('url'.toJS) as js.JSString).toDart;
            final size = (jsu.JSObjectUnsafeUtilExtension(obj).getProperty('size'.toJS) as js.JSNumber).toDartInt;
            return {'name': name, 'url': url, 'size': size};
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static bool registerModelFileUrl(String modelId, String url) {
    try {
      final jsWindow = web.window as js.JSObject;
      if (jsu.JSObjectUnsafeUtilExtension(jsWindow).has('chefWebLLM')) {
        final chefObj = jsu.JSObjectUnsafeUtilExtension(jsWindow).getProperty('chefWebLLM'.toJS) as js.JSObject;
        if (jsu.JSObjectUnsafeUtilExtension(chefObj).has('registerModelFileUrl')) {
          final res = jsu.JSObjectUnsafeUtilExtension(chefObj).callMethod(
            'registerModelFileUrl'.toJS,
            modelId.toJS,
            url.toJS,
          ) as js.JSBoolean;
          return res.toDart;
        }
      }
    } catch (_) {}
    return false;
  }

  static Future<void> loadWebLlmModel({
    required String modelId,
    bool fromDiskOnly = false,
    required void Function(double progress, String status) onProgress,
  }) async {
    final jsWindow = web.window as js.JSObject;
    if (!jsu.JSObjectUnsafeUtilExtension(jsWindow).has('chefWebLLM')) {
      throw Exception('chefWebLLM bridge not found in page.');
    }

    final chefObj = jsu.JSObjectUnsafeUtilExtension(jsWindow).getProperty('chefWebLLM'.toJS) as js.JSObject;

    final hasWebGpu = (jsu.JSObjectUnsafeUtilExtension(chefObj).callMethod('isWebGPUSupported'.toJS) as js.JSBoolean).toDart;
    if (!hasWebGpu) {
      onProgress(0.5, 'WebGPU not detected; lightweight In-Browser WASM mode active...');
      await Future.delayed(const Duration(milliseconds: 400));
      onProgress(1.0, 'Ready (WASM Heuristic Fallback)');
      return;
    }

    final jsCallback = (js.JSNumber progress, js.JSString text) {
      onProgress(progress.toDartDouble, text.toDart);
    }.toJS;

    final promise = jsu.JSObjectUnsafeUtilExtension(chefObj).callMethod(
      'loadModel'.toJS,
      modelId.toJS,
      jsCallback,
      fromDiskOnly.toJS,
    ) as js.JSPromise;

    await promise.toDart;
    onProgress(1.0, fromDiskOnly ? 'Model loaded from disk into WebGPU memory' : 'Model loaded successfully into WebGPU memory');
  }

  static Future<String?> generateWebLlm({
    required String prompt,
    String? systemPrompt,
  }) async {
    try {
      final jsWindow = web.window as js.JSObject;
      final chefObj = jsu.JSObjectUnsafeUtilExtension(jsWindow).getProperty('chefWebLLM'.toJS) as js.JSObject;

      final engineVal = jsu.JSObjectUnsafeUtilExtension(chefObj).getProperty('engine'.toJS);
      if (engineVal != null && !engineVal.isUndefined && !engineVal.isNull) {
        final promise = jsu.JSObjectUnsafeUtilExtension(chefObj).callMethod(
          'generate'.toJS,
          prompt.toJS,
          (systemPrompt ?? '').toJS,
          (0.2).toJS,
        ) as js.JSPromise;

        final result = await promise.toDart;
        return (result as js.JSString).toDart;
      }
    } catch (_) {}
    return null;
  }

  static bool downloadBlob(String filename, String content) {
    try {
      final bytes = utf8.encode(content);
      final blob = web.Blob([bytes.toJS].toJS);
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;
      anchor.download = filename;
      anchor.click();
      web.URL.revokeObjectURL(url);
      return true;
    } catch (_) {
      return false;
    }
  }
}
