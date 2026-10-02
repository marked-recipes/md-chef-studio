import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'web_interop/web_bridge.dart';

class ContentExtractorService {
  /// Extract text from PDF bytes
  static Future<String> extractTextFromPdf(Uint8List bytes) async {
    if (kIsWeb) {
      final text = await WebBridge.extractTextFromPdf(bytes);
      if (text != null && text.isNotEmpty) return text;
    }

    // Fallback: extract ASCII / printable strings from PDF stream
    return _extractTextFromPdfBytesFallback(bytes);
  }

  /// Extract readable content from HTML string
  static Future<String> extractTextFromHtml(String html) async {
    if (kIsWeb) {
      final text = await WebBridge.extractTextFromHtml(html);
      if (text != null && text.isNotEmpty) return text;
    }

    // Fallback: regex stripping of HTML tags
    return _stripHtmlFallback(html);
  }

  /// Fetch and extract content from a URI (with CORS proxy fallback)
  static Future<String> extractTextFromUrl(String url) async {
    final cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      throw Exception('Invalid URL. Must begin with http:// or https://');
    }

    if (kIsWeb) {
      final text = await WebBridge.fetchUrlContent(cleanUrl);
      if (text != null && text.isNotEmpty) return text;
    }

    // Direct HTTP fetch fallback
    try {
      final res = await http.get(Uri.parse(cleanUrl));
      if (res.statusCode == 200) {
        return await extractTextFromHtml(res.body);
      }
    } catch (_) {}

    // Fallback via CORS proxy
    try {
      final proxyUrl = Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(cleanUrl)}');
      final res = await http.get(proxyUrl);
      if (res.statusCode == 200) {
        return await extractTextFromHtml(res.body);
      }
    } catch (_) {}

    throw Exception('Failed to load recipe URL. Please copy and paste the recipe text or HTML directly.');
  }

  /// Strip HTML fallback for non-web or JS failure
  static String _stripHtmlFallback(String html) {
    var text = html
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&#39;'), "'");
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
    return text.trim();
  }

  /// Basic PDF stream text recovery fallback
  static String _extractTextFromPdfBytesFallback(Uint8List bytes) {
    try {
      final latin1Str = latin1.decode(bytes, allowInvalid: true);
      final textMatches = RegExp(r'\(([\w\s,.\-!?:;/]+)\)\s*Tj').allMatches(latin1Str);
      if (textMatches.isNotEmpty) {
        return textMatches.map((m) => m.group(1)).join(' ');
      }
    } catch (_) {}
    return 'Could not parse PDF text with fallback parser. Please ensure PDF has selectable text.';
  }
}
