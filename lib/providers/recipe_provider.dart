import 'package:flutter/foundation.dart';
import '../models/git_repo_config.dart';
import '../models/recipe.dart';
import '../services/github_service.dart';
import '../services/recipe_cache_service.dart';

class RecipeProvider with ChangeNotifier {
  List<Recipe> _recipes = [];
  Recipe? _selectedRecipe;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _syncStatusMessage;
  int _cachedRecipeCount = 0;
  int _lastUpdatedCount = 0;
  String? _errorMessage;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String? _selectedTag;

  List<Recipe> get recipes => _recipes;
  Recipe? get selectedRecipe => _selectedRecipe;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get syncStatusMessage => _syncStatusMessage;
  int get cachedRecipeCount => _cachedRecipeCount;
  int get lastUpdatedCount => _lastUpdatedCount;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  String? get selectedTag => _selectedTag;

  RecipeProvider() {
    _loadSeedRecipes();
  }

  /// Categories found in the repository
  List<String> get categories {
    final set = <String>{};
    for (final r in _recipes) {
      if (r.category.isNotEmpty) set.add(r.category);
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  int getCountForCategory(String category) {
    if (category == 'All' || category.isEmpty) return _recipes.length;
    return _recipes.where((r) => r.category.toLowerCase() == category.toLowerCase()).length;
  }

  /// All unique tags across all recipes
  List<String> get allTags {
    final set = <String>{};
    for (final r in _recipes) {
      for (final t in r.tags) {
        if (t.isNotEmpty) set.add(t.toLowerCase());
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Filtered list based on category, search text, and tag
  List<Recipe> get filteredRecipes {
    return _recipes.where((recipe) {
      // Category filter
      if (_selectedCategory != 'All' && recipe.category.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }

      // Tag filter
      if (_selectedTag != null && _selectedTag!.isNotEmpty) {
        final hasTag = recipe.tags.any((t) => t.toLowerCase() == _selectedTag!.toLowerCase());
        if (!hasTag) return false;
      }

      // Search query filter
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final inTitle = recipe.title.toLowerCase().contains(q);
        final inCategory = recipe.category.toLowerCase().contains(q);
        final inTags = recipe.tags.any((t) => t.toLowerCase().contains(q));
        final inIngredients = recipe.ingredients.any((i) => i.text.toLowerCase().contains(q));
        if (!inTitle && !inCategory && !inTags && !inIngredients) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void selectRecipe(Recipe? recipe) {
    _selectedRecipe = recipe;
    notifyListeners();
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectTag(String? tag) {
    _selectedTag = tag;
    notifyListeners();
  }

  /// Toggle checkbox item state in the current recipe
  void toggleIngredient(Recipe recipe, int index) {
    if (index >= 0 && index < recipe.ingredients.length) {
      recipe.ingredients[index].isChecked = !recipe.ingredients[index].isChecked;
      notifyListeners();
    }
  }

  /// Toggle instruction step state
  void toggleInstruction(Recipe recipe, int index) {
    if (index >= 0 && index < recipe.instructions.length) {
      recipe.instructions[index].isCompleted = !recipe.instructions[index].isCompleted;
      notifyListeners();
    }
  }

  /// Load recipes from local cache first, then perform delta-sync with GitHub
  /// only downloading recipes that have new or modified Git SHAs.
  Future<void> fetchFromGitHub(GitRepoConfig config, {bool forceFull = false}) async {
    final repoKey = RecipeCacheService.makeRepoKey(config.owner, config.repo, config.branch);
    _errorMessage = null;

    // Phase 1: Instant load from local cache if available
    try {
      final cached = await RecipeCacheService.loadCachedRecipes(repoKey);
      _cachedRecipeCount = cached.length;
      _lastSyncTime = await RecipeCacheService.getLastSync(repoKey);

      if (cached.isNotEmpty) {
        _recipes = cached;
        _syncStatusMessage = 'Loaded ${cached.length} recipes from local storage';
        if (_selectedRecipe != null) {
          _selectedRecipe = _recipes.firstWhere(
            (r) => r.repoPath == _selectedRecipe!.repoPath,
            orElse: () => _recipes.first,
          );
        } else {
          _selectedRecipe = _recipes.first;
        }
        _isLoading = false;
        notifyListeners();
      } else {
        // First time loading this repo and no cache exists yet
        _isLoading = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cached recipes: $e');
    }

    // Phase 2: Check Git tree for changes (delta-sync)
    _isSyncing = true;
    _syncStatusMessage = 'Checking Git repository for changes...';
    notifyListeners();

    try {
      final treeItems = await GitHubService.fetchRecipeTree(config);

      // Map current recipes by repoPath -> sha
      final currentMap = <String, Recipe>{};
      for (final r in _recipes) {
        currentMap[r.repoPath] = r;
      }

      final toFetch = <Map<String, dynamic>>[];
      final remotePaths = <String>{};

      for (final item in treeItems) {
        final path = item['path'] as String;
        final sha = item['sha'] as String;
        remotePaths.add(path);

        final existing = currentMap[path];
        // If forceFull, or new file, or sha changed in git:
        if (forceFull || existing == null || existing.sha != sha) {
          toFetch.add(item);
        }
      }

      // Detect files that were deleted remotely
      final toDelete = currentMap.keys.where((p) => !remotePaths.contains(p)).toList();

      int fetchedCount = 0;
      if (toFetch.isNotEmpty) {
        _syncStatusMessage = 'Fetching ${toFetch.length} updated recipes...';
        notifyListeners();

        final fetchedRecipes = <Recipe>[];
        for (var i = 0; i < toFetch.length; i += 6) {
          final chunk = toFetch.sublist(i, (i + 6 > toFetch.length) ? toFetch.length : i + 6);
          final results = await Future.wait(chunk.map((item) async {
            try {
              final content = await GitHubService.fetchRecipeContent(config, item['path']!);
              return Recipe.fromMarkdown(
                item['path']!,
                content,
                sha: item['sha'],
              );
            } catch (e) {
              debugPrint('Failed to download recipe (${item['path']}): $e');
              return null;
            }
          }));

          for (final r in results) {
            if (r != null) {
              fetchedRecipes.add(r);
              fetchedCount++;
            }
          }
        }

        // Cache the newly fetched recipes
        await RecipeCacheService.saveRecipesBatch(repoKey, fetchedRecipes);

        // Merge into in-memory list
        for (final updated in fetchedRecipes) {
          final index = _recipes.indexWhere((r) => r.repoPath == updated.repoPath);
          if (index != -1) {
            _recipes[index] = updated;
          } else {
            _recipes.add(updated);
          }
        }
      }

      // Remove any remotely deleted recipes
      if (toDelete.isNotEmpty) {
        for (final delPath in toDelete) {
          _recipes.removeWhere((r) => r.repoPath == delPath);
          await RecipeCacheService.deleteRecipe(repoKey, delPath);
        }
      }

      // Sort by title
      _recipes.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

      _lastSyncTime = DateTime.now();
      await RecipeCacheService.setLastSync(repoKey, _lastSyncTime!);
      _cachedRecipeCount = _recipes.length;
      _lastUpdatedCount = fetchedCount;

      if (toFetch.isEmpty && toDelete.isEmpty) {
        _syncStatusMessage = 'Up to date (${_recipes.length} cached, 0 changes)';
      } else {
        _syncStatusMessage = 'Synced: $fetchedCount updated, ${toDelete.length} removed (${_recipes.length} cached)';
      }

      if (_selectedRecipe != null) {
        final matches = _recipes.where((r) => r.repoPath == _selectedRecipe!.repoPath);
        _selectedRecipe = matches.isNotEmpty ? matches.first : (_recipes.isNotEmpty ? _recipes.first : null);
      } else if (_recipes.isNotEmpty) {
        _selectedRecipe = _recipes.first;
      }
    } catch (e) {
      if (_recipes.isNotEmpty) {
        // Still keep viewing local cache if offline or GitHub API fails
        _syncStatusMessage = 'Offline: viewing ${_recipes.length} cached recipes';
      } else {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      }
    } finally {
      _isLoading = false;
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Create a new recipe and commit to GitHub
  Future<void> createRecipe({
    required Recipe recipe,
    required String commitMessage,
    required GitRepoConfig config,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final markdown = recipe.toMarkdown();
      recipe.rawMarkdown = markdown;

      if (!config.hasToken) {
        throw Exception(
          'A GitHub Personal Access Token is required to commit and push changes to ${config.fullName}. '
          'Please configure your token in Git Settings.',
        );
      }

      final res = await GitHubService.saveRecipe(
        config: config,
        path: recipe.repoPath,
        content: markdown,
        commitMessage: commitMessage.isNotEmpty ? commitMessage : 'feat: add ${recipe.title} recipe',
      );
      final newSha = res['content']?['sha'] as String?;
      recipe.sha = newSha;

      _recipes.removeWhere((r) => r.repoPath == recipe.repoPath);
      _recipes.insert(0, recipe);
      _selectedRecipe = recipe;

      final repoKey = RecipeCacheService.makeRepoKey(config.owner, config.repo, config.branch);
      await RecipeCacheService.saveRecipe(repoKey, recipe);
      _cachedRecipeCount = _recipes.length;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Saves a recipe to local browser cache only without pushing to GitHub
  Future<void> saveLocalDraft({
    required Recipe recipe,
    required GitRepoConfig config,
  }) async {
    final markdown = recipe.toMarkdown();
    recipe.rawMarkdown = markdown;

    final index = _recipes.indexWhere((r) => r.repoPath == recipe.repoPath);
    if (index != -1) {
      _recipes[index] = recipe;
    } else {
      _recipes.insert(0, recipe);
    }
    _selectedRecipe = recipe;

    final repoKey = RecipeCacheService.makeRepoKey(config.owner, config.repo, config.branch);
    await RecipeCacheService.saveRecipe(repoKey, recipe);
    _cachedRecipeCount = _recipes.length;
    notifyListeners();
  }

  /// Update an existing recipe and commit to GitHub
  Future<void> updateRecipe({
    required Recipe recipe,
    required String commitMessage,
    required GitRepoConfig config,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final markdown = recipe.toMarkdown();
      recipe.rawMarkdown = markdown;

      if (!config.hasToken) {
        throw Exception(
          'A GitHub Personal Access Token is required to commit and push changes to ${config.fullName}. '
          'Please configure your token in Git Settings.',
        );
      }

      final res = await GitHubService.saveRecipe(
        config: config,
        path: recipe.repoPath,
        content: markdown,
        sha: recipe.sha,
        commitMessage: commitMessage.isNotEmpty ? commitMessage : 'chore: update ${recipe.title} recipe',
      );
      final newSha = res['content']?['sha'] as String?;
      recipe.sha = newSha;

      final index = _recipes.indexWhere((r) => r.repoPath == recipe.repoPath);
      if (index != -1) {
        _recipes[index] = recipe;
      } else {
        _recipes.insert(0, recipe);
      }
      _selectedRecipe = recipe;

      final repoKey = RecipeCacheService.makeRepoKey(config.owner, config.repo, config.branch);
      await RecipeCacheService.saveRecipe(repoKey, recipe);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Delete a recipe from GitHub and local list
  Future<void> deleteRecipe({
    required Recipe recipe,
    required String commitMessage,
    required GitRepoConfig config,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!config.hasToken) {
        throw Exception(
          'A GitHub Personal Access Token is required to delete recipes from ${config.fullName}. '
          'Please configure your token in Git Settings.',
        );
      }

      await GitHubService.deleteRecipe(
        config: config,
        path: recipe.repoPath,
        sha: recipe.sha ?? '',
        commitMessage: commitMessage.isNotEmpty ? commitMessage : 'refactor: delete ${recipe.title} recipe',
      );

      _recipes.removeWhere((r) => r.repoPath == recipe.repoPath);
      if (_selectedRecipe?.repoPath == recipe.repoPath) {
        _selectedRecipe = _recipes.isNotEmpty ? _recipes.first : null;
      }

      final repoKey = RecipeCacheService.makeRepoKey(config.owner, config.repo, config.branch);
      await RecipeCacheService.deleteRecipe(repoKey, recipe.repoPath);
      _cachedRecipeCount = _recipes.length;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Clears the local offline cache for this repository
  Future<void> clearLocalCache(GitRepoConfig config) async {
    final repoKey = RecipeCacheService.makeRepoKey(config.owner, config.repo, config.branch);
    await RecipeCacheService.clearCache(repoKey);
    _cachedRecipeCount = 0;
    _lastSyncTime = null;
    _syncStatusMessage = 'Local cache cleared';
    notifyListeners();
  }

  /// Seed recipes from marked-recipes/recipes for instant offline showcase
  void _loadSeedRecipes() {
    const cacioEpepeMd = '''---
title: Cacio e Pepe
prep_time: 10
cook_time: 20
servings: 2 - 3
difficulty: Easy
tags:
  - italian
  - pasta
credit: Ali
source: https://www.gimmesomeoven.com/cacio-e-pepe/
---

## Ingredients

- [ ] 8 ounces uncooked pasta (I recommend bucatini)
- [ ] 2 tablespoons butter, diced into 1-tablespoon chunks*
- [ ] 1 teaspoon freshly-ground coarse black pepper*
- [ ] 2 ounces finely-grated Pecorino-Romano cheese

## Instructions

- [ ] Boil the pasta water. Fill a large stockpot about halfway full of water (roughly 3 quarts) and bring it to a rolling boil. Generously season the water with fine sea salt (about 2 tablespoons).
- [ ] Bloom the pepper. Meanwhile, as the pasta water heats, melt the butter in a large sauté pan (preferably nonstick) over medium heat. Add the pepper and let it cook for 30 seconds, then turn off the heat.
- [ ] Cook the pasta. Add the pasta to the boiling water and cook, stirring occasionally, until it is just barely al dente.
- [ ] Toss the pasta. Use tongs to quickly transfer the pasta directly to the sauté pan with the melted butter and pepper. Add 1/3 cup of the starchy pasta water to the pan and toss the pasta briefly to combine. Add in half of the cheese and toss to coat. Add remaining cheese and continue tossing until smooth and glossy.
- [ ] Serve. Serve the pasta immediately, garnished with an extra twist of black pepper and extra Pecorino.
''';

    const lemonOrzoSoupMd = '''---
title: Lemon Chicken Orzo Soup
prep_time: 10
cook_time: 25
servings: 6
difficulty: Medium
tags:
  - soup
  - chicken
  - comfort
credit: Julia
source: https://juliasalbum.com/lemon-chicken-orzo-soup/
---

## Ingredients

- [ ] 1 tablespoon olive oil
- [ ] 1 small onion diced
- [ ] 3 medium carrots peeled and thinly diced
- [ ] 2 small celery stalks chopped
- [ ] ½ teaspoon garlic powder
- [ ] ½ teaspoon onion powder
- [ ] 4 cloves garlic minced
- [ ] 7 cups chicken stock or broth
- [ ] 1 teaspoon fresh thyme
- [ ] 1 cups dry orzo
- [ ] 3 cups cooked shredded chicken
- [ ] 3 tablespoons cornstarch
- [ ] 3 cups baby spinach
- [ ] 1 large lemon juiced
- [ ] Salt and pepper to taste

### Garnish
- [ ] Chopped fresh parsley
- [ ] 2 sprigs fresh thyme
- [ ] 1 small lemon sliced

## Instructions

- [ ] Heat olive oil in a Dutch oven over medium heat. Add onion, carrots, celery, garlic powder, and onion powder. Season with salt and pepper. Cook for 5 minutes until softened. Add garlic during the last 2 minutes.
- [ ] Pour in chicken stock, scraping browned bits. Add thyme and bring to a simmer. Reserve 1/3 cup stock to cool.
- [ ] Stir in orzo and shredded chicken. Simmer for 8-10 minutes until orzo is al dente.
- [ ] Whisk cornstarch with reserved cooled stock to make a slurry. Pour into soup and stir to thicken.
- [ ] Simmer for 5 minutes, then fold in spinach and fresh lemon juice.
- [ ] Serve warm garnished with parsley and lemon slices.
''';

    const carbonaraMd = '''---
title: Spaghetti alla Carbonara
prep_time: 10
cook_time: 15
servings: 4
difficulty: Medium
tags:
  - pasta
  - italian
  - classic
credit: MarkedChef
source: https://github.com/marked-recipes/recipes
---

## Ingredients

- [ ] 400 grams spaghetti
- [ ] 150 grams guanciale (or pancetta), diced
- [ ] 4 large fresh egg yolks + 1 whole egg
- [ ] 100 grams freshly grated Pecorino Romano cheese
- [ ] Freshly cracked black pepper to taste
- [ ] Coarse sea salt for pasta water

## Instructions

- [ ] Bring a large pot of water to a boil and season lightly with salt. Cook spaghetti until al dente.
- [ ] While pasta cooks, brown the diced guanciale in a skillet over medium heat until crispy and fat is rendered. Remove from heat.
- [ ] In a bowl, whisk egg yolks, whole egg, grated Pecorino Romano, and abundant black pepper until a thick paste forms.
- [ ] Transfer cooked spaghetti directly into skillet with warm guanciale fat, tossing well.
- [ ] Off the heat, pour in egg and cheese mixture, adding 2-3 tablespoons of pasta water. Toss vigorously until a glossy, creamy sauce forms.
- [ ] Serve immediately topped with extra Pecorino and cracked black pepper.
''';

    _recipes = [
      Recipe.fromMarkdown('Pasta/cacio-e-pepe.md', cacioEpepeMd),
      Recipe.fromMarkdown('Soup/lemon-chicken-orzo-soup.md', lemonOrzoSoupMd),
      Recipe.fromMarkdown('Pasta/spaghetti-alla-carbonara.md', carbonaraMd),
    ];
    _selectedRecipe = _recipes.first;
  }
}
