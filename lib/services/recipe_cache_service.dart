import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';

/// Service managing offline local caching and delta-sync metadata for recipes.
/// Uses SharedPreferences (backed by browser localStorage on web and platform storage on native).
class RecipeCacheService {
  static const String _manifestPrefix = 'md_chef_manifest_';
  static const String _blobPrefix = 'md_chef_blob_';
  static const String _lastSyncPrefix = 'md_chef_last_sync_';

  /// Generates a unique key identifying the repo and branch
  static String makeRepoKey(String owner, String repo, String branch) {
    final cleanOwner = owner.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    final cleanRepo = repo.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    final cleanBranch = branch.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    return '${cleanOwner}__${cleanRepo}__$cleanBranch';
  }

  /// Loads the manifest of cached recipes for a given repository.
  /// Returns a map of `repoPath -> sha`.
  static Future<Map<String, String>> loadManifest(String repoKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_manifestPrefix$repoKey');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (e) {
      debugPrint('Error loading recipe cache manifest: $e');
    }
    return <String, String>{};
  }

  /// Saves the updated manifest of `repoPath -> sha`
  static Future<void> _saveManifest(String repoKey, Map<String, String> manifest) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_manifestPrefix$repoKey', jsonEncode(manifest));
    } catch (e) {
      debugPrint('Error saving recipe cache manifest: $e');
    }
  }

  /// Loads all cached recipes for a given repository.
  static Future<List<Recipe>> loadCachedRecipes(String repoKey) async {
    final manifest = await loadManifest(repoKey);
    if (manifest.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final recipes = <Recipe>[];

    for (final entry in manifest.entries) {
      final path = entry.key;
      final sha = entry.value;
      final rawMarkdown = prefs.getString('$_blobPrefix${repoKey}_$path');

      if (rawMarkdown != null && rawMarkdown.isNotEmpty) {
        try {
          recipes.add(Recipe.fromMarkdown(path, rawMarkdown, sha: sha));
        } catch (e) {
          debugPrint('Error parsing cached recipe ($path): $e');
        }
      }
    }

    return recipes;
  }

  /// Caches or updates a single recipe
  static Future<void> saveRecipe(String repoKey, Recipe recipe) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final markdown = recipe.rawMarkdown.isNotEmpty ? recipe.rawMarkdown : recipe.toMarkdown();
      await prefs.setString('$_blobPrefix${repoKey}_${recipe.repoPath}', markdown);

      final manifest = await loadManifest(repoKey);
      manifest[recipe.repoPath] = recipe.sha ?? '';
      await _saveManifest(repoKey, manifest);
    } catch (e) {
      debugPrint('Error caching recipe (${recipe.repoPath}): $e');
    }
  }

  /// Caches a batch of recipes and updates the manifest atomically
  static Future<void> saveRecipesBatch(String repoKey, List<Recipe> recipes) async {
    if (recipes.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final manifest = await loadManifest(repoKey);

      for (final recipe in recipes) {
        final markdown = recipe.rawMarkdown.isNotEmpty ? recipe.rawMarkdown : recipe.toMarkdown();
        await prefs.setString('$_blobPrefix${repoKey}_${recipe.repoPath}', markdown);
        manifest[recipe.repoPath] = recipe.sha ?? '';
      }

      await _saveManifest(repoKey, manifest);
    } catch (e) {
      debugPrint('Error batch caching recipes: $e');
    }
  }

  /// Removes a deleted recipe from the cache and manifest
  static Future<void> deleteRecipe(String repoKey, String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_blobPrefix${repoKey}_$path');

      final manifest = await loadManifest(repoKey);
      if (manifest.containsKey(path)) {
        manifest.remove(path);
        await _saveManifest(repoKey, manifest);
      }
    } catch (e) {
      debugPrint('Error deleting recipe from cache ($path): $e');
    }
  }

  /// Clears all cached recipes and metadata for the given repository
  static Future<void> clearCache(String repoKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final manifest = await loadManifest(repoKey);

      for (final path in manifest.keys) {
        await prefs.remove('$_blobPrefix${repoKey}_$path');
      }

      await prefs.remove('$_manifestPrefix$repoKey');
      await prefs.remove('$_lastSyncPrefix$repoKey');
    } catch (e) {
      debugPrint('Error clearing recipe cache: $e');
    }
  }

  /// Gets the count of cached recipes for a repository
  static Future<int> getCachedCount(String repoKey) async {
    final manifest = await loadManifest(repoKey);
    return manifest.length;
  }

  /// Retrieves the last successful sync timestamp
  static Future<DateTime?> getLastSync(String repoKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_lastSyncPrefix$repoKey');
      if (raw != null && raw.isNotEmpty) {
        return DateTime.tryParse(raw);
      }
    } catch (_) {}
    return null;
  }

  /// Stores the last successful sync timestamp
  static Future<void> setLastSync(String repoKey, DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_lastSyncPrefix$repoKey', time.toIso8601String());
    } catch (_) {}
  }
}
