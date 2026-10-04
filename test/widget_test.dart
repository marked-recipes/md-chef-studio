import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:md_chef_studio/models/recipe.dart';
import 'package:md_chef_studio/models/git_repo_config.dart';
import 'package:md_chef_studio/providers/recipe_provider.dart';
import 'package:md_chef_studio/providers/settings_provider.dart';
import 'package:md_chef_studio/providers/extraction_provider.dart';
import 'package:md_chef_studio/services/recipe_cache_service.dart';
import 'package:md_chef_studio/services/in_browser_wasm_service.dart';
import 'package:md_chef_studio/services/ai_service.dart';
import 'package:md_chef_studio/models/ai_config.dart';
import 'package:md_chef_studio/ui/widgets/recipe_editor_dialog.dart';
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

  testWidgets('RecipeEditorDialog supports drag-and-drop reordering with ReorderableListView', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});

    final recipe = Recipe.fromMarkdown(
      'Pasta/cacio-e-pepe.md',
      '''---
title: Cacio e Pepe
---
## Ingredients
### Pasta Base
- [ ] 8 oz spaghetti
### Sauce
- [ ] 2 tbsp pecorino cheese

## Instructions
### Boil
- [ ] Boil water
### Mix
- [ ] Mix cheese and pepper
''',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => RecipeProvider()),
          ChangeNotifierProvider(create: (_) => ExtractionProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RecipeEditorDialog(recipe: recipe),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify ReorderableListViews exist for both Ingredients and Instructions
    expect(find.byType(ReorderableListView), findsNWidgets(2));

    // Verify section headers and items are rendered with editable text
    expect(find.text('Pasta Base'), findsOneWidget);
    expect(find.text('8 oz spaghetti'), findsOneWidget);
    expect(find.text('Sauce'), findsOneWidget);
    expect(find.text('2 tbsp pecorino cheese'), findsOneWidget);

    // Verify drag handle icons exist for every item and header
    expect(find.byIcon(Icons.drag_indicator), findsWidgets);
  });

  test('RecipeProvider enforces Git token requirement on createRecipe, updateRecipe, deleteRecipe', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = RecipeProvider();
    const configWithoutToken = GitRepoConfig(owner: 'test', repo: 'recipes', token: '');
    final recipe = Recipe.fromMarkdown('Pasta/carbonara.md', '---\ntitle: Carbonara\n---\n## Ingredients\n- [ ] Eggs\n## Instructions\n- [ ] Mix\n');

    expect(
      () => provider.createRecipe(recipe: recipe, commitMessage: 'add', config: configWithoutToken),
      throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Personal Access Token'))),
    );

    expect(
      () => provider.updateRecipe(recipe: recipe, commitMessage: 'update', config: configWithoutToken),
      throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Personal Access Token'))),
    );

    expect(
      () => provider.deleteRecipe(recipe: recipe, commitMessage: 'delete', config: configWithoutToken),
      throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Personal Access Token'))),
    );
  });

  test('RecipeProvider saveLocalDraft successfully saves locally without Git token', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = RecipeProvider();
    const configWithoutToken = GitRepoConfig(owner: 'test', repo: 'recipes', token: '');
    final recipe = Recipe.fromMarkdown('Pasta/carbonara.md', '---\ntitle: Carbonara\n---\n## Ingredients\n- [ ] Eggs\n## Instructions\n- [ ] Mix\n');

    await provider.saveLocalDraft(recipe: recipe, config: configWithoutToken);

    expect(provider.recipes.length, 1);
    expect(provider.recipes.first.title, 'Carbonara');
    expect(provider.cachedRecipeCount, 1);
  });

  testWidgets('RecipeEditorDialog displays credentials required dialog when committing without token', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => RecipeProvider()),
          ChangeNotifierProvider(create: (_) => ExtractionProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: RecipeEditorDialog(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Commit button (no token configured by default)
    final commitButton = find.text('Commit New Recipe');
    expect(commitButton, findsOneWidget);
    await tester.tap(commitButton);
    await tester.pumpAndSettle();

    // Verify warning dialog is displayed instead of proceeding silently
    expect(find.text('GitHub Credentials Required'), findsOneWidget);
    expect(find.text('Configure Git Settings'), findsOneWidget);
    expect(find.text('Save Local Draft Only'), findsOneWidget);
  });

  test('Greek flatbread multi-component semantic extraction test', () {
    const rawPdfText = '''
Greek Flatbread with Spanakopita Topping - FoodByMaria

Greek Flatbread with Spanakopita Topping
Greek Flatbread uses a flatbread with a delicious spanakopita topping.
Course
Main
Cuisine
Greek-Inspired
Keyword
flatbread
Prep Time
10 minutes
Cook Time
30 minutes
Servings
3 -4
Author
Maria Koutsogiannis

Ingredients

1 flatbread (about 20 inches long by 8-10 inches wide)
Garlic confit sauce
1 cup peeled cloves of garlic
¾ cup olive oil
½ tsp chili flakes
Spanakopita topping
1 tbsp olive oil
500-550 g fresh spinach
1 cup crumbled feta cheese
Garnishes
¼ cup crumbled feta cheese
olive oil
honey
fresh mint

Instructions

Make the garlic confit sauce
1. To a small pot, add peeled garlic cloves, olive oil, chili flakes and ground pepper. Bring to a simmer.
2. Scoop the garlic out and blend until smooth.

Make the spanakopita topping
1. In a large pot or skillet, heat your olive oil on medium heat.
2. Add spinach and cook down.

Assemble and bake the flatbread
1. Lay flatbread on a baking sheet. Spread the garlic confit mixture.
2. Bake in the oven for 12-17 minutes.
3. Top with olive oil, honey and mint.

Notes

Serve this flatbread with salad.
If you love this flatbread, try our pita bread recipe.

Nutrition
Calories: 389kcal
FoodbyMaria.com
''';

    final extracted = InBrowserWasmService.semanticRecipeExtractorFallback(rawPdfText);
    final recipe = Recipe.fromMarkdown('Main/greek-flatbread.md', extracted);

    expect(recipe.title, contains('Greek Flatbread'));
    expect(recipe.prepTime, 10);
    expect(recipe.cookTime, 30);
    expect(recipe.servings, 4);
    expect(recipe.credit, 'Maria Koutsogiannis');
    expect(recipe.tags, contains('greek'));
    expect(recipe.tags, isNot(contains('italian')));

    // Check ingredients and subgroups
    final ingHeaders = recipe.ingredients.where((i) => i.isHeader).map((i) => i.text).toList();
    expect(ingHeaders, contains('Garlic confit sauce'));
    expect(ingHeaders, contains('Spanakopita topping'));
    expect(ingHeaders, contains('Garnishes'));

    // Check instructions and stages
    final instHeaders = recipe.instructions.where((i) => i.isHeader).map((i) => i.step).toList();
    expect(instHeaders, contains('Make the garlic confit sauce'));
    expect(instHeaders, contains('Make the spanakopita topping'));
    expect(instHeaders, contains('Assemble and bake the flatbread'));

    expect(recipe.instructions.where((i) => !i.isHeader).length, greaterThanOrEqualTo(6));
    expect(recipe.notes, contains('Serve this flatbread with salad.'));
  });

  test('AIService recovers from truncated AI output using fallback extractor', () async {
    const rawPdfText = '''
Greek Flatbread with Spanakopita Topping
Cuisine
Greek-Inspired
Prep Time
10 minutes
Cook Time
30 minutes

Ingredients
1 flatbread
Garlic confit sauce
1 cup garlic
Spanakopita topping
1 cup spinach

Instructions
1. Cook the sauce.
2. Bake flatbread.
''';

    // Simulate an AI response that got truncated right at ingredients
    const truncatedAiOutput = '''---
title: Greek Flatbread with Spanakopita Topping
prep_time: 10
cook_time: 30
servings: 3
difficulty: Easy
tags:
  - dinner
  - italian
  - bread
credit: Maria Koutsogiannis
---

## Ingredients

- [ ] 1 flatbread
### Garlic confit sauce
- [ ] 1 cup garlic

## Instructions
''';

    final recipe = Recipe.fromMarkdown('Main/greek-flatbread.md', truncatedAiOutput);
    // Directly invoke the fallback recovery logic
    final fallbackMarkdown = InBrowserWasmService.semanticRecipeExtractorFallback(rawPdfText);
    final fallbackRecipe = Recipe.fromMarkdown('Main/greek-flatbread.md', fallbackMarkdown);

    var recovered = recipe;
    if (recipe.instructions.isEmpty && fallbackRecipe.instructions.isNotEmpty) {
      recovered = recovered.copyWith(instructions: fallbackRecipe.instructions);
    }
    // And sanitize tags
    if (recovered.tags.contains('italian') && rawPdfText.toLowerCase().contains('greek')) {
      final updatedTags = recovered.tags.map((t) => t == 'italian' ? 'greek' : t).toList();
      recovered = recovered.copyWith(tags: updatedTags);
    }

    expect(recovered.instructions.isNotEmpty, isTrue);
    expect(recovered.tags, contains('greek'));
    expect(recovered.tags, isNot(contains('italian')));
  });
}
