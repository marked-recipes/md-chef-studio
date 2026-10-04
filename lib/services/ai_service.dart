import '../models/ai_config.dart';
import '../models/recipe.dart';
import 'in_browser_wasm_service.dart';
import 'local_ollama_service.dart';
import 'remote_ai_service.dart';

class AIService {
  static const String systemInstruction = '''
You are an expert culinary data extractor for MarkedChef (https://github.com/marked-recipes/recipes).
Extract the recipe from the provided input and output strictly in MarkedChef Markdown format:

---
title: Title of Recipe
prep_time: 15
cook_time: 25
servings: 4
difficulty: Easy
tags:
  - dinner
  - italian
credit: Chef Name or Site
source: https://example.com/recipe
---

## Ingredients

- [ ] 1 flatbread (about 20 inches)

### Sauce (optional subgroup)
- [ ] 1 cup ingredient
- [ ] 2 tablespoons olive oil

### Topping (optional subgroup)
- [ ] 1 cup crumbled feta cheese

### Garnishes (optional subgroup)
- [ ] 1/4 cup crumbled feta cheese
- [ ] olive oil

## Instructions

### Make the sauce (optional stage)
- [ ] Step 1 description.
- [ ] Step 2 description.

### Assemble and Bake (optional stage)
- [ ] Step 3 description.

## Notes
* Helpful notes, tips, variations, or serving suggestions.

Critical Extraction Rules:
- Completeness: Read the ENTIRE document across ALL pages. Never truncate or omit instruction steps or notes.
- Subgroups & Multi-stage ingredients: Recipes frequently use ingredients in multiple components (e.g. olive oil or feta cheese used in both a sauce and a garnish). Group ingredients under "### Subgroup Name" headers (e.g. "### Garlic confit sauce", "### Spanakopita topping", "### Garnishes"). Do NOT deduplicate or delete ingredients that legitimately appear in different subgroups!
- Instruction stages: If instructions have stage titles (e.g. "Make the garlic confit sauce", "Make the topping", "Assemble and bake"), preserve them as "### Stage Name" headers. Every single instruction step MUST be formatted as "- [ ] Step description."
- Notes: Capture all recipe notes, serving recommendations, and variations under "## Notes" as bullet points with "* ". Exclude raw nutritional/calorie macro breakdowns.
- Metadata: Extract prep_time, cook_time, servings as integer numbers whenever possible. Extract author into credit.
- Output: Do NOT wrap your whole response in triple backticks. Return the raw markdown directly.
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
    final recipe = Recipe.fromMarkdown('$cat/extracted-recipe.md', rawResult);

    // If sourceUrl provided and recipe source was empty, populate it
    if ((recipe.source == null || recipe.source!.isEmpty) && sourceUrl != null && sourceUrl.isNotEmpty) {
      recipe.source = sourceUrl;
    }

    // Generate proper file slug
    final slug = Recipe.slugify(recipe.title);
    recipe.fileName = '$slug.md';

    return recipe;
  }
}
