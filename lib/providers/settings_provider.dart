import 'package:flutter/material.dart';
import '../models/git_repo_config.dart';
import '../models/ai_config.dart';
import '../services/storage_service.dart';
import '../services/github_service.dart';

class SettingsProvider with ChangeNotifier {
  GitRepoConfig _gitConfig = const GitRepoConfig();
  AIConfig _aiConfig = const AIConfig();
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isVerifyingGit = false;
  String? _gitAuthUser;
  String? _gitAuthError;

  GitRepoConfig get gitConfig => _gitConfig;
  AIConfig get aiConfig => _aiConfig;
  ThemeMode get themeMode => _themeMode;
  bool get isVerifyingGit => _isVerifyingGit;
  String? get gitAuthUser => _gitAuthUser;
  String? get gitAuthError => _gitAuthError;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _gitConfig = await StorageService.loadGitConfig();
    _aiConfig = await StorageService.loadAIConfig();
    final themeStr = await StorageService.loadThemeMode();
    if (themeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();

    if (_gitConfig.hasToken) {
      verifyGitToken();
    }
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    StorageService.saveThemeMode(mode.name);
  }

  Future<void> updateGitConfig(GitRepoConfig newConfig) async {
    _gitConfig = newConfig;
    notifyListeners();
    await StorageService.saveGitConfig(newConfig);
    if (newConfig.hasToken) {
      await verifyGitToken();
    }
  }

  Future<void> updateAIConfig(AIConfig newConfig) async {
    _aiConfig = newConfig;
    notifyListeners();
    await StorageService.saveAIConfig(newConfig);
  }

  Future<void> verifyGitToken() async {
    if (!_gitConfig.hasToken) {
      _gitAuthUser = null;
      _gitAuthError = null;
      notifyListeners();
      return;
    }

    _isVerifyingGit = true;
    _gitAuthError = null;
    notifyListeners();

    try {
      final user = await GitHubService.verifyToken(_gitConfig.token);
      _gitAuthUser = user['login'] as String?;
      _gitAuthError = null;
    } catch (e) {
      _gitAuthError = e.toString().replaceAll('Exception:', '').trim();
      _gitAuthUser = null;
    } finally {
      _isVerifyingGit = false;
      notifyListeners();
    }
  }
}
