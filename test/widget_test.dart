import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:md_chef_studio/models/recipe.dart';
import 'package:md_chef_studio/services/recipe_cache_service.dart';
import 'package:md_chef_studio/main.dart';

void main() {
  testWidgets('MD Chef Studio smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MDChefStudioApp());
    await tester.pump();

    expect(find.text('MD Chef Studio'), findsWidgets);
    expect(find.text('Cacio e Pepe'), findsWidgets);
  });

  test('Recipe Markdown parse and serialize test', () {
    const sampleMarkdown = '''---
title: Cacio e Pepe
prep_time: 10
cook_time: 20
servings: 2 - 3
difficulty: Easy
tags:
  - italian
  - pasta
credit: Ali
source: https://www.gimmesomeoven.com/cacio-e-pepe/
---

## Ingredients

- [ ] 8 ounces uncooked pasta
- [ ] 2 tablespoons butter

## Instructions

- [ ] Boil the pasta water.
- [ ] Toss the pasta.

## Notes
* Best served hot!
''';

    final recipe = Recipe.fromMarkdown('Pasta/cacio-e-pepe.md', sampleMarkdown);

    expect(recipe.title, 'Cacio e Pepe');
    expect(recipe.category, 'Pasta');
    expect(recipe.fileName, 'cacio-e-pepe.md');
    expect(recipe.prepTime, 10);
    expect(recipe.cookTime, 20);
    expect(recipe.difficulty, 'Easy');
    expect(recipe.tags, contains('italian'));
    expect(recipe.tags, contains('pasta'));
    expect(recipe.ingredients.length, 2);
    expect(recipe.instructions.length, 2);
    expect(recipe.notes, contains('Best served hot!'));

    final serialized = recipe.toMarkdown();
    expect(serialized, contains('title: Cacio e Pepe'));
    expect(serialized, contains('## Ingredients'));
    expect(serialized, contains('- [ ] 8 ounces uncooked pasta'));
    expect(serialized, contains('## Instructions'));
    expect(serialized, contains('- [ ] Boil the pasta water.'));
  });

  test('Recipe section headers in Ingredients and Instructions test', () {
    const pizzaMarkdown = '''---
title: Pizza
prep_time: 24 hours+
cook_time: 7-10 minutes
servings: 4
difficulty: Medium
tags:
  - italian
  - pizza
---

## Ingredients

### Dough
- [ ] 280 grams flour
- [ ] 100ml water

### Toppings
- [ ] 100g mozzarella

## Instructions

### Dough
- [ ] Melt the yeast in half a cup of water
- [ ] Knead for 10-15 minutes

### Assembly & Baking
- [ ] Stretch dough by hand
- [ ] Bake for 7-10 minutes
''';

    final recipe = Recipe.fromMarkdown('Pizza/pizza.md', pizzaMarkdown);

    expect(recipe.title, 'Pizza');
    expect(recipe.category, 'Pizza');

    // Ingredients headers
    expect(recipe.ingredients.length, 5); // 2 headers + 3 ingredients
    expect(recipe.ingredients[0].text, 'Dough');
    expect(recipe.ingredients[0].isHeader, true);
    expect(recipe.ingredients[1].text, '280 grams flour');
    expect(recipe.ingredients[1].isHeader, false);
    expect(recipe.ingredients[3].text, 'Toppings');
    expect(recipe.ingredients[3].isHeader, true);

    // Instructions headers
    expect(recipe.instructions.length, 6); // 2 headers + 4 steps
    expect(recipe.instructions[0].step, 'Dough');
    expect(recipe.instructions[0].isHeader, true);
    expect(recipe.instructions[1].step, 'Melt the yeast in half a cup of water');
    expect(recipe.instructions[1].isHeader, false);
    expect(recipe.instructions[3].step, 'Assembly & Baking');
    expect(recipe.instructions[3].isHeader, true);

    // Roundtrip markdown serialization
    final markdown = recipe.toMarkdown();
    expect(markdown, contains('### Dough'));
    expect(markdown, contains('- [ ] 280 grams flour'));
    expect(markdown, contains('### Toppings'));
    expect(markdown, contains('### Assembly & Baking'));
    // Ensure headers do not get wrapped in checkbox "- [ ] ### Dough"
    expect(markdown, isNot(contains('- [ ] ###')));
  });

  test('RecipeCacheService saves, loads, and clears cached recipes for delta-sync', () async {
    SharedPreferences.setMockInitialValues({});
    const repoKey = 'test_owner__test_repo__main';

    final recipe1 = Recipe.fromMarkdown(
      'Pasta/cacio-e-pepe.md',
      '---\ntitle: Cacio e Pepe\n---\n## Ingredients\n- [ ] Pasta\n## Instructions\n- [ ] Boil\n',
      sha: 'sha111',
    );
    final recipe2 = Recipe.fromMarkdown(
      'Pizza/pizza.md',
      '---\ntitle: Pizza\n---\n## Ingredients\n### Dough\n- [ ] Flour\n## Instructions\n### Dough\n- [ ] Knead\n',
      sha: 'sha222',
    );

    // Save batch
    await RecipeCacheService.saveRecipesBatch(repoKey, [recipe1, recipe2]);

    // Verify manifest
    final manifest = await RecipeCacheService.loadManifest(repoKey);
    expect(manifest.length, 2);
    expect(manifest['Pasta/cacio-e-pepe.md'], 'sha111');
    expect(manifest['Pizza/pizza.md'], 'sha222');

    // Verify loadCachedRecipes
    final loaded = await RecipeCacheService.loadCachedRecipes(repoKey);
    expect(loaded.length, 2);
    final loadedPizza = loaded.firstWhere((r) => r.repoPath == 'Pizza/pizza.md');
    expect(loadedPizza.title, 'Pizza');
    expect(loadedPizza.sha, 'sha222');
    expect(loadedPizza.ingredients.first.isHeader, true);

    // Update single recipe with new Git SHA
    final updatedRecipe1 = recipe1.copyWith(sha: 'sha111_updated');
    await RecipeCacheService.saveRecipe(repoKey, updatedRecipe1);
    final updatedManifest = await RecipeCacheService.loadManifest(repoKey);
    expect(updatedManifest['Pasta/cacio-e-pepe.md'], 'sha111_updated');

    // Delete single recipe
    await RecipeCacheService.deleteRecipe(repoKey, 'Pasta/cacio-e-pepe.md');
    final afterDeleteManifest = await RecipeCacheService.loadManifest(repoKey);
    expect(afterDeleteManifest.containsKey('Pasta/cacio-e-pepe.md'), false);
    expect(afterDeleteManifest.containsKey('Pizza/pizza.md'), true);

    // Clear cache
    await RecipeCacheService.clearCache(repoKey);
    final emptyManifest = await RecipeCacheService.loadManifest(repoKey);
    expect(emptyManifest.isEmpty, true);
  });
}
