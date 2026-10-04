import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recipe_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'widgets/ai_extractor_dialog.dart';
import 'widgets/ai_settings_dialog.dart';
import 'widgets/category_filter_bar.dart';
import 'widgets/contribute_recipe_dialog.dart';
import 'widgets/git_branch_icon.dart';
import 'widgets/git_settings_dialog.dart';
import 'widgets/recipe_card.dart';
import 'widgets/recipe_editor_dialog.dart';
import 'widgets/recipe_view_pane.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Automatically load from local cache and check Git for changes in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      final recipes = context.read<RecipeProvider>();
      recipes.fetchFromGitHub(settings.gitConfig);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.primaryAmber : AppTheme.primaryTerracotta;

    final recipeProvider = context.watch<RecipeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    final recipes = recipeProvider.filteredRecipes;
    final selectedRecipe = recipeProvider.selectedRecipe;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, isDark ? Colors.orangeAccent : Colors.deepOrange],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        'MD Chef Studio',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentSage.withAlpha(38),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'WASM • AI',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentSage),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'MarkedChef Recipe Repository Manager',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Git Repo Button (Responsive)
          if (MediaQuery.of(context).size.width >= 1100)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: GitBranchIcon(
                  size: 16,
                  color: settingsProvider.gitConfig.hasToken ? AppTheme.accentSage : primaryColor,
                ),
                label: Row(
                  children: [
                    Text(
                      settingsProvider.gitConfig.fullName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      settingsProvider.gitConfig.hasToken ? '(Push Active)' : '(Read Only)',
                      style: TextStyle(
                        fontSize: 10,
                        color: settingsProvider.gitConfig.hasToken ? AppTheme.accentSage : Colors.grey,
                      ),
                    ),
                  ],
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const GitSettingsDialog(),
                  );
                },
              ),
            )
          else
            IconButton(
              tooltip: 'Git Settings: ${settingsProvider.gitConfig.fullName} (${settingsProvider.gitConfig.hasToken ? "Push Active" : "Read Only"})',
              icon: GitBranchIcon(
                size: 20,
                color: settingsProvider.gitConfig.hasToken ? AppTheme.accentSage : primaryColor,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => const GitSettingsDialog(),
                );
              },
            ),
          const SizedBox(width: 4),

          // Pull / Delta-Sync Button
          IconButton(
            tooltip: recipeProvider.isSyncing
                ? 'Checking Git repository for changes...'
                : (recipeProvider.syncStatusMessage ?? 'Sync with GitHub (checks for changes)'),
            icon: recipeProvider.isSyncing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                  )
                : const Icon(Icons.sync),
            onPressed: recipeProvider.isSyncing
                ? null
                : () => recipeProvider.fetchFromGitHub(settingsProvider.gitConfig),
          ),

          const SizedBox(width: 4),

          // AI Extractor Studio Button (Responsive)
          if (MediaQuery.of(context).size.width >= 900)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('AI Extractor'),
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const AiExtractorDialog(),
                );
              },
            )
          else
            IconButton(
              tooltip: 'AI Recipe Extractor',
              icon: Icon(Icons.auto_awesome, color: primaryColor),
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const AiExtractorDialog(),
                );
              },
            ),

          const SizedBox(width: 4),

          // Add New Recipe Button (Responsive)
          if (MediaQuery.of(context).size.width >= 900)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                side: BorderSide(color: primaryColor),
              ),
              icon: Icon(Icons.add, size: 16, color: primaryColor),
              label: Text('New Recipe', style: TextStyle(color: primaryColor)),
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => RecipeEditorDialog(initialCategory: recipeProvider.selectedCategory),
                );
              },
            )
          else
            IconButton(
              tooltip: 'New Recipe',
              icon: Icon(Icons.add_circle_outline, color: primaryColor),
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => RecipeEditorDialog(initialCategory: recipeProvider.selectedCategory),
                );
              },
            ),

          const SizedBox(width: 4),

          // AI Config Dialog
          IconButton(
            tooltip: 'AI Engine Settings',
            icon: const Icon(Icons.psychology_outlined),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const AiSettingsDialog(),
              );
            },
          ),

          // Help, Guides & Community Menu
          PopupMenuButton<String>(
            tooltip: 'Help, Guides & Community',
            icon: const Icon(Icons.help_outline),
            onSelected: (val) {
              int tabIndex = 0;
              if (val == 'contribute') tabIndex = 0;
              if (val == 'personal_repo') tabIndex = 1;
              if (val == 'standards') tabIndex = 2;
              if (val == 'about') tabIndex = 3;
              showDialog(
                context: context,
                builder: (ctx) => HelpGuidesDialog(initialTabIndex: tabIndex),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'contribute',
                child: Row(
                  children: [
                    Icon(Icons.volunteer_activism_outlined, size: 18, color: Colors.teal),
                    SizedBox(width: 10),
                    Text('Contribute Recipe (PR)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'personal_repo',
                child: Row(
                  children: [
                    Icon(Icons.auto_stories_outlined, size: 18, color: Colors.amber),
                    SizedBox(width: 10),
                    Text('Create Personal Cookbook Repo'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'standards',
                child: Row(
                  children: [
                    Icon(Icons.rule_outlined, size: 18, color: Colors.blueAccent),
                    SizedBox(width: 10),
                    Text('Recipe Format Standards'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18),
                    SizedBox(width: 10),
                    Text('About MarkedChef Studio'),
                  ],
                ),
              ),
            ],
          ),

          // Dark/Light Mode Switcher
          IconButton(
            tooltip: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () {
              settingsProvider.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
            },
          ),

          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Error notification banner if any
          if (recipeProvider.errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.red.withAlpha(38),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'GitHub notice: ${recipeProvider.errorMessage}. Displaying available local recipes.',
                      style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                  ),
                  TextButton(
                    onPressed: () => recipeProvider.fetchFromGitHub(settingsProvider.gitConfig),
                    child: const Text('Retry Fetch', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                  ),
                ],
              ),
            ),

          // Main Responsive Layout
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 768;

                if (!isWide) {
                  // Mobile or Narrow Screen: Tab/Switcher
                  return selectedRecipe == null
                      ? _buildRecipeListPane(context, isDark, primaryColor, recipeProvider, recipes)
                      : RecipeViewPane(recipe: selectedRecipe);
                }

                // Desktop / Tablet Split View
                return Row(
                  children: [
                    // Left Pane: Category Filter & Recipe List (Width ~360px)
                    SizedBox(
                      width: 360,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          border: Border(right: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                        ),
                        child: _buildRecipeListPane(context, isDark, primaryColor, recipeProvider, recipes),
                      ),
                    ),

                    // Right Pane: Active Recipe View
                    Expanded(
                      child: selectedRecipe != null
                          ? RecipeViewPane(recipe: selectedRecipe)
                          : _buildEmptyState(context, isDark, primaryColor),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeListPane(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    RecipeProvider recipeProvider,
    List<dynamic> recipes,
  ) {
    return Column(
      children: [
        const CategoryFilterBar(),
        // Count bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${recipes.length} ${recipes.length == 1 ? 'recipe' : 'recipes'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(width: 8),
              if (recipeProvider.isSyncing)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: primaryColor),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Checking git...',
                      style: TextStyle(fontSize: 11, color: primaryColor),
                    ),
                  ],
                )
              else if (recipeProvider.cachedRecipeCount > 0)
                Tooltip(
                  message: recipeProvider.syncStatusMessage ?? 'Stored in local offline cache',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.offline_bolt_outlined, size: 11, color: AppTheme.accentSage),
                        const SizedBox(width: 4),
                        Text(
                          'Cached',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accentSage),
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              if (recipeProvider.selectedCategory != 'All')
                GestureDetector(
                  onTap: () => recipeProvider.selectCategory('All'),
                  child: Text(
                    'Clear filter',
                    style: TextStyle(fontSize: 11, color: primaryColor),
                  ),
                ),
            ],
          ),
        ),
        // List of Recipe Cards
        Expanded(
          child: recipes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 40, color: Colors.grey.withAlpha(128)),
                        const SizedBox(height: 12),
                        const Text(
                          'No recipes found matching query',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = recipes[index];
                    final isSelected = recipeProvider.selectedRecipe?.repoPath == recipe.repoPath;
                    return RecipeCard(
                      recipe: recipe,
                      isSelected: isSelected,
                      onTap: () => recipeProvider.selectRecipe(recipe),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 64, color: primaryColor.withAlpha(100)),
          const SizedBox(height: 16),
          const Text(
            'Select a recipe from the sidebar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'or use the AI Recipe Extractor to convert PDFs, HTML, or URLs into MarkedChef format',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
          ),
        ],
      ),
    );
  }
}
