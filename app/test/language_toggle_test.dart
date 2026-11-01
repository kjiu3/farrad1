import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farrad/main.dart';

/// معيار المرحلة 1 رقم 4 (ما زال مثبتًا على الشاشة الرئيسية الجديدة):
/// زر تبديل اللغة works — دورة كاملة ع↔EN دون انكسار.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('التبديل من العربية إلى الإنجليزية ثم العودة', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const FarradApp());
    await tester.pumpAndSettle();

    final rtlElement = tester.element(find.textContaining('فرّاد'));
    expect(Directionality.of(rtlElement), TextDirection.rtl);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    final ltrElement = tester.element(find.textContaining('Farrad'));
    expect(Directionality.of(ltrElement), TextDirection.ltr);
    expect(find.textContaining('فرّاد'), findsNothing);

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    final backElement = tester.element(find.textContaining('فرّاد'));
    expect(Directionality.of(backElement), TextDirection.rtl);
    expect(find.textContaining('Farrad'), findsNothing);
  });
}
