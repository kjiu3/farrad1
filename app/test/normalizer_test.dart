import 'package:flutter_test/flutter_test.dart';

import 'package:farrad/text/arabic_normalizer.dart';

/// اختبارات قواعد التطبيع — كل قاعدة موثقة في arabic_normalizer.dart.
void main() {
  test('تجاهل التشكيل: نص مُشكَّل يساوي نصًا سائبًا', () {
    expect(
      normalizeArabic('كَبْسَةٌ مَطْبُوخَة'),
      normalizeArabic('كبسة مطبوخة'),
    );
    expect(normalizeArabic('طَعَام'), 'طعام');
  });

  test('التطويل (ـ) يُحذف', () {
    expect(normalizeArabic('كـــبـــســـة'), 'كبسه');
    expect(normalizeArabic('مآذنَـــه'), 'ماذنه');
  });

  test('توحيد الهمزات: أ إ آ ٱ تصبح ا', () {
    expect(normalizeArabic('أرز'), normalizeArabic('ارز'));
    expect(normalizeArabic('إطباق'), 'اطباق');
    expect(normalizeArabic('آرد'), 'ارد');
    expect(normalizeArabic('ٱستخدام'), 'استخدام');
  });

  test('تقارب ث/ت: البحث عن «توم» يجد «ثوم» والعكس', () {
    expect(normalizeArabic('ثوم'), normalizeArabic('توم'));
    expect(normalizeArabic('ثلج'), 'تلج');
  });

  test('ة/ه و ى/ي متكافئان', () {
    expect(normalizeArabic('بطاطة'), normalizeArabic('بطاطه'));
    expect(normalizeArabic('ملى'), normalizeArabic('ملي'));
    expect(normalizeArabic('شعرة'), 'شعره');
  });

  test('المسافات المتعددة تُجمَّع ويُقصُّ الطرفان', () {
    expect(normalizeArabic('  رواء   مقلوبة \t\n '), 'رواء مقلوبه');
    expect(normalizeArabic('\n\n\t أرز بالكمية\t'), 'ارز بالكميه');
  });

  test('الحروف اللاتينية تصبح بحال الصغيرة', () {
    expect(normalizeArabic('Rice'), 'rice');
    expect(normalizeArabic('RICE'), normalizeArabic('rice'));
  });

  test('مدخل متطرف الضخامة لا يُجهاض', () {
    final long = 'طعام ' * 3000;
    final result = normalizeArabic(long);
    expect(result, isNotEmpty);
    expect(result.contains('طعام'), isTrue);
    expect(normalizeArabic(result), result); // ثبات عبر التكرار.
  });

  test('رموز ومحارف مقاتلة لا تُنَحَف', () {
    expect(normalizeArabic('٣٥٥(@#)'), '٣٥٥(@#)');
    expect(normalizeArabic(''), '');
  });

  test('ثبات عبر التكرار (idempotency) عبر عينة واسعة', () {
    const samples = [
      'كَبْسَة بالـلَّحْم',
      'أكلات شعبية مع تنويعات إقليمية',
      'ثوم وزيت وملح وخ!',
      'شُوربة العدس المجروش',
      'معكرونة بالبيضاء',
    ];
    for (final s in samples) {
      expect(normalizeArabic(normalizeArabic(s)), normalizeArabic(s));
    }
  });
}
