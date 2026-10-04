import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/git_repo_config.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/github_service.dart';
import '../../theme/app_theme.dart';
import 'git_branch_icon.dart';

class GitSettingsDialog extends StatefulWidget {
  const GitSettingsDialog({super.key});

  @override
  State<GitSettingsDialog> createState() => _GitSettingsDialogState();
}

class _GitSettingsDialogState extends State<GitSettingsDialog> {
  late TextEditingController _ownerController;
  late TextEditingController _repoController;
  late TextEditingController _branchController;
  late TextEditingController _tokenController;
  late TextEditingController _authorNameController;
  late TextEditingController _authorEmailController;

  bool _isForking = false;
  String? _forkSuccessMessage;
  String? _forkErrorMessage;

  @override
  void initState() {
    super.initState();
    final cfg = context.read<SettingsProvider>().gitConfig;
    _ownerController = TextEditingController(text: cfg.owner);
    _repoController = TextEditingController(text: cfg.repo);
    _branchController = TextEditingController(text: cfg.branch);
    _tokenController = TextEditingController(text: cfg.token);
    _authorNameController = TextEditingController(text: cfg.commitAuthorName);
    _authorEmailController = TextEditingController(text: cfg.commitAuthorEmail);
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _repoController.dispose();
    _branchController.dispose();
    _tokenController.dispose();
    _authorNameController.dispose();
    _authorEmailController.dispose();
    super.dispose();
  }

  GitRepoConfig _buildConfig() {
    return GitRepoConfig(
      owner: _ownerController.text.trim().isEmpty ? 'marked-recipes' : _ownerController.text.trim(),
      repo: _repoController.text.trim().isEmpty ? 'recipes' : _repoController.text.trim(),
      branch: _branchController.text.trim().isEmpty ? 'main' : _branchController.text.trim(),
      token: _tokenController.text.trim(),
      commitAuthorName: _authorNameController.text.trim().isEmpty ? 'MD Chef Studio User' : _authorNameController.text.trim(),
      commitAuthorEmail: _authorEmailController.text.trim().isEmpty ? 'user@markedchef.app' : _authorEmailController.text.trim(),
    );
  }

  Future<void> _forkRepo() async {
    final settings = context.read<SettingsProvider>();
    final cfg = _buildConfig();
    if (!cfg.hasToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your GitHub Personal Access Token to fork the repository.')),
      );
      return;
    }

    setState(() {
      _isForking = true;
      _forkSuccessMessage = null;
      _forkErrorMessage = null;
    });

    try {
      final res = await GitHubService.forkMarkedRecipes(cfg);
      final forkOwner = res['owner']?['login'] as String?;
      final forkRepo = res['name'] as String?;
      if (forkOwner != null) {
        _ownerController.text = forkOwner;
        if (forkRepo != null) _repoController.text = forkRepo;
        final updatedCfg = _buildConfig();
        await settings.updateGitConfig(updatedCfg);
        setState(() {
          _forkSuccessMessage = 'Fork created successfully under $forkOwner/$forkRepo! Connected.';
        });
      }
    } catch (e) {
      setState(() {
        _forkErrorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      setState(() {
        _isForking = false;
      });
    }
  }

  Future<void> _saveAndSync() async {
    final settings = context.read<SettingsProvider>();
    final recipeProvider = context.read<RecipeProvider>();
    final cfg = _buildConfig();

    await settings.updateGitConfig(cfg);
    await recipeProvider.fetchFromGitHub(cfg);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved connection to ${cfg.fullName} and loaded recipes.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.primaryAmber : AppTheme.primaryTerracotta;
    final settings = context.watch<SettingsProvider>();
    final recipeProvider = context.watch<RecipeProvider>();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  GitBranchIcon(size: 26, color: primaryColor),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Git Repository & Sync',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Connect marked-recipes/recipes or your personal fork',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Quick Presets
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.hub_outlined, size: 16),
                    label: const Text('Default (marked-recipes/recipes)'),
                    onPressed: () {
                      _ownerController.text = 'marked-recipes';
                      _repoController.text = 'recipes';
                      _branchController.text = 'main';
                    },
                  ),
                  if (settings.gitAuthUser != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_pin_outlined, size: 16),
                      label: Text('My Fork (${settings.gitAuthUser})'),
                      onPressed: () {
                        _ownerController.text = settings.gitAuthUser!;
                        _repoController.text = 'recipes';
                        _branchController.text = 'main';
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Owner & Repo
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _ownerController,
                      decoration: const InputDecoration(
                        labelText: 'GitHub Owner / Org',
                        hintText: 'marked-recipes or your username',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _repoController,
                      decoration: const InputDecoration(
                        labelText: 'Repository Name',
                        hintText: 'recipes',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _branchController,
                      decoration: const InputDecoration(
                        labelText: 'Branch',
                        hintText: 'main',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Personal Access Token
              TextField(
                controller: _tokenController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'GitHub Personal Access Token (PAT)',
                  hintText: 'ghp_...',
                  helperText: 'Required for committing, editing, deleting, or forking recipes.',
                  suffixIcon: IconButton(
                    tooltip: 'Create a GitHub PAT with repo permissions',
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () async {
                      final uri = Uri.parse('https://github.com/settings/tokens/new?scopes=repo&description=MD+Chef+Studio');
                      if (await canLaunchUrl(uri)) launchUrl(uri);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Authentication status badge
              if (settings.isVerifyingGit)
                const Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Verifying GitHub token...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                )
              else if (settings.gitAuthUser != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentSage.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentSage.withAlpha(76)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: AppTheme.accentSage),
                      const SizedBox(width: 8),
                      Text(
                        'Authenticated as @${settings.gitAuthUser} (Commit permissions active)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accentSage),
                      ),
                    ],
                  ),
                )
              else if (settings.gitAuthError != null)
                Text(
                  'Auth warning: ${settings.gitAuthError}',
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Fork section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.call_split, color: primaryColor),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need your own copy?',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Fork marked-recipes/recipes directly to your GitHub profile with one click.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155), foregroundColor: Colors.white),
                      icon: _isForking
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.fork_right, size: 16),
                      label: const Text('Fork to My Account'),
                      onPressed: _isForking ? null : _forkRepo,
                    ),
                  ],
                ),
              ),

              if (_forkSuccessMessage != null) ...[
                const SizedBox(height: 8),
                Text(_forkSuccessMessage!, style: const TextStyle(fontSize: 12, color: AppTheme.accentSage)),
              ],
              if (_forkErrorMessage != null) ...[
                const SizedBox(height: 8),
                Text('Fork error: $_forkErrorMessage', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
              ],

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Local Cache & Delta Sync
              Row(
                children: [
                  Icon(Icons.cached, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  const Text('Local Cache & Delta Sync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  if (recipeProvider.cachedRecipeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentSage.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.accentSage.withAlpha(76)),
                      ),
                      child: Text(
                        '${recipeProvider.cachedRecipeCount} cached',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentSage),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Recipes are cached locally in your browser/device so they load instantly without re-downloading. Sync checks Git for modified/new files and only downloads changes.',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 10),
              if (recipeProvider.syncStatusMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        recipeProvider.isSyncing ? Icons.sync : Icons.info_outline,
                        size: 15,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recipeProvider.syncStatusMessage!,
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: recipeProvider.isSyncing
                        ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor))
                        : const Icon(Icons.sync, size: 16),
                    label: const Text('Check for Git Changes'),
                    onPressed: recipeProvider.isSyncing
                        ? null
                        : () => recipeProvider.fetchFromGitHub(_buildConfig()),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download_for_offline_outlined, size: 16),
                    label: const Text('Force Full Re-read'),
                    onPressed: recipeProvider.isSyncing
                        ? null
                        : () => recipeProvider.fetchFromGitHub(_buildConfig(), forceFull: true),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.grey),
                    label: const Text('Clear Cache', style: TextStyle(color: Colors.grey)),
                    onPressed: () async {
                      await recipeProvider.clearLocalCache(_buildConfig());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Local recipe cache cleared.')),
                        );
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Author details for commits
              const Text('Git Commit Author Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _authorNameController,
                      decoration: const InputDecoration(labelText: 'Author Name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _authorEmailController,
                      decoration: const InputDecoration(labelText: 'Author Email'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.sync),
                    label: const Text('Save & Fetch Recipes'),
                    onPressed: _saveAndSync,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
