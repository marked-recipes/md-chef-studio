import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/github_service.dart';
import '../../theme/app_theme.dart';
import 'git_settings_dialog.dart';

class ContributeRecipeDialog extends StatefulWidget {
  final Recipe? initialRecipe;

  const ContributeRecipeDialog({super.key, this.initialRecipe});

  @override
  State<ContributeRecipeDialog> createState() => _ContributeRecipeDialogState();
}

class _ContributeRecipeDialogState extends State<ContributeRecipeDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _prTitleController;
  late TextEditingController _prBodyController;
  Recipe? _selectedRecipeForIssue;
  bool _isSubmittingPr = false;
  String? _prSuccessUrl;
  String? _prErrorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedRecipeForIssue = widget.initialRecipe;

    final recipeName = widget.initialRecipe?.title ?? 'new recipe';
    _prTitleController = TextEditingController(text: 'Add $recipeName recipe');
    _prBodyController = TextEditingController(
      text: '### Proposed Recipe\n\n'
          'Added `$recipeName` using MD Chef Studio.\n\n'
          '- **Category**: ${widget.initialRecipe?.category ?? "General"}\n'
          '- **Prep Time**: ${widget.initialRecipe?.prepTime ?? "N/A"}\n'
          '- **Cook Time**: ${widget.initialRecipe?.cookTime ?? "N/A"}\n\n'
          'Please review for inclusion in the official MarkedChef cookbook!',
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _prTitleController.dispose();
    _prBodyController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String urlStr) async {
    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _submitPrViaApi() async {
    final settingsProvider = context.read<SettingsProvider>();
    final cfg = settingsProvider.gitConfig;

    if (!cfg.hasToken) {
      setState(() => _prErrorMessage = 'A GitHub Personal Access Token is required to submit a PR via API.');
      return;
    }

    setState(() {
      _isSubmittingPr = true;
      _prErrorMessage = null;
      _prSuccessUrl = null;
    });

    try {
      final res = await GitHubService.createPullRequest(
        config: cfg,
        title: _prTitleController.text.trim(),
        body: _prBodyController.text.trim(),
        headBranch: cfg.branch,
        baseOwner: 'marked-recipes',
        baseBranch: 'main',
      );

      final htmlUrl = res['html_url'] as String? ?? 'https://github.com/marked-recipes/recipes/pulls';
      setState(() {
        _isSubmittingPr = false;
        _prSuccessUrl = htmlUrl;
      });
    } catch (e) {
      setState(() {
        _isSubmittingPr = false;
        _prErrorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final settingsProvider = context.watch<SettingsProvider>();
    final cfg = settingsProvider.gitConfig;
    final isFork = cfg.owner.toLowerCase() != 'marked-recipes';

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.volunteer_activism_outlined, color: primaryColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contribute to MarkedChef',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Share your favorite recipes with the community cookbook',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

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
                  tabs: const [
                    Tab(text: 'Pull Request Guide (Recommended)'),
                    Tab(text: 'Submit via GitHub Issue (Zero Token)'),
                    Tab(text: 'Quality Standards'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPullRequestTab(isDark, primaryColor, cfg, isFork),
                    _buildIssueSubmissionTab(isDark, primaryColor),
                    _buildQualityStandardsTab(isDark, primaryColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPullRequestTab(bool isDark, Color primaryColor, dynamic cfg, bool isFork) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 1: Fork
          _buildStepCard(
            isDark: isDark,
            stepNumber: 1,
            title: 'Fork the Repository',
            description:
                'A "Fork" is your personal copy of the MarkedChef cookbook under your own GitHub account. Any recipes you add or edit are saved to your fork first.',
            statusWidget: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isFork
                    ? AppTheme.accentSage.withAlpha(25)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFork
                      ? AppTheme.accentSage.withAlpha(80)
                      : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isFork ? Icons.check_circle_outline : Icons.info_outline,
                    size: 18,
                    color: isFork ? AppTheme.accentSage : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isFork
                          ? 'You are currently using your fork: ${cfg.owner}/${cfg.repo}'
                          : 'Currently connected to upstream marked-recipes/recipes (Read-Only)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isFork ? AppTheme.accentSage : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                  if (!isFork)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      icon: const Icon(Icons.fork_right, size: 14),
                      label: const Text('Fork to My Account'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        showDialog(
                          context: context,
                          builder: (ctx) => const GitSettingsDialog(),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Step 2: Create / Edit Recipe
          _buildStepCard(
            isDark: isDark,
            stepNumber: 2,
            title: 'Create & Commit Your Recipe',
            description:
                'Use the Visual Form Editor or AI Extractor in MD Chef Studio to create your recipe with ingredient measurements and numbered steps. When done, click "Commit New Recipe" to push it to your fork.',
          ),
          const SizedBox(height: 12),

          // Step 3: Pull Request
          _buildStepCard(
            isDark: isDark,
            stepNumber: 3,
            title: 'Submit a Pull Request (PR)',
            description:
                'A Pull Request invites the MarkedChef maintainers to review your recipe and merge it into the official repository for everyone to enjoy.',
            contentWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                TextField(
                  controller: _prTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Pull Request Title',
                    hintText: 'e.g. Add Lemon Ricotta Pasta recipe',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _prBodyController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description / Chef Notes',
                    hintText: 'Tell the maintainers about this recipe...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),

                if (_prErrorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withAlpha(100)),
                    ),
                    child: Text(_prErrorMessage!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                  ),

                if (_prSuccessUrl != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withAlpha(100)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pull request created successfully!',
                            style: const TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _launchUrl(_prSuccessUrl!),
                          child: const Text('View on GitHub'),
                        ),
                      ],
                    ),
                  ),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Open PR on GitHub (Recommended)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        final compareUrl = GitHubService.getPullRequestCompareUrl(
                          forkOwner: cfg.owner,
                          headBranch: cfg.branch,
                          title: _prTitleController.text.trim(),
                          body: _prBodyController.text.trim(),
                        );
                        _launchUrl(compareUrl);
                      },
                    ),
                    if (cfg.hasToken && isFork)
                      OutlinedButton.icon(
                        icon: _isSubmittingPr
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send, size: 16),
                        label: const Text('Submit via API Directly'),
                        onPressed: _isSubmittingPr ? null : _submitPrViaApi,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueSubmissionTab(bool isDark, Color primaryColor) {
    final recipeProvider = context.watch<RecipeProvider>();
    final recipes = recipeProvider.recipes;

    _selectedRecipeForIssue ??= recipes.isNotEmpty ? recipes.first : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bolt, color: Colors.amber, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No Tokens or Forks Required!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'If you don\'t want to configure GitHub access tokens or maintain a repository fork, you can submit any recipe as a GitHub Issue proposal in one click using your regular GitHub account.',
                        style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const Text('Select Recipe to Submit:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),

          if (recipes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No recipes loaded in studio yet. Create a recipe first or load recipes from GitHub.',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
              ),
            )
          else
            DropdownButtonFormField<Recipe>(
              initialValue: _selectedRecipeForIssue,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: recipes.map((r) {
                return DropdownMenuItem(
                  value: r,
                  child: Text('${r.title} (${r.category})'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedRecipeForIssue = val);
              },
            ),

          const SizedBox(height: 18),
          if (_selectedRecipeForIssue != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview: ${_selectedRecipeForIssue!.title}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedRecipeForIssue!.ingredients.length} ingredients • ${_selectedRecipeForIssue!.instructions.length} steps • Category: ${_selectedRecipeForIssue!.category}',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open Pre-Filled Issue on GitHub'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final issueUrl = GitHubService.getIssueSubmissionUrl(
                  title: _selectedRecipeForIssue!.title,
                  markdownBody: _selectedRecipeForIssue!.toMarkdown(),
                );
                _launchUrl(issueUrl);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQualityStandardsTab(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recipe Guidelines for Community Inclusion',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            'MarkedChef recipes use strict Markdown formatting to ensure they render smoothly across the web app, offline readers, and voice assistants.',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 16),
          _buildQualityItem(
            icon: Icons.title,
            title: 'Recipe Title & Cuisine Category',
            description:
                'Use standard categories matching existing directories (e.g. Pasta, Soup, Salad, Asian, Italian, Bread, Desserts).',
          ),
          _buildQualityItem(
            icon: Icons.checklist,
            title: 'Accurate Ingredient Measurements',
            description:
                'Use standard units (grams, ml, cups, tsp). Prefix optional or garnish ingredients with details.',
          ),
          _buildQualityItem(
            icon: Icons.format_list_numbered,
            title: 'Numbered Steps with Checkboxes',
            description:
                'Each step starts with a markdown checkbox `- [ ]`. Group complex recipes using Section Headers (e.g. `### Dough`, `### Sauce`).',
          ),
          _buildQualityItem(
            icon: Icons.timer_outlined,
            title: 'Metadata (Prep Time, Cook Time, Servings, Difficulty)',
            description:
                'Help home cooks know what to expect. State whether times are in minutes or hours in the frontmatter.',
          ),
          _buildQualityItem(
            icon: Icons.attribution,
            title: 'Credit & Source Attribution',
            description:
                'Give credit to the chef or link to the original cookbook / URL where you discovered the recipe.',
          ),
        ],
      ),
    );
  }

  Widget _buildQualityItem({required IconData icon, required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.teal, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required bool isDark,
    required int stepNumber,
    required String title,
    required String description,
    Widget? statusWidget,
    Widget? contentWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.primaryAmber,
                child: Text(
                  '$stepNumber',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(
              description,
              style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          if (statusWidget != null) Padding(padding: const EdgeInsets.only(left: 34), child: statusWidget),
          if (contentWidget != null) Padding(padding: const EdgeInsets.only(left: 34), child: contentWidget),
        ],
      ),
    );
  }
}
