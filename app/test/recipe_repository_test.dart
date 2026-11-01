import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farrad/data/recipe_repository.dart';
import 'package:farrad/models/recipe.dart';
import 'package:farrad/models/units.dart';

/// اختبارات وحدة لمستودع `shared_preferences` — كانت بلا اختبار مطلقًا
/// (مراجعة المرحلة 2: ملاحظة 1 🔴 على PR #12 / AGENTS §2.1).
///
/// المنهجية: `SharedPreferences.setMockInitialValues` لكل حالة، وإعادة
/// بناء المستودع من الصفر لمحاكاة إعادة تشغيل التطبيق.
Recipe _recipe(String id, {String title = 'وصفة'}) {
  final base = DateTime.utc(2026, 1, 1, 12);
  return Recipe(
    id: id,
    title: title,
    category: RecipeCategory.main,
    difficulty: RecipeDifficulty.easy,
    prepTimeMinutes: 20,
    baseServings: 2,
    ingredients: [const Ingredient(name: 'أرز', amount: 2, unit: RecipeUnit.cup)],
    steps: const ['اطبخ'],
    createdAt: base,
    updatedAt: base,
  );
}

/// بذرة من وصفة واحدة — ممثلة لظاهر `sample_recipes.json`.
final List<Recipe> seed = [_recipe('s1', title: 'بذرة')];

SharedPreferencesRecipeRepository _fresh() =>
    SharedPreferencesRecipeRepository(seed: seed);

const _storageKey = 'farrad.saved_recipes';
const _deletedKey = 'farrad.deleted_recipe_ids';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('البذور تُقرأ أولًا بلا تخزين', () async {
    expect((await _fresh().list()).single.id, 's1');
  });

  test('الحذف يزيل البذرة ويبقى محذوفة بعد إعادة تشغيل', () async {
    final repo = _fresh();
    await repo.delete('s1');

    expect(await repo.list(), isEmpty);
    expect(await _fresh().list(), isEmpty); // بعد «إعادة تشغيل».

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_deletedKey), contains('s1'));
  });

  test('تعديل بذرة يُحفظ كتويدٍ ويعود نسخة من بعد إعادة التشغيل', () async {
    final repo = _fresh();
    final edited = Recipe(
      id: 's1',
      title: 'بذرة معدلة',
      category: RecipeCategory.main,
      difficulty: RecipeDifficulty.easy,
      prepTimeMinutes: 20,
      baseServings: 2,
      ingredients: [
        const Ingredient(name: 'أرز', amount: 2, unit: RecipeUnit.cup),
      ],
      steps: const ['اطبخ'],
      createdAt: DateTime.utc(2026, 1, 1, 12),
      updatedAt: DateTime.utc(2026, 2, 2),
    );
    await repo.save(edited);

    expect((await repo.list()).single.title, 'بذرة معدلة');
    final after = await _fresh().list();
    expect(after.single.title, 'بذرة معدلة');
    expect(after.single.updatedAt, DateTime.utc(2026, 2, 2));
  });

  test('إضافة جديدة تبقى بعد إعادة تشغيل وتُحفظ في التخزين', () async {
    final repo = _fresh();
    await repo.save(_recipe('u1', title: 'مضافة'));

    // البذرة + المضافة: الأنسان.
    expect((await repo.list()).map((r) => r.id), containsAll(['s1', 'u1']));
    final after = await _fresh().list();
    expect(after.map((r) => r.id), containsAll(['s1', 'u1']));
    expect(after.where((r) => r.id == 'u1'), hasLength(1));

    final prefs = await SharedPreferences.getInstance();
    final overrides =
        (json.decode(prefs.getString(_storageKey) ?? '[]') as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
    expect(overrides.map((o) => o['id']), contains('u1'));
  });

  test('حذف مضافة يزيلها ويبقى البذرة', () async {
    final repo = _fresh();
    await repo.save(_recipe('u1'));
    await repo.delete('u1');

    // البذرة باقية؛ المضافة ذهبت.
    expect((await repo.list()).map((r) => r.id), contains('s1'));
    expect((await repo.list()).map((r) => r.id), isNot(contains('u1')));
    expect(await _fresh().list().then((l) => l.map((r) => r.id).toList()),
        isNot(contains('u1')));
    final prefs = await SharedPreferences.getInstance();
    // لائحة المحذوفات مخصصة للبذور — المضافة غير بذرة؛ يكفي خضعها من
    // قائمة التخزين مباشرة.
    expect(prefs.getStringList(_deletedKey) ?? const <String>[], isEmpty);
  });

  test('JSON فاسد في التخزين: يعود إلى البذور بلا إجهاض', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      _storageKey: 'not-json{{!',
    });
    final list = await _fresh().list();
    expect(list.map((r) => r.id), contains('s1')); // البذرة تظل موجودة.
  });

  test('JSON سليم بنود فاسدة: الفاسد يُرفض والسليم يبقى', () async {
    final good = _recipe('u1').toJson();
    // وصفة فاسدة: عدد أقل خطئًا — تُرفض من Recipe.fromJson ولا تُجهاض.
    final bad = <String, dynamic>{
      'id': 'u2',
      'title': 'فاسدة',
      'category': 'main',
      'difficulty': 'easy',
      'prepTimeMinutes': -1,
      'baseServings': 0,
      'ingredients': [
        {'name': ' ', 'amount': 0, 'unit': 'gram'},
      ],
      'steps': ['خ'],
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      _storageKey: json.encode([bad, good]),
    });
    final list = await _fresh().list();
    expect(list.map((r) => r.id), contains('u1'));
    expect(list.map((r) => r.id), isNot(contains('u2')));
  });
}
