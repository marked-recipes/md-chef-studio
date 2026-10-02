import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/git_repo_config.dart';
import '../models/ai_config.dart';

class StorageService {
  static const String _keyGitConfig = 'md_chef_git_config';
  static const String _keyAiConfig = 'md_chef_ai_config';
  static const String _keyThemeMode = 'md_chef_theme_mode';

  static Future<GitRepoConfig> loadGitConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyGitConfig);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return GitRepoConfig.fromJson(map);
      } catch (_) {}
    }
    return const GitRepoConfig();
  }

  static Future<void> saveGitConfig(GitRepoConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGitConfig, jsonEncode(config.toJson()));
  }

  static Future<AIConfig> loadAIConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyAiConfig);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return AIConfig.fromJson(map);
      } catch (_) {}
    }
    return const AIConfig();
  }

  static Future<void> saveAIConfig(AIConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiConfig, jsonEncode(config.toJson()));
  }

  static Future<String> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeMode) ?? 'system';
  }

  static Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode);
  }
}
