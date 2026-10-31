import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n.dart';

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

  void _switchLanguage() {
    setState(() {
      _language = (_language == 'ar') ? 'en' : 'ar';
    });
  }

  @override
  Widget build(BuildContext context) {
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
      home: ExperimentHome(
        language: _language,
        onToggleLanguage: _switchLanguage,
      ),
    );
  }
}

/// شاشة تجريبية للمرحلة 1 فقط: تثبت أن النصوص تعمل من ملفات الترجمة،
/// وأن الاتجاه RTL يعمل، وأن التبديل ع/EN فوري دون انكسار في الواجهة.
class ExperimentHome extends StatelessWidget {
  const ExperimentHome({
    super.key,
    required this.language,
    required this.onToggleLanguage,
  });

  final String language;
  final VoidCallback onToggleLanguage;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppStrings>(
      future: AppStrings.load(language),
      builder: (context, snapshot) {
        final strings = snapshot.data;
        if (strings == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // وجهة الزر تُعرض باسم اللغة المُراد التبديل إليها بلغتها الأصلية، والاسم نفسه من ملف الترجمة.
        final destination = strings.get('otherLanguage');
        return Scaffold(
          appBar: AppBar(title: Text(strings.get('appTitle'))),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    strings.get('appTitle'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(strings.get('welcome'), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    strings.get('experimentNote'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: onToggleLanguage,
                    child: Text(destination),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
