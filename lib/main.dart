import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/extraction_provider.dart';
import 'providers/recipe_provider.dart';
import 'providers/settings_provider.dart';
import 'theme/app_theme.dart';
import 'ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MDChefStudioApp());
}

class MDChefStudioApp extends StatelessWidget {
  const MDChefStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => ExtractionProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'MD Chef Studio',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: settings.themeMode,
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
