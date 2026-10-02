import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import 'commit_dialog.dart';

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
  final List<RecipeIngredientItem> _ingredients = [];
  final List<RecipeInstructionItem> _instructions = [];

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
      _ingredients.addAll(r.ingredients.map((e) => e.copyWith()));
      _instructions.addAll(r.instructions.map((e) => e.copyWith()));
    } else {
      _tags.addAll(['dinner']);
      _ingredients.add(RecipeIngredientItem(text: '1 lb main ingredient'));
      _instructions.add(RecipeInstructionItem(step: 'Prepare all ingredients.'));
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
      ingredients: List.from(_ingredients),
      instructions: List.from(_instructions),
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
        _ingredients.clear();
        _ingredients.addAll(parsed.ingredients);
        _instructions.clear();
        _instructions.addAll(parsed.instructions);
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
          config: settingsProvider.gitConfig,
        );
      } else {
        await recipeProvider.updateRecipe(
          recipe: recipeToSave,
          commitMessage: commitMsg,
          config: settingsProvider.gitConfig,
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _ingredients.length,
            itemBuilder: (context, index) {
              final item = _ingredients[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      item.isHeader ? Icons.label_important_outline : Icons.check_box_outline_blank,
                      size: 20,
                      color: item.isHeader ? primaryColor : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: item.text,
                        decoration: InputDecoration(
                          hintText: item.isHeader ? 'Section Title (e.g. Dressing, Sauce)' : 'e.g. 2 tbsp olive oil',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (val) {
                          _ingredients[index] = item.copyWith(text: val);
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                      onPressed: () => setState(() => _ingredients.removeAt(index)),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Instructions Editor
          Row(
            children: [
              const Text('Instructions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _instructions.length,
            itemBuilder: (context, index) {
              final step = _instructions[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: step.isHeader
                          ? Icon(
                              Icons.label_important_outline,
                              size: 20,
                              color: primaryColor,
                            )
                          : CircleAvatar(
                              radius: 12,
                              backgroundColor: primaryColor.withAlpha(51),
                              child: Text(
                                '${_instructions.take(index + 1).where((s) => !s.isHeader).length}',
                                style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: step.step,
                        maxLines: step.isHeader ? 1 : null,
                        decoration: InputDecoration(
                          hintText: step.isHeader ? 'Section Title (e.g. Dough, Sauce, Baking)' : 'Step instructions...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (val) {
                          _instructions[index] = step.copyWith(step: val);
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                      onPressed: () => setState(() => _instructions.removeAt(index)),
                    ),
                  ],
                ),
              );
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
      _ingredients.add(RecipeIngredientItem(text: '', isHeader: isHeader));
    });
  }

  void _addInstruction({required bool isHeader}) {
    setState(() {
      _instructions.add(RecipeInstructionItem(step: '', isHeader: isHeader));
    });
  }
}
