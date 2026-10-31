/// محرك تطبيع النص العربي للبحث — وفق PRD §4.2: «تيسير بسيط:
/// تجاهل التشكيل، وتقارب ث/ت، ه/ة، ي/ى».
///
/// القواعد كلها موثقة ومُختبرة في test/normalizer_test.dart:
/// 1. تجاهل التشكيل: يُحذف التطويل (U+0640) والحركات (U+064B..U+065F)
///    والألف الخنجرية (U+0670) وعلامات القرآن (U+06D6..U+06ED).
/// 2. توحيد الهمزات على المقعد: أ إ آ ٱ تصبح ألفًا بلا همزة (ا).
/// 3. تقارب المقارنات وفق PRD المصدر: ث تصبح ت، وتظل الصاعدة الأخرى كما هي.
/// 4. ة تصبح ه، وى تصبح ي.
/// 5. تُفسَّر كل أنواع المسافات في مسافة واحدة وتُقصَّ الطرفان.
/// 6. الحروف اللاتينية تصبح بحال الصغيرة — لاستقبال نص مختلط دون ضرر.
///
/// الدالة نقية: لا حالة ولا إجهاض — لكل مدخل خرج نصي، والمخرج للمقارنة
/// فقط لا للعرض.
library;

/// التطويل المؤقت — محرف لا قيمة له في المقارنة.
const int _tatweelCode = 0x0640;

bool _isDiacritic(int code) {
  // U+064B..U+0652: حركات التشكيل القياسية + السكون.
  // U+0653..U+065F أدوات تلاوة إضافية تُهمل معها كلمات العرض.
  // U+0670: ألف خنجرية. U+06D6..U+06ED علامات قرآن.
  return (code >= 0x064B && code <= 0x065F) ||
      code == 0x0670 ||
      (code >= 0x06D6 && code <= 0x06ED);
}

String normalizeArabic(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();

  for (final rune in lower.runes) {
    if (rune == _tatweelCode) continue; // التطويل المؤقت.
    if (_isDiacritic(rune)) continue;

    final ch = String.fromCharCode(rune);
    switch (ch) {
      case 'أ':
      case 'إ':
      case 'آ':
      case 'ٱ':
        buffer.write('ا');
        continue;
      case 'ث':
        buffer.write('ت');
        continue;
      case 'ة':
        buffer.write('ه');
        continue;
      case 'ى':
        buffer.write('ي');
        continue;
      default:
        buffer.write(ch);
    }
  }

  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}
