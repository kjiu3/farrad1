import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farrad/data/recipe_repository.dart';
import 'package:farrad/data/sample_recipes_loader.dart';
import 'package:farrad/l10n.dart';
import 'package:farrad/ui/search_screen.dart';

/// معيار المرحلة 2 رقم 2 (الحفظ) ورقم 3 (المدخلات المتطرفة) — واجهة.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppStrings strings;
  late InMemoryRecipeRepository repo;

  setUp(() async {
    strings = await AppStrings.load('ar');
    final seed = await SampleRecipeLoader.load();
    repo = InMemoryRecipeRepository(seed);
  });

  Future<void> pumpSearch(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      home: SearchScreen(strings: strings, repository: repo),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('البحث يعرض نتائج ويُفلتر بالنص', (tester) async {
    await pumpSearch(tester);
    // أول نتيجة مرئية في القائمة (الأحدث أولًا).
    expect(find.text('فتة حمص باللحم'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'كبسة');
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('كبسة دجاج بالبهارات'), findsOneWidget);
  });

  testWidgets('فلتر التصنيف (مشروبات) يعيد 2', (tester) async {
    await pumpSearch(tester);
    await tester.tap(find.text('الكل').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('مشروبات').last);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets('إنشاء وصفة ثم حفظها يُظهرها في النتائج (معيار 2)', (tester) async {
    await pumpSearch(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'وصفة اختبار الحفظ');
    await tester.enterText(fields.at(1), '15');
    await tester.enterText(fields.at(2), '2');
    await tester.enterText(fields.at(3), 'ملح');
    await tester.enterText(fields.at(4), '1');
    await tester.enterText(fields.at(5), 'امزج الملح بالماء');

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.get('saveRecipe')));
    await tester.pumpAndSettle();

    expect(find.text('وصفة اختبار الحفظ'), findsOneWidget);
    final list = await repo.list();
    expect(list.map((r) => r.title), contains('وصفة اختبار الحفظ'));
  });

  testWidgets('مدخل متطرف (عنوان 4000 حرف) يُقصُّ إلى 500 ولا يُجهاض (معيار 3)', (tester) async {
    await pumpSearch(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    // كتابة 4000 حرفًا: حدّ الحقل 500 يُقصّه قبل التحقق — مطابقة لحدّ القاعدة.
    await tester.enterText(fields.at(0), 'ط' * 4000);
    await tester.enterText(fields.at(1), '15');
    await tester.enterText(fields.at(2), '2');
    await tester.enterText(fields.at(3), 'ملح');
    await tester.enterText(fields.at(4), '1');
    await tester.enterText(fields.at(5), 'خطوة');

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.get('saveRecipe')));
    await tester.pumpAndSettle();

    // لا انكسار: الحفظ نجح، ووصفة بعنوان مُقصّ إلى 500 حرفًا في المستودع.
    final list = await repo.list();
    final titles = list.map((r) => r.title).where((t) => t.length > 1 && t.startsWith('ط'));
    expect(titles, isNotEmpty);
    expect(titles.first.length, lessThanOrEqualTo(500));
  });

  testWidgets('الحذف يتطلب تأكيدًا: الإلغاء يحفظ الوصفة والتأكيد يحذفها', (tester) async {
    await pumpSearch(tester);

    // افتح أول وصفة (فتة حمص باللحم — أول نتيجة).
    await tester.tap(find.text('فتة حمص باللحم'));
    await tester.pumpAndSettle();

    // اضغط زر الحذف → يظهر حوار تأكيد.
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    expect(find.text(strings.get('deleteConfirmTitle')), findsOneWidget);

    // الإلغاء: لا حذف — الوصفة ما زالت في المستودع.
    await tester.tap(find.text(strings.get('deleteConfirmNo')));
    await tester.pumpAndSettle();
    expect((await repo.list()).map((r) => r.title), contains('فتة حمص باللحم'));

    // التأكيد: حذف فعلي والوصفة تغيب عن المستودع وفي القائمة.
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.get('deleteConfirmYes')));
    await tester.pumpAndSettle();

    expect((await repo.list()).map((r) => r.title), isNot(contains('فتة حمص باللحم')));
    expect(find.text('فتة حمص باللحم'), findsNothing);
  });
}
