import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farrad/main.dart';

/// معيار المرحلة 1 رقم 4: زر تبديل اللغة يعمل — ع/EN فوريًا دون انكسار،
/// والعودة تكسر شيئًا لا (اختبار الاتجاهين).
void main() {
  testWidgets('التبديل من العربية إلى الإنجليزية ثم العودة', (tester) async {
    await tester.pumpWidget(const FarradApp());
    await tester.pumpAndSettle();

    // البداية: عربية RTL مع نص من ملف الترجمة العربية.
    final rtlElement = tester.element(find.textContaining('أهلاً'));
    expect(Directionality.of(rtlElement), TextDirection.rtl);

    // الضغط على زر التبديل: يصبح LTR والنص إنجليزيًا من ملف الترجمة.
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    final ltrElement = tester.element(find.textContaining('Welcome'));
    expect(Directionality.of(ltrElement), TextDirection.ltr);
    expect(find.textContaining('أهلاً'), findsNothing);

    // العودة إلى العربية تعمل أيضًا دون انكسار.
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    final backElement = tester.element(find.textContaining('أهلاً'));
    expect(Directionality.of(backElement), TextDirection.rtl);
    expect(find.textContaining('Welcome'), findsNothing);
  });
}
