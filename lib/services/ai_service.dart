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
  - <exact cuisine strictly from recipe in lowercase, e.g. "greek" for Greek recipes; NEVER "italian" unless explicitly Italian>
  - <course or category, e.g. main, dinner, appetizer>
  - <recipe keyword, e.g. flatbread>
credit: <author or site name>
source: <source url if present in text>
---

## Ingredients

- [ ] <general ingredient>

### <Component Subgroup Name (e.g. Garlic confit sauce, Spanakopita topping, Garnishes)>
- [ ] <subgroup ingredient>

## Instructions

### <Stage Name (e.g. Make the garlic confit sauce, Make the spanakopita topping, Assemble and bake the flatbread)>
- [ ] <detailed step description>

## Notes
* <helpful tip, variation, or serving suggestion>

Rules:
1. MANDATORY COMPLETENESS: Extract EVERY single ingredient and EVERY single instruction step across ALL pages of the input text. NEVER truncate, omit, or stop early.
2. Accurate Tags: Infer tags strictly from the recipe's stated cuisine and keywords. If the cuisine is Greek or Greek-Inspired, the cuisine tag MUST be "greek", NEVER "italian".
3. Checkboxes: Every ingredient and instruction step must start with "- [ ] ".
4. Subgroups & Stages: Always preserve component ingredient headers (### Component) and instruction stage headers (### Stage). Do not drop duplicate ingredients that belong to separate subgroups (e.g. feta in topping vs garnish).
5. Exclude nutritional breakdowns (calories/macros) from the notes.
6. Return only the raw Markdown with frontmatter. Do not wrap in markdown code blocks.
''';

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
    rawResult = rawResult.trim();

    // Default category fallback
    final cat = (categoryHint != null && categoryHint.isNotEmpty)
        ? categoryHint
        : 'Main';

    // Parse into Recipe object
    var recipe = Recipe.fromMarkdown('$cat/extracted-recipe.md', rawResult);

    // Robust validation and fallback recovery:
    // If the AI output truncated or omitted instructions/ingredients, use the semantic extractor fallback to recover
    final hasInputInstructions = RegExp(r'\b(instructions|directions|method|steps|preparation|make the|assemble)\b', caseSensitive: false).hasMatch(rawContent);
    if ((recipe.instructions.isEmpty && hasInputInstructions) || recipe.ingredients.isEmpty || recipe.ingredients.length < 3) {
      final fallbackMarkdown = InBrowserWasmService.semanticRecipeExtractorFallback(rawContent);
      final fallbackRecipe = Recipe.fromMarkdown('$cat/extracted-recipe.md', fallbackMarkdown);

      if (recipe.instructions.isEmpty && fallbackRecipe.instructions.isNotEmpty) {
        recipe = recipe.copyWith(instructions: fallbackRecipe.instructions);
      }
      if ((recipe.ingredients.isEmpty || recipe.ingredients.length < 3) && fallbackRecipe.ingredients.length > recipe.ingredients.length) {
        recipe = recipe.copyWith(ingredients: fallbackRecipe.ingredients);
      }
      if ((recipe.notes == null || recipe.notes!.isEmpty) && fallbackRecipe.notes != null && fallbackRecipe.notes!.isNotEmpty) {
        recipe = recipe.copyWith(notes: fallbackRecipe.notes);
      }
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
}
