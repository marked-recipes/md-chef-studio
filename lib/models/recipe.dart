import 'package:yaml/yaml.dart';

class RecipeIngredientItem {
  final String text;
  bool isChecked;
  final bool isHeader;

  RecipeIngredientItem({
    required this.text,
    this.isChecked = false,
    this.isHeader = false,
  });

  RecipeIngredientItem copyWith({
    String? text,
    bool? isChecked,
    bool? isHeader,
  }) {
    return RecipeIngredientItem(
      text: text ?? this.text,
      isChecked: isChecked ?? this.isChecked,
      isHeader: isHeader ?? this.isHeader,
    );
  }
}

class RecipeInstructionItem {
  final String step;
  bool isCompleted;
  final bool isHeader;

  RecipeInstructionItem({
    required this.step,
    this.isCompleted = false,
    this.isHeader = false,
  });

  RecipeInstructionItem copyWith({
    String? step,
    bool? isCompleted,
    bool? isHeader,
  }) {
    return RecipeInstructionItem(
      step: step ?? this.step,
      isCompleted: isCompleted ?? this.isCompleted,
      isHeader: isHeader ?? this.isHeader,
    );
  }
}

class Recipe {
  final String id;
  String category; // Directory, e.g. "Pasta", "Soup", "Chicken"
  String fileName; // e.g. "cacio-e-pepe.md"
  String? sha; // GitHub file SHA for committing updates
  String title;
  dynamic prepTime; // e.g. 10 or "10" or "15 mins"
  dynamic cookTime; // e.g. 25
  dynamic servings; // e.g. "2 - 3" or 4
  String? difficulty; // e.g. "Easy", "Medium"
  List<String> tags;
  String? credit;
  String? source;
  List<RecipeIngredientItem> ingredients;
  List<RecipeInstructionItem> instructions;
  String? notes;
  String rawMarkdown;

  Recipe({
    required this.id,
    required this.category,
    required this.fileName,
    this.sha,
    required this.title,
    this.prepTime,
    this.cookTime,
    this.servings,
    this.difficulty,
    List<String>? tags,
    this.credit,
    this.source,
    List<RecipeIngredientItem>? ingredients,
    List<RecipeInstructionItem>? instructions,
    this.notes,
    required this.rawMarkdown,
  })  : tags = tags ?? [],
        ingredients = ingredients ?? [],
        instructions = instructions ?? [];

  /// Full path in git repo: e.g. "Pasta/cacio-e-pepe.md"
  String get repoPath => category.trim().isEmpty ? fileName : '${category.trim()}/$fileName';

  /// Standard slug name from title
  static String slugify(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  /// Parse Markdown text following marked-recipes format
  factory Recipe.fromMarkdown(
    String fullPath,
    String content, {
    String? sha,
  }) {
    // Determine category and fileName from path (e.g. Pasta/cacio-e-pepe.md)
    final parts = fullPath.split('/');
    String category = 'Uncategorized';
    String fileName = fullPath;
    if (parts.length > 1) {
      category = parts.first;
      fileName = parts.sublist(1).join('/');
    }

    String title = fileName.replaceAll('.md', '').replaceAll('-', ' ');
    dynamic prepTime;
    dynamic cookTime;
    dynamic servings;
    String? difficulty;
    List<String> tags = [];
    String? credit;
    String? source;

    String body = content;

    // Check for YAML frontmatter
    final frontmatterMatch = RegExp(r'^---\s*\n([\s\S]*?)\n---\s*\n?').firstMatch(content);
    if (frontmatterMatch != null) {
      final yamlText = frontmatterMatch.group(1) ?? '';
      body = content.substring(frontmatterMatch.end);
      try {
        final yaml = loadYaml(yamlText);
        if (yaml is Map) {
          title = (yaml['title']?.toString() ?? title).trim();
          prepTime = yaml['prep_time'];
          cookTime = yaml['cook_time'];
          servings = yaml['servings'];
          difficulty = yaml['difficulty']?.toString();
          credit = yaml['credit']?.toString();
          source = yaml['source']?.toString();

          if (yaml['tags'] != null) {
            if (yaml['tags'] is Iterable) {
              tags = (yaml['tags'] as Iterable).map((e) => e.toString().trim()).toList();
            } else if (yaml['tags'] is String) {
              tags = (yaml['tags'] as String)
                  .split(RegExp(r'[,;]'))
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
            }
          }
        }
      } catch (e) {
        // Fallback if YAML syntax is slightly irregular
      }
    }

    // Parse Ingredients, Instructions, Notes from body
    final ingredients = <RecipeIngredientItem>[];
    final instructions = <RecipeInstructionItem>[];
    String? notes;

    final lines = body.split('\n');
    String currentSection = '';
    final notesLines = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (RegExp(r'^##\s+Ingredients', caseSensitive: false).hasMatch(line)) {
        currentSection = 'ingredients';
        continue;
      } else if (RegExp(r'^##\s+Instructions', caseSensitive: false).hasMatch(line)) {
        currentSection = 'instructions';
        continue;
      } else if (RegExp(r'^##\s+Notes?', caseSensitive: false).hasMatch(line)) {
        currentSection = 'notes';
        continue;
      } else if (RegExp(r'^##\s+', caseSensitive: false).hasMatch(line)) {
        currentSection = 'other';
        continue;
      }

      if (currentSection == 'ingredients') {
        final bulletStripped = line
            .replaceAll(RegExp(r'^[-*]\s*(\[[ xX]?\]\s*)?'), '')
            .trim();

        if (line.startsWith('#') || bulletStripped.startsWith('#')) {
          final headerText = bulletStripped.replaceAll(RegExp(r'^#+\s*'), '').trim();
          if (headerText.isNotEmpty) {
            ingredients.add(RecipeIngredientItem(text: headerText, isHeader: true));
          }
        } else if (line.isNotEmpty) {
          if (bulletStripped.isNotEmpty) {
            ingredients.add(RecipeIngredientItem(text: bulletStripped));
          }
        }
      } else if (currentSection == 'instructions') {
        final bulletStripped = line
            .replaceAll(RegExp(r'^[-*]\s*(\[[ xX]?\]\s*)?'), '')
            .replaceAll(RegExp(r'^\d+\.\s*(\[[ xX]?\]\s*)?'), '')
            .trim();

        if (line.startsWith('#') || bulletStripped.startsWith('#')) {
          final headerText = bulletStripped.replaceAll(RegExp(r'^#+\s*'), '').trim();
          if (headerText.isNotEmpty) {
            instructions.add(RecipeInstructionItem(step: headerText, isHeader: true));
          }
        } else if (line.isNotEmpty) {
          if (bulletStripped.isNotEmpty) {
            instructions.add(RecipeInstructionItem(step: bulletStripped));
          }
        }
      } else if (currentSection == 'notes') {
        if (line.isNotEmpty) {
          notesLines.add(line);
        }
      }
    }

    if (notesLines.isNotEmpty) {
      notes = notesLines.join('\n');
    }

    return Recipe(
      id: fullPath,
      category: category,
      fileName: fileName,
      sha: sha,
      title: title,
      prepTime: prepTime,
      cookTime: cookTime,
      servings: servings,
      difficulty: difficulty,
      tags: tags,
      credit: credit,
      source: source,
      ingredients: ingredients,
      instructions: instructions,
      notes: notes,
      rawMarkdown: content,
    );
  }

  /// Formats the Recipe back into standard markdown adhering to marked-recipes
  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('title: $title');
    if (prepTime != null && prepTime.toString().trim().isNotEmpty) {
      buffer.writeln('prep_time: $prepTime');
    }
    if (cookTime != null && cookTime.toString().trim().isNotEmpty) {
      buffer.writeln('cook_time: $cookTime');
    }
    if (servings != null && servings.toString().trim().isNotEmpty) {
      buffer.writeln('servings: $servings');
    }
    if (difficulty != null && difficulty!.trim().isNotEmpty) {
      buffer.writeln('difficulty: $difficulty');
    }
    if (tags.isNotEmpty) {
      buffer.writeln('tags:');
      for (final tag in tags) {
        if (tag.trim().isNotEmpty) {
          buffer.writeln('  - ${tag.trim().toLowerCase()}');
        }
      }
    }
    if (credit != null && credit!.trim().isNotEmpty) {
      buffer.writeln('credit: $credit');
    }
    if (source != null && source!.trim().isNotEmpty) {
      buffer.writeln('source: $source');
    }
    buffer.writeln('---');
    buffer.writeln();

    buffer.writeln('## Ingredients');
    buffer.writeln();
    for (final item in ingredients) {
      if (item.isHeader) {
        buffer.writeln('### ${item.text}');
      } else if (item.text.trim().isNotEmpty) {
        buffer.writeln('- [ ] ${item.text.trim()}');
      }
    }
    buffer.writeln();

    buffer.writeln('## Instructions');
    buffer.writeln();
    for (final step in instructions) {
      if (step.isHeader) {
        buffer.writeln('### ${step.step.trim()}');
      } else if (step.step.trim().isNotEmpty) {
        buffer.writeln('- [ ] ${step.step.trim()}');
      }
    }
    buffer.writeln();

    if (notes != null && notes!.trim().isNotEmpty) {
      buffer.writeln('## Notes');
      buffer.writeln(notes!.trim());
      buffer.writeln();
    }

    return buffer.toString();
  }

  Recipe copyWith({
    String? category,
    String? fileName,
    String? sha,
    String? title,
    dynamic prepTime,
    dynamic cookTime,
    dynamic servings,
    String? difficulty,
    List<String>? tags,
    String? credit,
    String? source,
    List<RecipeIngredientItem>? ingredients,
    List<RecipeInstructionItem>? instructions,
    String? notes,
    String? rawMarkdown,
  }) {
    return Recipe(
      id: id,
      category: category ?? this.category,
      fileName: fileName ?? this.fileName,
      sha: sha ?? this.sha,
      title: title ?? this.title,
      prepTime: prepTime ?? this.prepTime,
      cookTime: cookTime ?? this.cookTime,
      servings: servings ?? this.servings,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? List.from(this.tags),
      credit: credit ?? this.credit,
      source: source ?? this.source,
      ingredients: ingredients ?? this.ingredients.map((e) => e.copyWith()).toList(),
      instructions: instructions ?? this.instructions.map((e) => e.copyWith()).toList(),
      notes: notes ?? this.notes,
      rawMarkdown: rawMarkdown ?? this.rawMarkdown,
    );
  }
}
