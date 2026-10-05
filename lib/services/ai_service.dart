import '../models/ai_config.dart';
import '../models/recipe.dart';
import 'in_browser_wasm_service.dart';
import 'local_ollama_service.dart';
import 'remote_ai_service.dart';

class AIService {
  static const String systemInstruction = '''
You are an expert recipe extractor for MarkedChef (https://github.com/marked-recipes/recipes).
Extract the recipe from the provided input and output strictly in MarkedChef Markdown format.

Required Format:
---
title: <Recipe Title>
prep_time: <prep time in minutes as integer, or omit>
cook_time: <cook time in minutes as integer, or omit>
servings: <servings count as integer, e.g. 4>
difficulty: <Easy, Medium, or Hard based on preparation complexity>
tags:
  - <exact cuisine strictly from recipe in lowercase, e.g. "chinese", "greek"; NEVER "italian" unless explicitly Italian>
  - <course or category, e.g. main, dinner, appetizer>
  - <recipe keyword, e.g. egg roll, bowl, flatbread>
credit: <author or site name>
source: <source url if present in text>
---

## Ingredients

### <Subgroup Header (if the recipe organizes ingredients into components, e.g. Wontons, Veggies, Pork, Sauce, To Serve, Dough, Filling)>
- [ ] <subgroup ingredient>

- [ ] <general ingredient only if the recipe does NOT contain subgroups>

## Instructions

- [ ] <numbered or sequential instruction step as ONE complete checkbox item>
- [ ] <next instruction step>

### <Stage Name (ONLY IF explicitly labeled as a distinct section/stage in the source recipe, e.g. "For the Dough")>
- [ ] <step description>

## Notes
* <verbatim introductory headnote, author description, or recipe tip>

Rules:
1. MANDATORY COMPLETENESS: Extract EVERY single ingredient and EVERY single instruction step across ALL pages of the input text. NEVER truncate, omit, or stop early.
2. Accurate Tags: Infer tags strictly from the recipe's stated cuisine and keywords. If the cuisine is Chinese, the cuisine tag MUST be "chinese"; if Greek, "greek"; NEVER "italian" unless explicitly Italian.
3. Checkboxes: Every ingredient and instruction step must start with "- [ ] ".
4. Preserve All Ingredient Subgroup Headers: If the source recipe organizes ingredients under subheadings or component titles (e.g., "Wontons:", "Veggies:", "Pork:", "Sauce:", "To Serve:", "For the sauce:", "Dough:", "Filling:", "Garnishes:"), you MUST output every single subheading as a markdown header (e.g., `### Wontons`, `### Veggies`, `### Pork`, `### Sauce`, `### To Serve`). NEVER omit these subheadings or flatten the ingredients into a single unsectioned list. Preserve all ingredients even if repeated across separate subgroups (e.g., oil in veggies vs pork).
5. Instructions Structure & No Hallucinated Headers:
   - Output standard sequential numbered steps directly as checkbox items (`- [ ] `) under `## Instructions`.
   - DO NOT invent, fabricate, or hallucinate stage headers (e.g., NEVER create headers like `### Cook the eggs`, `### Cook the wontons`, `### Cook the veggies`, `### Cook the pork and sauce`, `### Assemble and serve` if they are not explicitly standalone section titles in the source recipe).
   - ONLY include `### Stage Name` in Instructions if the source text itself explicitly contains named section titles separating major phases of cooking (e.g., "Part 1: The Dough"). If directions are simply numbered steps (1, 2, 3...), output them directly as sequential checkbox steps.
   - Each numbered or sequential step from the source document MUST be ONE complete checkbox item. NEVER split a single numbered step into multiple sentence-fragment checkboxes.
6. Verbatim Notes & Headnotes (NEVER Summarize or Distort):
   - If the recipe includes an introductory description, author's story/headnote, or chef's note (such as background on why the dish was created or personal commentary from the author), you MUST include it under `## Notes` VERBATIM (word-for-word).
   - NEVER summarize, paraphrase, shorten, or reword author headnotes into artificial tips (e.g., do NOT turn "If I'm getting takeout, I'm ordering egg rolls. So I took the flavors..." into "If you are getting takeout, you can order egg rolls").
   - Do NOT invent tips or extract parenthetical ingredient comments into separate tips.
   - Output the complete original paragraph verbatim as: `* <verbatim text>`.
   - Exclude nutritional breakdowns (calories/macros) and web boilerplate from notes.
7. Return only the raw Markdown with frontmatter. Do not wrap in markdown code blocks.
8. Handling Print-Margin Word Truncation: If text from printed or scanned documents has words slightly clipped at line ends (e.g. 'browr' for 'brown', 'stirri' for 'stirring', 'the sa' for 'the sauce', 'coo' for 'cook'), reconstruct the complete word naturally from cooking context.
9. No Repetition Loops: NEVER repeat words, phrases, or sentences in a loop. Once a step is described, proceed directly to the next step.
''';

  /// Detects and collapses runaway repetitive n-gram loops produced by small autoregressive models
  static String sanitizeRepetitionLoops(String text) {
    if (text.length < 60) return text;

    final lines = text.split('\n');
    final sanitizedLines = lines.map((line) {
      if (line.length < 60) return line;

      final words = line.split(RegExp(r'\s+'));
      if (words.length < 12) return line;

      final maxWindow = (words.length ~/ 3).clamp(4, 30);
      for (int w = 4; w <= maxWindow; w++) {
        for (int i = 0; i <= words.length - 3 * w; i++) {
          final phrase = words.sublist(i, i + w).join(' ');
          final next1 = words.sublist(i + w, i + 2 * w).join(' ');
          final next2 = words.sublist(i + 2 * w, i + 3 * w).join(' ');

          if (phrase.length >= 15 && phrase == next1 && phrase == next2) {
            int repeatCount = 3;
            while (i + (repeatCount + 1) * w <= words.length &&
                words.sublist(i + repeatCount * w, i + (repeatCount + 1) * w).join(' ') == phrase) {
              repeatCount++;
            }
            final before = words.sublist(0, i + w).join(' ');
            final afterWords = words.sublist(i + repeatCount * w);
            final after = afterWords.join(' ');
            return after.isNotEmpty ? '$before $after' : before;
          }
        }
      }
      return line;
    }).toList();

    return sanitizedLines.join('\n');
  }

  /// Extracts recipe from raw source text using the configured AI engine
  static Future<Recipe> extractRecipe({
    required AIConfig config,
    required String rawContent,
    String? categoryHint,
    String? sourceUrl,
  }) async {
    final prompt = '''
Please extract and format the entire cooking recipe from the source text into MarkedChef format.
Ensure ALL pages are processed completely, preserving component ingredient subgroups (e.g. sauces, toppings, garnishes), all instruction steps and stages, and all recipe notes/tips.
${sourceUrl != null && sourceUrl.isNotEmpty ? 'Source URL: $sourceUrl\n' : ''}
${categoryHint != null && categoryHint.isNotEmpty ? 'Suggested Category: $categoryHint\n' : ''}

SOURCE CONTENT:
$rawContent
''';

    String rawResult = '';

    switch (config.activeType) {
      case AIServiceType.inBrowserWasm:
        rawResult = await InBrowserWasmService.generate(
          prompt: prompt,
          systemPrompt: systemInstruction,
        );
        break;

      case AIServiceType.localOllama:
        rawResult = await LocalOllamaService.generate(
          baseUrl: config.ollamaUrl,
          model: config.ollamaModel,
          prompt: prompt,
          systemPrompt: systemInstruction,
        );
        break;

      case AIServiceType.remoteGemini:
        rawResult = await RemoteAIService.generateGemini(
          apiKey: config.geminiApiKey,
          model: config.geminiModel,
          prompt: prompt,
          systemInstruction: systemInstruction,
        );
        break;

      case AIServiceType.remoteOpenAI:
        rawResult = await RemoteAIService.generateOpenAI(
          baseUrl: config.openAiUrl,
          apiKey: config.openAiApiKey,
          model: config.openAiModel,
          prompt: prompt,
          systemPrompt: systemInstruction,
        );
        break;
    }

    // Clean up result if wrapped in markdown blocks
    rawResult = rawResult.trim();
    if (rawResult.startsWith('```markdown')) {
      rawResult = rawResult.substring(11);
    } else if (rawResult.startsWith('```')) {
      rawResult = rawResult.substring(3);
    }
    if (rawResult.endsWith('```')) {
      rawResult = rawResult.substring(0, rawResult.length - 3);
    }
    rawResult = sanitizeRepetitionLoops(rawResult.trim());

    // Default category fallback
    final cat = (categoryHint != null && categoryHint.isNotEmpty)
        ? categoryHint
        : 'Main';

    // Parse into Recipe object
    var recipe = Recipe.fromMarkdown('$cat/extracted-recipe.md', rawResult);

    // Sanitize hallucinated instruction stage headers that were not in the source text
    if (recipe.instructions.any((s) => s.isHeader)) {
      final cleanedInstructions = sanitizeInstructionHeaders(
        recipe.instructions,
        rawContent,
      );
      recipe = recipe.copyWith(instructions: cleanedInstructions);
    }

    // Sanitize hallucinated cuisine tags
    final lowerRaw = rawContent.toLowerCase();
    if (recipe.tags.contains('italian') && !lowerRaw.contains('italian') && (lowerRaw.contains('greek') || lowerRaw.contains('greek-inspired'))) {
      final updatedTags = recipe.tags.map((t) => t == 'italian' ? 'greek' : t).toList();
      recipe = recipe.copyWith(tags: updatedTags);
    }

    // If sourceUrl provided and recipe source was empty, populate it
    if ((recipe.source == null || recipe.source!.isEmpty) && sourceUrl != null && sourceUrl.isNotEmpty) {
      recipe = recipe.copyWith(source: sourceUrl);
    }

    // Generate proper file slug
    final slug = Recipe.slugify(recipe.title);
    recipe = recipe.copyWith(fileName: '$slug.md');

    return recipe;
  }

  /// Checks if a heading appears as a standalone line or section header in the raw source text
  static bool appearsAsStandaloneHeading(String title, String rawContent) {
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

  /// Strips hallucinated instruction stage headers that were not present in the source text
  static List<RecipeInstructionItem> sanitizeInstructionHeaders(
    List<RecipeInstructionItem> instructions,
    String rawContent,
  ) {
    if (!instructions.any((s) => s.isHeader)) {
      return instructions;
    }

    final cleaned = <RecipeInstructionItem>[];
    for (final item in instructions) {
      if (item.isHeader) {
        final headerText = item.step.trim();
        final isStandalone = appearsAsStandaloneHeading(headerText, rawContent);
        final isGenericActionHeader = RegExp(r'^(?:cook|make|prepare|heat|bake|fry|chop|mix)\s+the\b', caseSensitive: false).hasMatch(headerText);

        if (!isStandalone || isGenericActionHeader) {
          // Fabricated header - drop it
          continue;
        }
        cleaned.add(item);
      } else {
        final stepText = item.step.trim();
        // Filter out accidental tiny fragment bullets from split sentences like "Minutes."
        if (stepText.length < 5 || RegExp(r'^(?:minutes|mins|seconds|secs)\.?$', caseSensitive: false).hasMatch(stepText)) {
          continue;
        }
        cleaned.add(item);
      }
    }

    return cleaned;
  }
}

