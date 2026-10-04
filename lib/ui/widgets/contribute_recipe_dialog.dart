import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/github_service.dart';
import '../../theme/app_theme.dart';
import 'git_settings_dialog.dart';

class HelpGuidesDialog extends StatefulWidget {
  final Recipe? initialRecipe;
  final int initialTabIndex;

  const HelpGuidesDialog({
    super.key,
    this.initialRecipe,
    this.initialTabIndex = 0,
  });

  @override
  State<HelpGuidesDialog> createState() => _HelpGuidesDialogState();
}

/// Backwards compatibility alias for existing references
typedef ContributeRecipeDialog = HelpGuidesDialog;

class _HelpGuidesDialogState extends State<HelpGuidesDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _prTitleController;
  late TextEditingController _prBodyController;
  late TextEditingController _newRepoNameController;
  bool _isPrivateRepo = false;
  bool _isCreatingRepo = false;
  String? _createRepoSuccessMsg;
  String? _createRepoErrorMsg;

  Recipe? _selectedRecipeForIssue;
  bool _isSubmittingPr = false;
  String? _prSuccessUrl;
  String? _prErrorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _selectedRecipeForIssue = widget.initialRecipe;
    _newRepoNameController = TextEditingController(text: 'my-recipes');

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
    _newRepoNameController.dispose();
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

  Future<void> _createPersonalRepo() async {
    final settingsProvider = context.read<SettingsProvider>();
    final recipeProvider = context.read<RecipeProvider>();
    final cfg = settingsProvider.gitConfig;

    final repoName = _newRepoNameController.text.trim();
    if (repoName.isEmpty) {
      setState(() => _createRepoErrorMsg = 'Please enter a repository name (e.g. my-recipes).');
      return;
    }

    if (!cfg.hasToken) {
      setState(() => _createRepoErrorMsg = 'A GitHub Personal Access Token is required to create a repository via API. Alternatively, click "Create via GitHub.com".');
      return;
    }

    setState(() {
      _isCreatingRepo = true;
      _createRepoErrorMsg = null;
      _createRepoSuccessMsg = null;
    });

    try {
      // 1. Verify user info to get username
      final userInfo = await GitHubService.verifyToken(cfg.token);
      final login = userInfo['login'] as String? ?? cfg.owner;

      // 2. Create repo
      final repoRes = await GitHubService.createPersonalRepository(
        config: cfg,
        repoName: repoName,
        isPrivate: _isPrivateRepo,
      );

      final createdOwner = (repoRes['owner']?['login'] as String?) ?? login;
      final createdName = repoRes['name'] as String? ?? repoName;

      // 3. Switch active Git repo in Studio
      final newConfig = cfg.copyWith(
        owner: createdOwner,
        repo: createdName,
        branch: 'main',
        commitAuthorName: userInfo['name'] as String? ?? cfg.commitAuthorName,
        commitAuthorEmail: userInfo['email'] as String? ?? cfg.commitAuthorEmail,
      );

      await settingsProvider.updateGitConfig(newConfig);
      await recipeProvider.fetchFromGitHub(newConfig);

      setState(() {
        _isCreatingRepo = false;
        _createRepoSuccessMsg = 'Successfully created "$createdOwner/$createdName" and connected MD Chef Studio!';
      });
    } catch (e) {
      setState(() {
        _isCreatingRepo = false;
        _createRepoErrorMsg = e.toString().replaceFirst('Exception: ', '');
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
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 820),
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
                    child: Icon(Icons.help_outline, color: primaryColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Help, Guides & Repositories',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Contribute to the community, create your own cookbook repo, or review standards',
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
                    Tab(
                      icon: Icon(Icons.volunteer_activism_outlined, size: 16),
                      text: 'Contribute Recipe',
                    ),
                    Tab(
                      icon: Icon(Icons.auto_stories_outlined, size: 16),
                      text: 'Create Personal Repo',
                    ),
                    Tab(
                      icon: Icon(Icons.rule_outlined, size: 16),
                      text: 'Format Standards',
                    ),
                    Tab(
                      icon: Icon(Icons.info_outline, size: 16),
                      text: 'About Ecosystem',
                    ),
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
                    _buildPersonalRepoTab(isDark, primaryColor, cfg),
                    _buildQualityStandardsTab(isDark, primaryColor),
                    _buildAboutEcosystemTab(isDark, primaryColor),
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
                'A "Fork" is your personal copy of the MarkedChef cookbook on GitHub. Any recipes you add or edit are safely saved to your fork first without touching the community repository.',
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
                'Use the Visual Form Editor or AI Extractor in MD Chef Studio to create your recipe with ingredient measurements and numbered steps. When ready, click "Commit New Recipe" to push it to your fork.',
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
                        const Expanded(
                          child: Text(
                            'Pull request created successfully!',
                            style: TextStyle(fontSize: 12, color: Colors.green),
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
          const SizedBox(height: 16),

          // Fallback option: GitHub Issue
          _buildStepCard(
            isDark: isDark,
            stepNumber: 4,
            title: 'Alternative: Submit via GitHub Issue (No Tokens / No Forks)',
            description:
                'Prefer not to create a Personal Access Token or manage a fork? Pick any recipe and submit it directly as a GitHub Proposal issue with your free GitHub account.',
            contentWidget: _buildIssueSubmissionInline(isDark, primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueSubmissionInline(bool isDark, Color primaryColor) {
    final recipeProvider = context.watch<RecipeProvider>();
    final recipes = recipeProvider.recipes;
    _selectedRecipeForIssue ??= recipes.isNotEmpty ? recipes.first : null;

    if (recipes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'No recipes loaded in studio yet.',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
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
        const SizedBox(height: 10),
        ElevatedButton.icon(
          icon: const Icon(Icons.open_in_new, size: 14),
          label: const Text('Open Pre-Filled Issue on GitHub'),
          onPressed: _selectedRecipeForIssue == null
              ? null
              : () {
                  final issueUrl = GitHubService.getIssueSubmissionUrl(
                    title: _selectedRecipeForIssue!.title,
                    markdownBody: _selectedRecipeForIssue!.toMarkdown(),
                  );
                  _launchUrl(issueUrl);
                },
        ),
      ],
    );
  }

  Widget _buildPersonalRepoTab(bool isDark, Color primaryColor, dynamic cfg) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Explanatory Comparison Card
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
                const Icon(Icons.auto_stories, color: Colors.teal, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Want a Fresh Cookbook with ONLY Your Recipes?',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Instead of forking the community repo with all existing recipes, you can create a standalone GitHub repository (e.g. "my-recipes" or "family-recipes"). This gives you a blank slate where only your private or curated recipes live.',
                        style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Two Paths: Fork vs Standalone
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.fork_right, size: 16, color: Colors.amber),
                          SizedBox(width: 6),
                          Text('Option A: Fork MarkedChef', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• Starts with all 18+ community recipes.\n• Best if you want to contribute recipes back to the official community.\n• Automatic upstream sync.',
                        style: TextStyle(fontSize: 11, height: 1.4, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryColor.withAlpha(80), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: primaryColor),
                          const SizedBox(width: 6),
                          const Text('Option B: Personal Blank Repo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• 100% clean slate (0 community recipes).\n• Best for private family cookbooks or personal collections.\n• Complete privacy & ownership.',
                        style: TextStyle(fontSize: 11, height: 1.4, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1-Click Repo Creator Wizard
          const Text('Create & Connect Your Personal Repo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _newRepoNameController,
                  decoration: const InputDecoration(
                    labelText: 'Repository Name',
                    hintText: 'e.g. my-recipes, secret-cookbook',
                    prefixIcon: Icon(Icons.folder_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Make Repository Private (Hidden from public GitHub)', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Only you and people you invite can view recipes.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _isPrivateRepo,
                  onChanged: (val) => setState(() => _isPrivateRepo = val ?? false),
                ),
                const SizedBox(height: 12),

                if (_createRepoErrorMsg != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withAlpha(100)),
                    ),
                    child: Text(_createRepoErrorMsg!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                  ),

                if (_createRepoSuccessMsg != null)
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
                            _createRepoSuccessMsg!,
                            style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (cfg.hasToken)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        icon: _isCreatingRepo
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text('Create & Connect Repository Now'),
                        onPressed: _isCreatingRepo ? null : _createPersonalRepo,
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Create via GitHub.com (Browser)'),
                      onPressed: () {
                        final newRepoUrl = GitHubService.getNewRepoUrl(
                          name: _newRepoNameController.text.trim().isEmpty ? 'my-recipes' : _newRepoNameController.text.trim(),
                        );
                        _launchUrl(newRepoUrl);
                      },
                    ),
                  ],
                ),

                if (!cfg.hasToken)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Tip: Add a GitHub Personal Access Token in Git Settings to enable 1-click automatic repo creation & switching.',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
              ],
            ),
          ),
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

  Widget _buildAboutEcosystemTab(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About the MarkedChef Ecosystem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Text(
            'MarkedChef is an open culinary ecosystem built on open formats (Markdown), Git version control, and privacy-preserving local AI.',
            style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 16),
          _buildQualityItem(
            icon: Icons.menu_book,
            title: 'marked-recipes/recipes',
            description:
                'The central open-source recipe repository stored as clean, transparent Markdown files.',
          ),
          _buildQualityItem(
            icon: Icons.restaurant,
            title: 'MD Chef (Reader & Cook Companion)',
            description:
                'The companion cooking app with checklist progress, timers, and meal planning.',
          ),
          _buildQualityItem(
            icon: Icons.laptop_mac,
            title: 'MD Chef Studio (Recipe Manager)',
            description:
                'This application! Designed for authoring, editing, AI extracting from PDFs/URLs, and managing Git recipe repositories.',
          ),
          _buildQualityItem(
            icon: Icons.bolt,
            title: 'Offline-First & Git Delta Sync',
            description:
                'All recipes are cached locally in browser storage. Git tree blob SHAs enable sub-10ms loads with zero unnecessary network calls.',
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
