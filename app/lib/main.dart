import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/recipe_repository.dart';
import 'data/sample_recipes_loader.dart';
import 'l10n.dart';
import 'models/recipe.dart';
import 'ui/search_screen.dart';

void main() => runApp(const FarradApp());

/// الجذر كما في ADR-0002: العربية افتراضية (RTL)، لكل نص من ملفات الترجمة،
/// والاتجاه ينتج تلقائيًا من اللغة. التبديل بين اللغتين فوري من الشاشة.
class FarradApp extends StatefulWidget {
  const FarradApp({super.key});

  @override
  State<FarradApp> createState() => _FarradAppState();
}

class _FarradAppState extends State<FarradApp> {
  String _language = AppStrings.defaultLanguage;
  List<Recipe>? _seed;
  RecipeRepository? _repository;

  @override
  void initState() {
    super.initState();
    _loadSeed();
  }

  Future<void> _loadSeed() async {
    final seed = await SampleRecipeLoader.load();
    RecipeRepository repo;
    try {
      repo = SharedPreferencesRecipeRepository(seed: seed);
      await repo.list(); // trigger init; if it hangs, future never completes (handled by caller's timeout)
    } catch (_) {
      repo = InMemoryRecipeRepository(seed);
    }
    if (!mounted) return;
    setState(() {
      _seed = seed;
      _repository = repo;
    });
  }

  void _switchLanguage() {
    setState(() {
      _language = (_language == 'ar') ? 'en' : 'ar';
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppStrings>(
      future: AppStrings.load(_language),
      builder: (context, snapshot) {
        if (!snapshot.hasData || _seed == null || _repository == null) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: Text('...'))),
          );
        }
        final strings = snapshot.data!;
        return MaterialApp(
          title: 'Farrad',
          debugShowCheckedModeBanner: false,
          locale: Locale(_language),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SearchScreen(
            strings: strings,
            repository: _repository!,
            onToggleLanguage: _switchLanguage,
            otherLanguageLabel: strings.get('otherLanguage'),
          ),
        );
      },
    );
  }
}
