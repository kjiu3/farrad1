import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farrad/main.dart';

/// معيار المرحلة 1 رقم 2: الشاشة التجريبية تعرض نصها العربي باتجاه RTL.
void main() {
  testWidgets('النص العربي على الشاشة باتجاه RTL', (tester) async {
    await tester.pumpWidget(const FarradApp());
    await tester.pumpAndSettle();

    // نص الترحيب يأتي من ملف الترجمة العربية.
    final welcome = find.textContaining('أهلاً');
    expect(welcome, findsOneWidget);

    final textWidget = tester.widget<Text>(welcome);
    expect(textWidget.data, contains('أهلاً'));

    // الاتجاه مُشتق من اللغة العربية الافتراضية (فق ADR-0002).
    final element = tester.element(welcome);
    expect(Directionality.of(element), TextDirection.rtl);
  });
}
