import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/git_repo_config.dart';

class GitHubService {
  static const String baseUrl = 'https://api.github.com';

  static Map<String, String> _buildHeaders(GitRepoConfig config, {String? accept}) {
    final headers = <String, String>{
      'Accept': accept ?? 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    };
    if (config.hasToken) {
      headers['Authorization'] = 'Bearer ${config.token.trim()}';
    }
    return headers;
  }

  /// Verifies token and retrieves authenticated user information
  static Future<Map<String, dynamic>> verifyToken(String token) async {
    final url = Uri.parse('$baseUrl/user');
    final response = await http.get(url, headers: {
      'Accept': 'application/vnd.github+json',
      'Authorization': 'Bearer ${token.trim()}',
      'X-GitHub-Api-Version': '2022-11-28',
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('GitHub authentication failed: ${response.statusCode} - ${response.body}');
    }
  }

  /// Checks if repository exists and checks user permissions
  static Future<Map<String, dynamic>> getRepositoryInfo(GitRepoConfig config) async {
    final url = Uri.parse('$baseUrl/repos/${config.owner}/${config.repo}');
    final response = await http.get(url, headers: _buildHeaders(config));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      throw Exception('Repository "${config.fullName}" not found. Verify owner and repo name.');
    } else {
      throw Exception('Failed to fetch repo info: ${response.statusCode} - ${response.body}');
    }
  }

  static Exception _handleHttpError(http.Response response, String defaultPrefix) {
    if (response.statusCode == 403 &&
        (response.headers['x-ratelimit-remaining'] == '0' || response.body.contains('rate limit'))) {
      final resetEpoch = int.tryParse(response.headers['x-ratelimit-reset'] ?? '') ?? 0;
      if (resetEpoch > 0) {
        final resetTime = DateTime.fromMillisecondsSinceEpoch(resetEpoch * 1000, isUtc: true).toLocal();
        final now = DateTime.now();
        final diff = resetTime.difference(now);
        final minutes = diff.inMinutes;
        final seconds = diff.inSeconds % 60;
        final formattedTime =
            '${resetTime.hour.toString().padLeft(2, '0')}:${resetTime.minute.toString().padLeft(2, '0')}';
        final remainingStr = minutes > 0 ? '$minutes min ' : '';
        return Exception(
          'GitHub API rate limit exceeded (60 req/hr for anonymous requests). Resets at $formattedTime (in $remainingStr${seconds}s). Tip: Add a free Personal Access Token in Git Settings for 5,000 req/hr.',
        );
      }
      return Exception(
        'GitHub API rate limit exceeded (60 req/hr). Resets within 60 minutes. Add a Personal Access Token in Git Settings to bypass immediately.',
      );
    }
    return Exception('$defaultPrefix: ${response.statusCode} - ${response.body}');
  }

  /// Fetches all recipe tree items from GitHub repository
  static Future<List<Map<String, dynamic>>> fetchRecipeTree(GitRepoConfig config) async {
    final url = Uri.parse('$baseUrl/repos/${config.owner}/${config.repo}/git/trees/${config.branch}?recursive=1');
    final response = await http.get(url, headers: _buildHeaders(config));

    if (response.statusCode != 200) {
      throw _handleHttpError(response, 'Failed to fetch tree for ${config.fullName} (${config.branch})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tree = (data['tree'] as List<dynamic>? ?? []);

    final recipes = <Map<String, dynamic>>[];

    for (final item in tree) {
      final path = item['path'] as String? ?? '';
      final type = item['type'] as String? ?? '';
      final sha = item['sha'] as String? ?? '';

      if (type == 'blob' && path.endsWith('.md')) {
        // Exclude root README, PRIVACY, and mcp-server docs
        final parts = path.split('/');
        if (parts.length >= 2) {
          final category = parts[0];
          // Skip dot folders and non-recipe folders
          if (!category.startsWith('.') && category != 'mcp-server' && category != '.github') {
            recipes.add({
              'path': path,
              'category': category,
              'fileName': parts.sublist(1).join('/'),
              'sha': sha,
            });
          }
        }
      }
    }

    return recipes;
  }

  /// Fetches raw markdown recipe content
  static Future<String> fetchRecipeContent(GitRepoConfig config, String path) async {
    final url = Uri.parse('$baseUrl/repos/${config.owner}/${config.repo}/contents/$path?ref=${config.branch}');
    final response = await http.get(
      url,
      headers: _buildHeaders(config, accept: 'application/vnd.github.raw+json'),
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw _handleHttpError(response, 'Failed to fetch recipe content ($path)');
    }
  }

  /// Commits a new or updated recipe markdown file to GitHub
  static Future<Map<String, dynamic>> saveRecipe({
    required GitRepoConfig config,
    required String path,
    required String content,
    required String commitMessage,
    String? sha,
  }) async {
    if (!config.hasToken) {
      throw Exception('A GitHub Personal Access Token is required to commit changes to the repository.');
    }

    final url = Uri.parse('$baseUrl/repos/${config.owner}/${config.repo}/contents/$path');
    final base64Content = base64.encode(utf8.encode(content));

    final body = <String, dynamic>{
      'message': commitMessage,
      'content': base64Content,
      'branch': config.branch,
      'committer': {
        'name': config.commitAuthorName,
        'email': config.commitAuthorEmail,
      },
      'author': {
        'name': config.commitAuthorName,
        'email': config.commitAuthorEmail,
      },
    };

    if (sha != null && sha.isNotEmpty) {
      body['sha'] = sha;
    }

    final response = await http.put(
      url,
      headers: _buildHeaders(config),
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception('GitHub commit failed (${response.statusCode}): ${error['message'] ?? response.body}');
    }
  }

  /// Deletes a recipe file from the GitHub repository
  static Future<void> deleteRecipe({
    required GitRepoConfig config,
    required String path,
    required String sha,
    required String commitMessage,
  }) async {
    if (!config.hasToken) {
      throw Exception('A GitHub Personal Access Token is required to delete recipes from the repository.');
    }

    final url = Uri.parse('$baseUrl/repos/${config.owner}/${config.repo}/contents/$path');
    final body = <String, dynamic>{
      'message': commitMessage,
      'sha': sha,
      'branch': config.branch,
      'committer': {
        'name': config.commitAuthorName,
        'email': config.commitAuthorEmail,
      },
    };

    final response = await http.delete(
      url,
      headers: _buildHeaders(config),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception('Failed to delete recipe (${response.statusCode}): ${error['message'] ?? response.body}');
    }
  }

  /// Forks marked-recipes/recipes to the user's account
  static Future<Map<String, dynamic>> forkMarkedRecipes(GitRepoConfig config) async {
    if (!config.hasToken) {
      throw Exception('GitHub Personal Access Token is required to create a fork.');
    }

    final url = Uri.parse('$baseUrl/repos/marked-recipes/recipes/forks');
    final response = await http.post(
      url,
      headers: _buildHeaders(config),
    );

    if (response.statusCode == 202 || response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception('Failed to fork repository (${response.statusCode}): ${error['message'] ?? response.body}');
    }
  }

  /// Generates the GitHub web URL to compare and open a Pull Request against marked-recipes/recipes
  static String getPullRequestCompareUrl({
    required String forkOwner,
    String headBranch = 'main',
    String baseOwner = 'marked-recipes',
    String baseBranch = 'main',
    String? title,
    String? body,
  }) {
    var url = 'https://github.com/$baseOwner/recipes/compare/$baseBranch...$forkOwner:$headBranch?expand=1';
    if (title != null && title.isNotEmpty) {
      url += '&title=${Uri.encodeComponent(title)}';
    }
    if (body != null && body.isNotEmpty) {
      url += '&body=${Uri.encodeComponent(body)}';
    }
    return url;
  }

  /// Generates a pre-filled GitHub issue URL on marked-recipes/recipes for non-technical submission
  static String getIssueSubmissionUrl({
    required String title,
    required String markdownBody,
  }) {
    final bodyText = '### Recipe Proposal: $title\n\n'
        '```markdown\n$markdownBody\n```\n\n'
        '---\n*Submitted via MD Chef Studio*';
    return 'https://github.com/marked-recipes/recipes/issues/new?'
        'title=${Uri.encodeComponent('[New Recipe] $title')}&'
        'body=${Uri.encodeComponent(bodyText)}';
  }

  /// Submits a Pull Request programmatically from the user\'s fork to marked-recipes/recipes
  static Future<Map<String, dynamic>> createPullRequest({
    required GitRepoConfig config,
    required String title,
    required String body,
    String headBranch = 'main',
    String baseOwner = 'marked-recipes',
    String baseBranch = 'main',
  }) async {
    if (!config.hasToken) {
      throw Exception('A GitHub Personal Access Token is required to submit a Pull Request via API.');
    }

    final url = Uri.parse('$baseUrl/repos/$baseOwner/recipes/pulls');
    final payload = {
      'title': title,
      'body': body,
      'head': '${config.owner}:$headBranch',
      'base': baseBranch,
    };

    final response = await http.post(
      url,
      headers: _buildHeaders(config),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception('Failed to create pull request (${response.statusCode}): ${error['message'] ?? response.body}');
    }
  }

  /// Creates a brand new standalone GitHub repository on the authenticated user's account
  static Future<Map<String, dynamic>> createPersonalRepository({
    required GitRepoConfig config,
    required String repoName,
    String description = 'Personal cookbook for MarkedChef and MD Chef Studio',
    bool isPrivate = false,
  }) async {
    if (!config.hasToken) {
      throw Exception('A GitHub Personal Access Token is required to create a new repository.');
    }

    final url = Uri.parse('$baseUrl/user/repos');
    final payload = {
      'name': repoName,
      'description': description,
      'private': isPrivate,
      'auto_init': true,
    };

    final response = await http.post(
      url,
      headers: _buildHeaders(config),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception('Failed to create repository (${response.statusCode}): ${error['message'] ?? response.body}');
    }
  }

  /// Generates URL to create a new repository on GitHub via browser
  static String getNewRepoUrl({String name = 'my-recipes'}) {
    return 'https://github.com/new?name=${Uri.encodeComponent(name)}&description=${Uri.encodeComponent("Personal cookbook for MarkedChef")}&auto_init=true';
  }
}
