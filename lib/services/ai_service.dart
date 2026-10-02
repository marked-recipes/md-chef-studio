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

- [ ] 1 cup ingredient
- [ ] 2 tablespoons olive oil

## Instructions

- [ ] Step 1 description.
- [ ] Step 2 description.

## Notes
* Helpful notes or tips (optional).

Formatting guidelines:
- Every ingredient MUST begin with "- [ ] ".
- If ingredients are grouped, use "### Group Name" headers (e.g. "### Dough", "### Sauce").
- Every instruction step MUST begin with "- [ ] ".
- If instructions are grouped into stages, use "### Stage Name" headers (e.g. "### Dough", "### Assembly & Baking").
- Numbers for prep_time and cook_time should be integers in minutes when possible.
- Do NOT wrap your whole response in triple backticks. Return the raw markdown directly.
''';

  /// Extracts recipe from raw source text using the configured AI engine
  static Future<Recipe> extractRecipe({
    required AIConfig config,
    required String rawContent,
    String? categoryHint,
    String? sourceUrl,
  }) async {
    final prompt = '''
Please extract and format the following cooking recipe into MarkedChef format.
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
