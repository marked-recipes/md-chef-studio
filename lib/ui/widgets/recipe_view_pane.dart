import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/web_interop/web_bridge.dart';
import '../../theme/app_theme.dart';
import 'commit_dialog.dart';
import 'recipe_editor_dialog.dart';

class RecipeViewPane extends StatefulWidget {
  final Recipe recipe;

  const RecipeViewPane({super.key, required this.recipe});

  @override
  State<RecipeViewPane> createState() => _RecipeViewPaneState();
}

class _RecipeViewPaneState extends State<RecipeViewPane> {
  bool _showRawMarkdown = false;

  void _downloadMarkdownFile(Recipe recipe) {
    if (kIsWeb) {
      final ok = WebBridge.downloadBlob(recipe.fileName, recipe.toMarkdown());
      if (ok) return;
    }

    Clipboard.setData(ClipboardData(text: recipe.toMarkdown()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recipe Markdown copied to clipboard')),
    );
  }

  Future<void> _openSourceUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.primaryAmber : AppTheme.primaryTerracotta;
    final recipeProvider = context.watch<RecipeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    final nonHeaderSteps = widget.recipe.instructions.where((s) => !s.isHeader).toList();
    final completedSteps = nonHeaderSteps.where((s) => s.isCompleted).length;
    final totalSteps = nonHeaderSteps.length;
    final stepProgress = totalSteps > 0 ? completedSteps / totalSteps : 0.0;

    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Top Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Category & Path Breadcrumb
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(38),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.recipe.repoPath,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  if (widget.recipe.sha != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'SHA: ${widget.recipe.sha!.substring(0, 7)}',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
                    ),
                  ],
                  const SizedBox(width: 16),

                  // Toggle Markdown vs Visual
                  IconButton(
                    tooltip: _showRawMarkdown ? 'View Formatted Recipe' : 'View Raw Markdown',
                    icon: Icon(_showRawMarkdown ? Icons.menu_book_outlined : Icons.code_outlined),
                    onPressed: () => setState(() => _showRawMarkdown = !_showRawMarkdown),
                  ),

                  // Copy / Download Markdown
                  IconButton(
                    tooltip: 'Download .md file',
                    icon: const Icon(Icons.download_outlined),
                    onPressed: () => _downloadMarkdownFile(widget.recipe),
                  ),

                  const SizedBox(width: 8),

                  // Edit Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Recipe'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => RecipeEditorDialog(recipe: widget.recipe),
                      );
                    },
                  ),

                  const SizedBox(width: 8),

                  // Delete Button
                  IconButton(
                    tooltip: 'Delete Recipe from Repo',
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () async {
                      final confirmedMessage = await showDialog<String>(
                        context: context,
                        builder: (ctx) => CommitDialog(
                          title: 'Delete "${widget.recipe.title}"?',
                          defaultMessage: 'refactor: delete ${widget.recipe.title} recipe',
                          actionLabel: 'Confirm Delete',
                          isDestructive: true,
                        ),
                      );

                      if (confirmedMessage != null && context.mounted) {
                        try {
                          await recipeProvider.deleteRecipe(
                            recipe: widget.recipe,
                            commitMessage: confirmedMessage,
                            config: settingsProvider.gitConfig,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Deleted "${widget.recipe.title}"')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Main Recipe Content
          Expanded(
            child: _showRawMarkdown
                ? _buildRawMarkdownView(isDark)
                : _buildVisualCookingView(context, isDark, primaryColor, recipeProvider, completedSteps, totalSteps, stepProgress),
          ),
        ],
      ),
    );
  }

  Widget _buildRawMarkdownView(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: SelectableText(
        widget.recipe.toMarkdown(),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.5,
          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildVisualCookingView(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    RecipeProvider recipeProvider,
    int completedSteps,
    int totalSteps,
    double stepProgress,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                widget.recipe.title,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Metadata Pills (Prep, Cook, Servings, Difficulty)
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.recipe.prepTime != null && widget.recipe.prepTime.toString().isNotEmpty)
                    _buildMetaPill(
                      icon: Icons.timer_outlined,
                      label: 'Prep: ${widget.recipe.prepTime} min',
                      isDark: isDark,
                    ),
                  if (widget.recipe.cookTime != null && widget.recipe.cookTime.toString().isNotEmpty)
                    _buildMetaPill(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Cook: ${widget.recipe.cookTime} min',
                      isDark: isDark,
                    ),
                  if (widget.recipe.servings != null && widget.recipe.servings.toString().isNotEmpty)
                    _buildMetaPill(
                      icon: Icons.restaurant_outlined,
                      label: 'Serves: ${widget.recipe.servings}',
                      isDark: isDark,
                    ),
                  if (widget.recipe.difficulty != null && widget.recipe.difficulty!.isNotEmpty)
                    _buildMetaPill(
                      icon: Icons.speed_outlined,
                      label: widget.recipe.difficulty!,
                      isDark: isDark,
                      highlight: true,
                    ),
                  if (widget.recipe.credit != null && widget.recipe.credit!.isNotEmpty)
                    _buildMetaPill(
                      icon: Icons.person_outline,
                      label: 'Credit: ${widget.recipe.credit}',
                      isDark: isDark,
                    ),
                  if (widget.recipe.source != null && widget.recipe.source!.isNotEmpty)
                    InkWell(
                      onTap: () => _openSourceUrl(widget.recipe.source!),
                      child: _buildMetaPill(
                        icon: Icons.link_outlined,
                        label: 'Original Source',
                        isDark: isDark,
                        clickable: true,
                      ),
                    ),
                ],
              ),

              // Tags
              if (widget.recipe.tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.recipe.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Two-column or Sequential layout for Ingredients & Instructions
              LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth > 720;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ingredients (40% width)
                      Expanded(
                        flex: 4,
                        child: _buildIngredientsSection(isDark, primaryColor, recipeProvider),
                      ),
                      const SizedBox(width: 32),
                      // Instructions (60% width)
                      Expanded(
                        flex: 6,
                        child: _buildInstructionsSection(
                          isDark,
                          primaryColor,
                          recipeProvider,
                          completedSteps,
                          totalSteps,
                          stepProgress,
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildIngredientsSection(isDark, primaryColor, recipeProvider),
                      const SizedBox(height: 32),
                      _buildInstructionsSection(
                        isDark,
                        primaryColor,
                        recipeProvider,
                        completedSteps,
                        totalSteps,
                        stepProgress,
                      ),
                    ],
                  );
                }
              }),

              // Notes Section
              if (widget.recipe.notes != null && widget.recipe.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: primaryColor, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Chef Notes & Tips',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    widget.recipe.notes!.trim(),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientsSection(bool isDark, Color primaryColor, RecipeProvider recipeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: primaryColor, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Ingredients',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.recipe.ingredients.isEmpty)
          const Text('No ingredients listed.', style: TextStyle(color: Colors.grey))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.recipe.ingredients.length,
            itemBuilder: (context, index) {
              final item = widget.recipe.ingredients[index];
              if (item.isHeader) {
                return Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 6),
                  child: Text(
                    item.text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                );
              }
              return InkWell(
                onTap: () => recipeProvider.toggleIngredient(widget.recipe, index),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: item.isChecked,
                        activeColor: primaryColor,
                        onChanged: (_) => recipeProvider.toggleIngredient(widget.recipe, index),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            item.text,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              decoration: item.isChecked ? TextDecoration.lineThrough : null,
                              color: item.isChecked
                                  ? (isDark ? Colors.white38 : Colors.black38)
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildInstructionsSection(
    bool isDark,
    Color primaryColor,
    RecipeProvider recipeProvider,
    int completedSteps,
    int totalSteps,
    double stepProgress,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.format_list_numbered_outlined, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Instructions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (totalSteps > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '$completedSteps of $totalSteps completed',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                ),
              ),
          ],
        ),
        if (totalSteps > 0) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: stepProgress,
            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            color: primaryColor,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
        const SizedBox(height: 16),
        if (widget.recipe.instructions.isEmpty)
          const Text('No instructions listed.', style: TextStyle(color: Colors.grey))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.recipe.instructions.length,
            itemBuilder: (context, index) {
              final step = widget.recipe.instructions[index];
              if (step.isHeader) {
                return Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 8),
                  child: Text(
                    step.step,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                );
              }
              return InkWell(
                onTap: () => recipeProvider.toggleInstruction(widget.recipe, index),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: step.isCompleted
                        ? (isDark ? const Color(0xFF1E293B).withAlpha(128) : const Color(0xFFF1F5F9))
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: step.isCompleted
                          ? (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: step.isCompleted,
                        activeColor: primaryColor,
                        onChanged: (_) => recipeProvider.toggleInstruction(widget.recipe, index),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            step.step,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              decoration: step.isCompleted ? TextDecoration.lineThrough : null,
                              color: step.isCompleted
                                  ? (isDark ? Colors.white38 : Colors.black38)
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMetaPill({
    required IconData icon,
    required String label,
    required bool isDark,
    bool highlight = false,
    bool clickable = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? (isDark ? AppTheme.primaryAmber.withAlpha(38) : AppTheme.primaryTerracotta.withAlpha(38))
            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: highlight
                ? (isDark ? AppTheme.primaryAmber : AppTheme.primaryTerracotta)
                : (isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
              color: clickable
                  ? Colors.blueAccent
                  : (highlight
                      ? (isDark ? AppTheme.primaryAmber : AppTheme.primaryTerracotta)
                      : (isDark ? Colors.white70 : Colors.black87)),
            ),
          ),
        ],
      ),
    );
  }
}
