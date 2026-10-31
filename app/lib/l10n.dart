import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// تحميل نصوص الواجهة من ملفات الترجمة (فق ADR-0002).
/// كل نص في الواجهة يأتي من هذه الملفات — لا نصوص مضمّنة في الكود.
class AppStrings {
  AppStrings._(this.map);

  final Map<String, String> map;

  /// اللغات المدعومة في هذه المرحلة: العربية مصدر المفاتيح، ثم الإنجليزية.
  static const supported = <String>['ar', 'en'];

  /// العرض الافتراضي عربي واتجاه RTL (فق ADR-0002).
  static const defaultLanguage = 'ar';

  static bool isSupported(String language) => supported.contains(language);

  static Future<AppStrings> load(String language) async {
    final lang = isSupported(language) ? language : defaultLanguage;
    final raw = await rootBundle.loadString('assets/l10n/$lang.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return AppStrings._(
      decoded.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  /// إرجاع نص المفتاح، مع العودة إلى المفتاح نفسه عند غيابه (وحده يظهر أعذر الشاشة).
  String get(String key) => map[key] ?? key;
}
