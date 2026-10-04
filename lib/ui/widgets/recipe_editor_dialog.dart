import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import 'commit_dialog.dart';
import 'git_settings_dialog.dart';

class _EditableRecipeItem {
  final Key key;
  final TextEditingController controller;
  final bool isHeader;

  _EditableRecipeItem({
    required this.key,
    required String text,
    this.isHeader = false,
  }) : controller = TextEditingController(text: text);

  void dispose() {
    controller.dispose();
  }
}

class RecipeEditorDialog extends StatefulWidget {
  final Recipe? recipe; // null if creating a new recipe
  final String? initialCategory;

  const RecipeEditorDialog({
    super.key,
    this.recipe,
    this.initialCategory,
  });

  @override
  State<RecipeEditorDialog> createState() => _RecipeEditorDialogState();
}

class _RecipeEditorDialogState extends State<RecipeEditorDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers
  late TextEditingController _titleController;
  late TextEditingController _categoryController;
  late TextEditingController _fileNameController;
  late TextEditingController _prepTimeController;
  late TextEditingController _cookTimeController;
  late TextEditingController _servingsController;
  late TextEditingController _creditController;
  late TextEditingController _sourceController;
  late TextEditingController _notesController;
  late TextEditingController _tagInputController;
  late TextEditingController _rawMarkdownController;

  String _difficulty = 'Easy';
  final List<String> _tags = [];
  final List<_EditableRecipeItem> _ingredients = [];
  final List<_EditableRecipeItem> _instructions = [];

  bool _isAutoSlug = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final r = widget.recipe;
    _isAutoSlug = r == null;

    _titleController = TextEditingController(text: r?.title ?? '');
    _categoryController = TextEditingController(text: r?.category ?? widget.initialCategory ?? 'Pasta');
    _fileNameController = TextEditingController(text: r?.fileName ?? 'new-recipe.md');
    _prepTimeController = TextEditingController(text: r?.prepTime?.toString() ?? '15');
    _cookTimeController = TextEditingController(text: r?.cookTime?.toString() ?? '20');
    _servingsController = TextEditingController(text: r?.servings?.toString() ?? '4');
    _creditController = TextEditingController(text: r?.credit ?? '');
    _sourceController = TextEditingController(text: r?.source ?? '');
    _notesController = TextEditingController(text: r?.notes ?? '');
    _tagInputController = TextEditingController();
    _rawMarkdownController = TextEditingController(text: r?.toMarkdown() ?? '');

    if (r != null) {
      _difficulty = r.difficulty ?? 'Easy';
      _tags.addAll(r.tags);
      for (final ing in r.ingredients) {
        _ingredients.add(_EditableRecipeItem(
          key: UniqueKey(),
          text: ing.text,
          isHeader: ing.isHeader,
        ));
      }
      for (final ins in r.instructions) {
        _instructions.add(_EditableRecipeItem(
          key: UniqueKey(),
          text: ins.step,
          isHeader: ins.isHeader,
        ));
      }
    } else {
      _tags.addAll(['dinner']);
      _ingredients.add(_EditableRecipeItem(
        key: UniqueKey(),
        text: '1 lb main ingredient',
        isHeader: false,
      ));
      _instructions.add(_EditableRecipeItem(
        key: UniqueKey(),
        text: 'Prepare all ingredients.',
        isHeader: false,
      ));
    }

    _titleController.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    if (_isAutoSlug) {
      final slug = Recipe.slugify(_titleController.text);
      if (slug.isNotEmpty) {
        _fileNameController.text = '$slug.md';
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _categoryController.dispose();
    _fileNameController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    _creditController.dispose();
    _sourceController.dispose();
    _notesController.dispose();
    _tagInputController.dispose();
    _rawMarkdownController.dispose();
    for (final item in _ingredients) {
      item.dispose();
    }
    for (final item in _instructions) {
      item.dispose();
    }
    super.dispose();
  }

  Recipe _buildRecipeFromForm() {
    var fn = _fileNameController.text.trim();
    if (!fn.endsWith('.md')) fn = '$fn.md';

    final fullPath = '${_categoryController.text.trim()}/$fn';

    return Recipe(
      id: widget.recipe?.id ?? fullPath,
      category: _categoryController.text.trim().isEmpty ? 'Main' : _categoryController.text.trim(),
      fileName: fn,
      sha: widget.recipe?.sha,
      title: _titleController.text.trim().isEmpty ? 'Untitled Recipe' : _titleController.text.trim(),
      prepTime: int.tryParse(_prepTimeController.text.trim()) ?? _prepTimeController.text.trim(),
      cookTime: int.tryParse(_cookTimeController.text.trim()) ?? _cookTimeController.text.trim(),
      servings: _servingsController.text.trim(),
      difficulty: _difficulty,
      tags: List.from(_tags),
      credit: _creditController.text.trim().isEmpty ? null : _creditController.text.trim(),
      source: _sourceController.text.trim().isEmpty ? null : _sourceController.text.trim(),
      ingredients: _ingredients
          .map((e) => RecipeIngredientItem(text: e.controller.text.trim(), isHeader: e.isHeader))
          .where((e) => e.text.isNotEmpty)
          .toList(),
      instructions: _instructions
          .map((e) => RecipeInstructionItem(step: e.controller.text.trim(), isHeader: e.isHeader))
          .where((e) => e.step.isNotEmpty)
          .toList(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      rawMarkdown: '',
    );
  }

  void _syncFormToRawMarkdown() {
    final recipe = _buildRecipeFromForm();
    _rawMarkdownController.text = recipe.toMarkdown();
  }

  void _syncRawMarkdownToForm() {
    try {
      final fullPath = '${_categoryController.text.trim()}/${_fileNameController.text.trim()}';
      final parsed = Recipe.fromMarkdown(fullPath, _rawMarkdownController.text, sha: widget.recipe?.sha);
      setState(() {
        _titleController.text = parsed.title;
        _categoryController.text = parsed.category;
        _fileNameController.text = parsed.fileName;
        _prepTimeController.text = parsed.prepTime?.toString() ?? '';
        _cookTimeController.text = parsed.cookTime?.toString() ?? '';
        _servingsController.text = parsed.servings?.toString() ?? '';
        _creditController.text = parsed.credit ?? '';
        _sourceController.text = parsed.source ?? '';
        _notesController.text = parsed.notes ?? '';
        _difficulty = parsed.difficulty ?? 'Easy';
        _tags.clear();
        _tags.addAll(parsed.tags);

        for (final item in _ingredients) {
          item.dispose();
        }
        _ingredients.clear();
        for (final ing in parsed.ingredients) {
          _ingredients.add(_EditableRecipeItem(
            key: UniqueKey(),
            text: ing.text,
            isHeader: ing.isHeader,
          ));
        }

        for (final item in _instructions) {
          item.dispose();
        }
        _instructions.clear();
        for (final ins in parsed.instructions) {
          _instructions.add(_EditableRecipeItem(
            key: UniqueKey(),
            text: ins.step,
            isHeader: ins.isHeader,
          ));
        }
      });
    } catch (_) {}
  }

  Future<void> _saveAndCommit() async {
    Recipe recipeToSave;
    if (_tabController.index == 1) {
      // From raw markdown
      final fullPath = '${_categoryController.text.trim()}/${_fileNameController.text.trim()}';
      recipeToSave = Recipe.fromMarkdown(fullPath, _rawMarkdownController.text, sha: widget.recipe?.sha);
    } else {
      recipeToSave = _buildRecipeFromForm();
    }

    final recipeProvider = context.read<RecipeProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final gitConfig = settingsProvider.gitConfig;

    // Check if user has Git credentials configured
    if (!gitConfig.hasToken) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.amber, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text('GitHub Credentials Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are currently in Read-Only mode for "${gitConfig.fullName}".',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 10),
              const Text(
                'A GitHub Personal Access Token (PAT) with "repo" permissions is required to commit and push recipes directly to the repository.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              const Text(
                'What would you like to do?',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text('Cancel'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Save Local Draft Only'),
              onPressed: () => Navigator.of(ctx).pop('draft'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Configure Git Settings'),
              onPressed: () => Navigator.of(ctx).pop('settings'),
            ),
          ],
        ),
      );

      if (action == 'settings' && mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => const GitSettingsDialog(),
        );
        if (settingsProvider.gitConfig.hasToken && mounted) {
          _saveAndCommit();
        }
        return;
      } else if (action == 'draft' && mounted) {
        await recipeProvider.saveLocalDraft(
          recipe: recipeToSave,
          config: gitConfig,
        );
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved "${recipeToSave.title}" to local browser cache (not pushed to GitHub).'),
              backgroundColor: Colors.teal,
            ),
          );
        }
        return;
      }
      return; // Cancelled
    }

    final defaultCommit = widget.recipe == null
        ? 'feat(${recipeToSave.category.toLowerCase()}): add ${recipeToSave.title} recipe'
        : 'chore(${recipeToSave.category.toLowerCase()}): update ${recipeToSave.title}';

    final commitMsg = await showDialog<String>(
      context: context,
      builder: (ctx) => CommitDialog(
        title: widget.recipe == null ? 'Commit New Recipe' : 'Commit Recipe Updates',
        defaultMessage: defaultCommit,
        actionLabel: 'Commit & Push',
      ),
    );

    if (commitMsg == null) return;

    try {
      if (widget.recipe == null) {
        await recipeProvider.createRecipe(
          recipe: recipeToSave,
          commitMessage: commitMsg,
          config: gitConfig,
        );
      } else {
        await recipeProvider.updateRecipe(
          recipe: recipeToSave,
          commitMessage: commitMsg,
          config: gitConfig,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully committed "${recipeToSave.title}" to repository!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.primaryAmber : AppTheme.primaryTerracotta;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 860),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Icon(widget.recipe == null ? Icons.add_circle_outline : Icons.edit_note_outlined, color: primaryColor),
                  const SizedBox(width: 10),
                  Text(
                    widget.recipe == null ? 'Add New Recipe' : 'Edit Recipe',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: isDark ? Colors.white : Colors.black,
                      unselectedLabelColor: Colors.grey,
                      onTap: (index) {
                        if (index == 1) {
                          _syncFormToRawMarkdown();
                        } else {
                          _syncRawMarkdownToForm();
                        }
                      },
                      tabs: const [
                        Tab(text: 'Visual Form Editor'),
                        Tab(text: 'Raw Markdown'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFormEditor(isDark, primaryColor),
                  _buildMarkdownEditor(isDark),
                ],
              ),
            ),

            // Bottom Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Text(
                    'Path: ${_categoryController.text}/${_fileNameController.text}',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black54),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: Text(widget.recipe == null ? 'Commit New Recipe' : 'Commit Changes'),
                    onPressed: _saveAndCommit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormEditor(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Title, Category, Filename
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Recipe Title *',
                    hintText: 'e.g. Spaghetti alla Carbonara',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Cuisine / Category *',
                    hintText: 'e.g. Pasta, Soup, Salad',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _fileNameController,
                  onChanged: (_) => _isAutoSlug = false,
                  decoration: const InputDecoration(
                    labelText: 'File Name',
                    hintText: 'e.g. carbonara.md',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 2: Prep Time, Cook Time, Servings, Difficulty
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _prepTimeController,
                  decoration: const InputDecoration(
                    labelText: 'Prep Time (mins)',
                    hintText: '10',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _cookTimeController,
                  decoration: const InputDecoration(
                    labelText: 'Cook Time (mins)',
                    hintText: '20',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _servingsController,
                  decoration: const InputDecoration(
                    labelText: 'Servings',
                    hintText: '4 or 2 - 3',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _difficulty,
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  items: const [
                    DropdownMenuItem(value: 'Easy', child: Text('Easy')),
                    DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'Hard', child: Text('Hard')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _difficulty = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 3: Credit, Source URL
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _creditController,
                  decoration: const InputDecoration(
                    labelText: 'Credit / Chef',
                    hintText: 'e.g. Ali, Julia, MarkedChef',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _sourceController,
                  decoration: const InputDecoration(
                    labelText: 'Source URL',
                    hintText: 'https://example.com/recipe',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tags Editor
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagInputController,
                  decoration: InputDecoration(
                    labelText: 'Add Tag',
                    hintText: 'Type tag and hit Enter',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addTag,
                    ),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _tags.map((tag) {
                    return Chip(
                      label: Text('#$tag'),
                      onDeleted: () => setState(() => _tags.remove(tag)),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Ingredients Editor
          Row(
            children: [
              const Text('Ingredients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text(
                '(drag to reorder)',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.title, size: 16),
                label: const Text('Add Section Header'),
                onPressed: () => _addIngredient(isHeader: true),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Ingredient'),
                onPressed: () => _addIngredient(isHeader: false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_ingredients.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No ingredients added yet. Click buttons above to add ingredients or headers.',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _ingredients.length,
              onReorderItem: _onReorderIngredients,
              proxyDecorator: (child, index, animation) => _buildProxyDecorator(child, index, animation, isDark),
              itemBuilder: (context, index) {
                final item = _ingredients[index];
                return _buildIngredientRow(context, index, item, isDark, primaryColor);
              },
            ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Instructions Editor
          Row(
            children: [
              const Text('Instructions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text(
                '(drag to reorder)',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.title, size: 16),
                label: const Text('Add Section Header'),
                onPressed: () => _addInstruction(isHeader: true),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Step'),
                onPressed: () => _addInstruction(isHeader: false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_instructions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No instructions added yet. Click buttons above to add steps or headers.',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _instructions.length,
              onReorderItem: _onReorderInstructions,
              proxyDecorator: (child, index, animation) => _buildProxyDecorator(child, index, animation, isDark),
              itemBuilder: (context, index) {
                final item = _instructions[index];
                return _buildInstructionRow(context, index, item, isDark, primaryColor);
              },
            ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Notes
          const Text('Chef Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '* Helpful variations\n* Cooking tips or substitutions',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProxyDecorator(Widget child, int index, Animation<double> animation, bool isDark) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Material(
          elevation: 6,
          shadowColor: Colors.black45,
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: child,
        );
      },
      child: child,
    );
  }

  Widget _buildIngredientRow(
    BuildContext context,
    int index,
    _EditableRecipeItem item,
    bool isDark,
    Color primaryColor,
  ) {
    if (item.isHeader) {
      return Container(
        key: item.key,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? primaryColor.withAlpha(25) : primaryColor.withAlpha(16),
          border: Border.all(color: primaryColor.withAlpha(80), width: 1.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Tooltip(
                message: 'Drag to reorder section header',
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.drag_indicator, size: 20, color: primaryColor),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: primaryColor.withAlpha(45),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.title, size: 14, color: primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    'HEADER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: item.controller,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: const InputDecoration(
                  hintText: 'Section Title (e.g. Dough, Sauce, Seasoning)',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
              tooltip: 'Remove section header',
              onPressed: () => _removeIngredient(index),
            ),
          ],
        ),
      );
    }

    return Container(
      key: item.key,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withAlpha(128) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Tooltip(
              message: 'Drag to reorder ingredient',
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ),
          ),
          Icon(
            Icons.check_box_outline_blank,
            size: 18,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: item.controller,
              decoration: const InputDecoration(
                hintText: 'e.g. 2 tbsp extra virgin olive oil',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
            tooltip: 'Remove ingredient',
            onPressed: () => _removeIngredient(index),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionRow(
    BuildContext context,
    int index,
    _EditableRecipeItem item,
    bool isDark,
    Color primaryColor,
  ) {
    if (item.isHeader) {
      return Container(
        key: item.key,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? primaryColor.withAlpha(25) : primaryColor.withAlpha(16),
          border: Border.all(color: primaryColor.withAlpha(80), width: 1.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Tooltip(
                message: 'Drag to reorder section header',
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.drag_indicator, size: 20, color: primaryColor),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: primaryColor.withAlpha(45),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.title, size: 14, color: primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    'HEADER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: item.controller,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: const InputDecoration(
                  hintText: 'Section Title (e.g. Dough, Sauce, Baking)',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
              tooltip: 'Remove section header',
              onPressed: () => _removeInstruction(index),
            ),
          ],
        ),
      );
    }

    final stepNum = _instructions.take(index + 1).where((s) => !s.isHeader).length;

    return Container(
      key: item.key,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withAlpha(128) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ReorderableDragStartListener(
              index: index,
              child: Tooltip(
                message: 'Drag to reorder step',
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: CircleAvatar(
              radius: 12,
              backgroundColor: primaryColor.withAlpha(45),
              child: Text(
                '$stepNum',
                style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: item.controller,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Step instructions...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
              tooltip: 'Remove step',
              onPressed: () => _removeInstruction(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownEditor(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: TextField(
        controller: _rawMarkdownController,
        maxLines: null,
        expands: true,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          hintText: 'Enter full MarkedChef recipe Markdown...',
        ),
      ),
    );
  }

  void _addTag() {
    final text = _tagInputController.text.trim().toLowerCase();
    if (text.isNotEmpty && !_tags.contains(text)) {
      setState(() {
        _tags.add(text);
        _tagInputController.clear();
      });
    }
  }

  void _addIngredient({required bool isHeader}) {
    setState(() {
      _ingredients.add(_EditableRecipeItem(
        key: UniqueKey(),
        text: '',
        isHeader: isHeader,
      ));
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      final removed = _ingredients.removeAt(index);
      removed.dispose();
    });
  }

  void _onReorderIngredients(int oldIndex, int newIndex) {
    setState(() {
      final item = _ingredients.removeAt(oldIndex);
      _ingredients.insert(newIndex, item);
    });
  }

  void _addInstruction({required bool isHeader}) {
    setState(() {
      _instructions.add(_EditableRecipeItem(
        key: UniqueKey(),
        text: '',
        isHeader: isHeader,
      ));
    });
  }

  void _removeInstruction(int index) {
    setState(() {
      final removed = _instructions.removeAt(index);
      removed.dispose();
    });
  }

  void _onReorderInstructions(int oldIndex, int newIndex) {
    setState(() {
      final item = _instructions.removeAt(oldIndex);
      _instructions.insert(newIndex, item);
    });
  }
}
