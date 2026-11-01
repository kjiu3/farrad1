import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farrad/main.dart';

/// معيار المرحلة 1 رقم 2 (ما زال مثبتًا على الشاشة الرئيسية الجديدة):
/// الشاشة الرئيسية تعرض نصها العربي باتجاه RTL.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('النص العربي على الشاشة الرئيسية باتجاه RTL', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const FarradApp());
    await tester.pumpAndSettle();

    final title = find.textContaining('فرّاد');
    expect(title, findsWidgets);

    final element = tester.element(title.first);
    expect(Directionality.of(element), TextDirection.rtl);
  });
}
