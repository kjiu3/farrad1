import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:farrad/l10n.dart';

/// معيار المرحلة 1 رقم 3: ملفا ترجمة ع/EN بنفس المفاتيح تمامًا (بنفس ترتيب ADR-0002).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('مفاتيح العربية والإنجليزية متطابقة وغير فارغة', () async {
    final baseKeys = <String>{};

    for (final language in AppStrings.supported) {
      final raw = await rootBundle.loadString('assets/l10n/$language.json');
      final map = json.decode(raw) as Map<String, dynamic>;

      expect(map, isNotEmpty, reason: 'ملف $language فارغ');

      // لا قيمة فارغة في أي ملف.
      for (final entry in map.entries) {
        expect(
          (entry.value as String).trim(),
          isNotEmpty,
          reason: 'قيمة فارغة للمفتاح $entry في الملف $language',
        );
      }

      if (language == AppStrings.defaultLanguage) {
        baseKeys
          ..clear()
          ..addAll(map.keys);
      } else {
        for (final key in map.keys) {
          expect(
            baseKeys.contains(key),
            isTrue,
            reason: 'مفتاح زائد في $language: $key',
          );
        }
        for (final key in baseKeys) {
          expect(
            map.containsKey(key),
            isTrue,
            reason: 'مفتاح مفقود في $language: $key',
          );
        }
      }
    }
  });

  test('تحميل نصوص عربية من الملف، والعودة للغة الافتراضية عند لغة غير معروفة', () async {
    final arabic = await AppStrings.load('ar');
    expect(arabic.get('appTitle'), contains('فر'));

    final unknown = await AppStrings.load('xx');
    final arabicAgain = await AppStrings.load(AppStrings.defaultLanguage);
    expect(unknown.get('appTitle'), arabicAgain.get('appTitle'));
  });
}
