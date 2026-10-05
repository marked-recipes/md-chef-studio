import 'recipe.dart';

class RecipeValidationResult {
  final List<String> errors;
  final List<String> warnings;
  final List<String> notices;

  const RecipeValidationResult({
    this.errors = const [],
    this.warnings = const [],
    this.notices = const [],
  });

  bool get isValid => errors.isEmpty;
  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get isReasonable => errors.isEmpty && warnings.isEmpty;
  int get issueCount => errors.length + warnings.length;

  /// Inspects an extracted recipe for completeness, duplicates, and reasonableness
  static RecipeValidationResult validate(Recipe recipe, {String? rawSource}) {
    final errors = <String>[];
    final warnings = <String>[];
    final notices = <String>[];

    // 1. Title validation
    final cleanTitle = recipe.title.trim();
    if (cleanTitle.isEmpty) {
      errors.add('Recipe title is missing.');
    } else if (cleanTitle.toLowerCase() == 'extracted recipe' ||
        cleanTitle.toLowerCase() == 'untitled' ||
        cleanTitle.toLowerCase() == 'recipe') {
      warnings.add('Recipe title appears to be a generic placeholder ("$cleanTitle").');
    } else if (cleanTitle.startsWith('http://') || cleanTitle.startsWith('https://')) {
      warnings.add('Recipe title is a URL instead of a recipe name.');
    }

    // 2. Ingredients validation
    final actualIngredients = recipe.ingredients.where((i) => !i.isHeader).toList();
    if (actualIngredients.isEmpty) {
      errors.add('No ingredients found. A complete recipe must have at least one ingredient.');
    } else if (actualIngredients.length == 1) {
      warnings.add('Only 1 ingredient found. Most recipes require multiple ingredients.');
    }

    // Duplicate ingredients detection
    final seenIngredients = <String, int>{};
    for (final ing in actualIngredients) {
      final normalized = ing.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      seenIngredients[normalized] = (seenIngredients[normalized] ?? 0) + 1;
    }
    final duplicateIngredients = seenIngredients.entries.where((e) => e.value > 1).toList();
    if (duplicateIngredients.isNotEmpty) {
      for (final dup in duplicateIngredients) {
        warnings.add('Duplicate ingredient detected: "${dup.key}" appears ${dup.value} times.');
      }
    }

    // Suspicious ingredients (too long, contains instructions, repetition)
    for (final ing in actualIngredients) {
      if (ing.text.length > 200) {
        warnings.add('Suspiciously long ingredient line (${ing.text.length} chars): "${_truncate(ing.text, 60)}" - may contain instructions.');
      }
      if (_hasRepetitionLoop(ing.text)) {
        warnings.add('Repetitive text loop detected in ingredient: "${_truncate(ing.text, 60)}".');
      }
    }

    // 3. Instructions validation
    final actualSteps = recipe.instructions.where((s) => !s.isHeader).toList();
    if (actualSteps.isEmpty) {
      errors.add('No instructions or preparation steps found.');
    } else if (actualSteps.length == 1) {
      warnings.add('Only 1 instruction step found. Recipe directions are typically multi-step.');
    }

    // Duplicate instructions detection
    final seenSteps = <String, int>{};
    for (final step in actualSteps) {
      final normalized = step.step.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      seenSteps[normalized] = (seenSteps[normalized] ?? 0) + 1;
    }
    final duplicateSteps = seenSteps.entries.where((e) => e.value > 1).toList();
    if (duplicateSteps.isNotEmpty) {
      for (final dup in duplicateSteps) {
        warnings.add('Duplicate instruction step detected (${dup.value}x): "${_truncate(dup.key, 60)}".');
      }
    }

    // Hallucinated instruction stage headers detection
    if (rawSource != null && rawSource.isNotEmpty) {
      for (final header in recipe.instructions.where((s) => s.isHeader)) {
        if (!_appearsAsStandaloneHeading(header.step, rawSource)) {
          warnings.add('Instruction stage header "### ${header.step}" was not found in source directions and may be hallucinated.');
        }
      }
    }

    // Suspicious instructions (too short, repetition loops, looks like ingredient)
    for (final step in actualSteps) {
      final text = step.step.trim();
      if (text.length < 5) {
        warnings.add('Suspiciously short instruction step: "$text".');
      }
      if (_hasRepetitionLoop(text)) {
        warnings.add('Runaway repetition loop detected in instruction step: "${_truncate(text, 60)}".');
      }
      if (RegExp(r'^\d+\s*(?:cup|cups|tbsp|tsp|tablespoon|teaspoon|oz|g|kg|lb|lbs)\b', caseSensitive: false).hasMatch(text) && text.length < 40) {
        warnings.add('Instruction step appears to be an ingredient: "$text".');
      }
    }

    // 4. Time & Servings sanity checks
    if (recipe.prepTime != null) {
      final prep = _parseInt(recipe.prepTime);
      if (prep != null && prep > 1440) {
        warnings.add('Unusually high prep time ($prep minutes / ${(prep / 60).toStringAsFixed(1)} hours).');
      } else if (prep != null && prep < 0) {
        errors.add('Negative prep time ($prep minutes).');
      }
    }

    if (recipe.cookTime != null) {
      final cook = _parseInt(recipe.cookTime);
      if (cook != null && cook > 1440) {
        warnings.add('Unusually high cook time ($cook minutes / ${(cook / 60).toStringAsFixed(1)} hours).');
      } else if (cook != null && cook < 0) {
        errors.add('Negative cook time ($cook minutes).');
      }
    }

    if (recipe.servings != null) {
      final s = _parseInt(recipe.servings);
      if (s != null && s <= 0) {
        warnings.add('Invalid servings count ($s). Must be greater than 0.');
      } else if (s != null && s > 100) {
        notices.add('Large batch recipe: $s servings.');
      }
    }

    // 5. Tags check
    if (recipe.tags.isEmpty) {
      notices.add('No tags assigned to this recipe.');
    }

    return RecipeValidationResult(
      errors: errors,
      warnings: warnings,
      notices: notices,
    );
  }

  /// Automatically fixes common quality issues (removes duplicate ingredients & steps, trims loops, drops fake headers)
  static Recipe autoFix(Recipe original, {String? rawSource}) {
    // 1. Deduplicate consecutive identical ingredients & exact duplicates in same subgroup
    final cleanedIngredients = <RecipeIngredientItem>[];
    final seenInSubgroup = <String>{};

    for (final item in original.ingredients) {
      if (item.isHeader) {
        cleanedIngredients.add(item);
        seenInSubgroup.clear(); // new subgroup allows repeating ingredients across subgroups (e.g. olive oil)
      } else {
        final norm = item.text.trim().toLowerCase();
        if (!seenInSubgroup.contains(norm)) {
          seenInSubgroup.add(norm);
          cleanedIngredients.add(item.copyWith(
            text: _cleanRepetition(item.text.trim()),
          ));
        }
      }
    }

    // 2. Deduplicate exact duplicate instruction steps and remove hallucinated stage headers
    final cleanedInstructions = <RecipeInstructionItem>[];
    final seenSteps = <String>{};

    for (final item in original.instructions) {
      if (item.isHeader) {
        if (rawSource != null && rawSource.isNotEmpty && !_appearsAsStandaloneHeading(item.step, rawSource)) {
          // Drop hallucinated stage header
          continue;
        }
        cleanedInstructions.add(item);
      } else {
        final text = item.step.trim();
        if (text.length < 5 || RegExp(r'^(?:minutes|mins|seconds|secs)\.?$', caseSensitive: false).hasMatch(text)) {
          // Drop tiny sentence fragments like "Minutes."
          continue;
        }
        final norm = text.toLowerCase();
        if (!seenSteps.contains(norm)) {
          seenSteps.add(norm);
          cleanedInstructions.add(item.copyWith(
            step: _cleanRepetition(text),
          ));
        }
      }
    }

    return original.copyWith(
      ingredients: cleanedIngredients,
      instructions: cleanedInstructions,
    );
  }

  static bool _appearsAsStandaloneHeading(String title, String rawContent) {
    final lines = rawContent.split('\n');
    final normTitle = title.trim().toLowerCase().replaceAll(RegExp(r'[:#]'), '').trim();
    if (normTitle.isEmpty) return false;

    for (final l in lines) {
      final clean = l.trim().toLowerCase().replaceAll(RegExp(r'[:#]'), '').trim();
      if (clean == normTitle && l.trim().length < 50) {
        return true;
      }
    }
    return false;
  }

  static bool _hasRepetitionLoop(String text) {
    if (text.length < 50) return false;
    final words = text.split(RegExp(r'\s+'));
    if (words.length < 12) return false;

    for (int w = 4; w <= (words.length ~/ 3).clamp(4, 25); w++) {
      for (int i = 0; i <= words.length - 3 * w; i++) {
        final p = words.sublist(i, i + w).join(' ');
        final n1 = words.sublist(i + w, i + 2 * w).join(' ');
        final n2 = words.sublist(i + 2 * w, i + 3 * w).join(' ');
        if (p.length >= 15 && p == n1 && p == n2) {
          return true;
        }
      }
    }
    return false;
  }

  static String _cleanRepetition(String text) {
    if (text.length < 50) return text;
    final words = text.split(RegExp(r'\s+'));
    if (words.length < 12) return text;

    for (int w = 4; w <= (words.length ~/ 3).clamp(4, 25); w++) {
      for (int i = 0; i <= words.length - 3 * w; i++) {
        final p = words.sublist(i, i + w).join(' ');
        final n1 = words.sublist(i + w, i + 2 * w).join(' ');
        final n2 = words.sublist(i + 2 * w, i + 3 * w).join(' ');
        if (p.length >= 15 && p == n1 && p == n2) {
          int count = 3;
          while (i + (count + 1) * w <= words.length &&
              words.sublist(i + count * w, i + (count + 1) * w).join(' ') == p) {
            count++;
          }
          final before = words.sublist(0, i + w).join(' ');
          final after = words.sublist(i + count * w).join(' ');
          return after.isNotEmpty ? '$before $after' : before;
        }
      }
    }
    return text;
  }

  static int? _parseInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    final s = val.toString();
    final m = RegExp(r'\d+').firstMatch(s);
    return m != null ? int.tryParse(m.group(0)!) : null;
  }

  static String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}...';
  }
}
