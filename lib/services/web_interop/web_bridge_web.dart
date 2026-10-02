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

  static Future<void> loadWebLlmModel({
    required String modelId,
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
    ) as js.JSPromise;

    await promise.toDart;
    onProgress(1.0, 'Model loaded successfully into WebGPU memory');
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
