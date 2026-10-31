import 'package:flutter_test/flutter_test.dart';

import 'package:farrad/data/sample_recipes_loader.dart';
import 'package:farrad/models/recipe.dart';
import 'package:farrad/search/search_engine.dart';

/// معيار المرحلة 2 رقم 1: اختبارات بحث على 20 وصفة نموذجية.
/// تطابق دقيق، بلا تشكيل، مع تغيير حرف (ث/ت، ه/ة، ي/ى)، و«لا نتائج».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Recipe> fixtures;

  setUpAll(() async {
    fixtures = await SampleRecipeLoader.load();
  });

  group('الدفعة النموذجية نفسها', () {
    test('عشرون وصفة كلها صالحة بلا رفض', () {
      expect(fixtures, hasLength(20));
      // لا تكرار معرفات ولا عناوين تحملها مبنيان غير قابلين للاختبار.
      expect(fixtures.map((r) => r.id).toSet(), hasLength(20));
      expect(fixtures.map((r) => r.title).toSet(), hasLength(20));
    });
  });

  group('تطابق دقيق', () {
    test('عنوان دقيق يعيد الوصفة نفسها مرتبة الأولى', () {
      final result = const SearchEngine().search(
        fixtures,
        const RecipeQuery(text: 'كبسة دجاج بالبهارات'),
      );
      expect(result.recipes.first.title, 'كبسة دجاج بالبهارات');
      // عنوان ثنائي الكلمات يُقسم كلمتين — كلتاهما تصيب العنوان.
      expect(result.recipes, hasLength(1));
    });

    test('بحث بكلمة مكون (ثوم) يجد الوصفات المتوافقة', () {
      final result = const SearchEngine().search(
        fixtures,
        const RecipeQuery(text: 'ثوم'),
      );
      // الوصفات التي فيها ثوم: hamous بالطحينة (s04)، شكشوكة (s10)؛
      // وشاورما (s11) س11 والفتة (s20) فيها «بالثوم»، عمومًا >1 نتيجة.
      expect(result.recipes, isNotEmpty);
      final titles = result.recipes.map((r) => r.title).toList();
      expect(titles, contains('حمص بالطحينة'));
      expect(titles, contains('شكشوكة بيض بالطماطم'));
    });
  });

  group('تطابق بلا تشكيل', () {
    test('نص مشكل ونص سائب يعيدان النتائج نفسها', () {
      final shaped = const SearchEngine().search(
        fixtures,
        const RecipeQuery(text: 'شُورَبَةُ الْعَدَسِ'),
      );
      final plain = const SearchEngine().search(
        fixtures,
        const RecipeQuery(text: 'شوربة العدس'),
      );
      expect(shaped.recipes, plain.recipes);
      expect(shaped.recipes.first.title, 'شوربة عدس الحمراء');
    });

    test('تطويل (ــ) لا يبطل النتيجة', () {
      final result = const SearchEngine().search(
        fixtures,
        const RecipeQuery(text: 'كــبسة'),
      );
      expect(result.recipes.first.title, 'كبسة دجاج بالبهارات');
    });
  });

  group('تطابق مع تغيير حرف واحد', () {
    test('ث/ت: البحث عن (توم) يجد وصفة (ثوم) والعكس', () {
      final tawmQuery = const SearchEngine()
          .search(fixtures, const RecipeQuery(text: 'توم'));
      final thawmQuery = const SearchEngine()
          .search(fixtures, const RecipeQuery(text: 'ثوم'));
      expect(tawmQuery.recipes, thawmQuery.recipes);
      expect(tawmQuery.recipes.map((r) => r.title), contains('شاورما دجاج بيتية'));
    });

    test('ه/ة: (جبنه) تجد (كنافة بالجبنه) و(بطاطه) تجد (بطاطة)', () {
      final gubnah = const SearchEngine()
          .search(fixtures, const RecipeQuery(text: 'كنافه'));
      expect(gubnah.recipes.first.title, 'كنافة بالجبنه');

      final batataTa = const SearchEngine()
          .search(fixtures, const RecipeQuery(text: 'بطاطة'));
      final batataHa = const SearchEngine()
          .search(fixtures, const RecipeQuery(text: 'بطاطه'));
      expect(batataTa.recipes, batataHa.recipes);
      expect(batataHa.recipes.map((r) => r.title), contains('بطاطة مقليّة بالكزبرة'));
    });

    test('ي/ى: (علي) تجد نصًا فيه (على)', () {
      final ali = const SearchEngine().search(fixtures, const RecipeQuery(text: 'علي'));
      // s03 فيها «على المائدة» فالتطبيع يوحّد ى←ي.
      expect(ali.recipes, isNotEmpty);
    });
  });

  group('لا نتائج عند غياب التطابق', () {
    test('كلمة مالوش أصل في الدفعة تعيد صفرًا', () {
      final result = const SearchEngine()
          .search(fixtures, const RecipeQuery(text: 'بوابة جانبية للغاد'));
      expect(result.isEmpty, isTrue);
      expect(result.recipes, isEmpty);
    });

    test('كلمة أنجليزية غريبة تعيد صفرًا', () {
      final result = const SearchEngine()
          .search(fixtures, const RecipeQuery(text: 'lasagna monterray'));
      expect(result.recipes, isEmpty);
    });

    test('فقرة تعددية إحدى كلماتها مفقودة → لا نتائج (قاعدة ALL)', () {
      final result = const SearchEngine()
          .search(fixtures, const RecipeQuery(text: 'كبسة سوشي ياباني'));
      expect(result.recipes, isEmpty);
    });
  });

  group('الفلاتر (PRD §4.2)', () {
    test('فلتر التصنيف: المشروب منها اثنتان فقط', () {
      final result = const SearchEngine().search(
        fixtures,
        const RecipeQuery(text: '', category: RecipeCategory.drink),
      );
      expect(result.recipes, hasLength(2));
      for (final r in result.recipes) {
        expect(r.category, RecipeCategory.drink);
      }
    });

    test('فلتر الصعوبة: السهل في الدفعة عدد معروض لكل درجاته', () {
      final result = const SearchEngine().search(
        fixtures,
        const RecipeQuery(text: '', difficulty: RecipeDifficulty.hard),
      );
      expect(result.recipes, isNotEmpty);
      for (final r in result.recipes) {
        expect(r.difficulty, RecipeDifficulty.hard);
      }
      // المتعلمة موجودة في العينة: العدد المقدر 4 (رجاءً نظام الدفعة).
      expect(result.recipes.length, 4);
    });

    test('فلتر أقصى الوقت: كل النتائج تنم القيد', () {
      final result = const SearchEngine()
          .search(fixtures, const RecipeQuery(text: '', maxPrepMinutes: 15));
      for (final r in result.recipes) {
        expect(r.prepTimeMinutes, lessThanOrEqualTo(15));
      }
      expect(result.recipes, isNotEmpty);
    });

    test('دمج الاستعلام + منقي معًا: نتيجة محسومة', () {
      final result = const SearchEngine().search(
        fixtures,
        const RecipeQuery(
          text: 'عدس',
          category: RecipeCategory.main,
        ),
      );
      // كشري المصري فيها «عدس بني» وعنوانه بالنحتوي category main …
      expect(result.recipes.map((r) => r.title), contains('كشري مصري بالعدس'));
      for (final r in result.recipes) {
        expect(r.category, RecipeCategory.main);
      }
    });
  });

  group('ترتيب النتائج', () {
    test('الوصفة التي في عنوانها الكلمة تسبق التي في مكوناتها فقط', () {
      final result = const SearchEngine()
          .search(fixtures, const RecipeQuery(text: 'اللحم'));
      // فتة حمص باللحم: «اللحم» في عنوانها (6) + مكون (2) + خطوة (1).
      // كفتة بالصينية: «لحم» في مكونها (2) فقط — ترتيب أقل.
      expect(result.recipes.first.title, 'فتة حمص باللحم');
    });
  });
}
