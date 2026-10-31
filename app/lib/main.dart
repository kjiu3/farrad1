import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n.dart';

void main() => runApp(const FarradApp());

/// الجذر كما في ADR-0002: العربية افتراضية (RTL)، لكل نص من ملفات الترجمة،
/// والاتجاه ينتج تلقائيًا من اللغة.
class FarradApp extends StatefulWidget {
  const FarradApp({super.key});

  @override
  State<FarradApp> createState() => _FarradAppState();
}

class _FarradAppState extends State<FarradApp> {
  // في هذه المرحلة اللغة ثابتة على العربية؛ زر التبديل يأتي في PR التالي
  // وسيتحول الحقل عندها إلى متغير بالإعداد.
  final String _language = AppStrings.defaultLanguage;

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
      home: ExperimentHome(language: _language),
    );
  }
}

/// شاشة تجريبية للمرحلة 1 فقط: تثبت أن النصوص تعمل من ملفات الترجمة
/// وأن الاتجاه العربي RTL عامل قبل أي ميزة حغية.
class ExperimentHome extends StatelessWidget {
  const ExperimentHome({super.key, required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppStrings>(
      future: AppStrings.load(language),
      builder: (context, snapshot) {
        final strings = snapshot.data;
        if (strings == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
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
                  Text(
                    strings.get('welcome'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.get('experimentNote'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
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
