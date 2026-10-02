class GitRepoConfig {
  final String owner;
  final String repo;
  final String branch;
  final String token;
  final String commitAuthorName;
  final String commitAuthorEmail;

  const GitRepoConfig({
    this.owner = 'marked-recipes',
    this.repo = 'recipes',
    this.branch = 'main',
    this.token = '',
    this.commitAuthorName = 'MD Chef Studio User',
    this.commitAuthorEmail = 'user@markedchef.app',
  });

  String get fullName => '$owner/$repo';
  bool get hasToken => token.trim().isNotEmpty;
  bool get isOfficialRepo => owner.toLowerCase() == 'marked-recipes' && repo.toLowerCase() == 'recipes';
  String get repoUrl => 'https://github.com/$owner/$repo';

  GitRepoConfig copyWith({
    String? owner,
    String? repo,
    String? branch,
    String? token,
    String? commitAuthorName,
    String? commitAuthorEmail,
  }) {
    return GitRepoConfig(
      owner: owner ?? this.owner,
      repo: repo ?? this.repo,
      branch: branch ?? this.branch,
      token: token ?? this.token,
      commitAuthorName: commitAuthorName ?? this.commitAuthorName,
      commitAuthorEmail: commitAuthorEmail ?? this.commitAuthorEmail,
    );
  }

  Map<String, dynamic> toJson() => {
        'owner': owner,
        'repo': repo,
        'branch': branch,
        'token': token,
        'commitAuthorName': commitAuthorName,
        'commitAuthorEmail': commitAuthorEmail,
      };

  factory GitRepoConfig.fromJson(Map<String, dynamic> json) {
    return GitRepoConfig(
      owner: json['owner'] as String? ?? 'marked-recipes',
      repo: json['repo'] as String? ?? 'recipes',
      branch: json['branch'] as String? ?? 'main',
      token: json['token'] as String? ?? '',
      commitAuthorName: json['commitAuthorName'] as String? ?? 'MD Chef Studio User',
      commitAuthorEmail: json['commitAuthorEmail'] as String? ?? 'user@markedchef.app',
    );
  }
}
