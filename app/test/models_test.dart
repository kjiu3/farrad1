import 'package:flutter_test/flutter_test.dart';

import 'package:farrad/models/recipe.dart';
import 'package:farrad/models/units.dart';

/// اختبارات نموذج الوصفة ومكوناته ومدققه — المرحلة 2.
void main() {
  group('وحدات القياس (فق ADR-0005 المستوى الابتدائي)', () {
    test('المجموعة الثمانية موجودة بمعرفات ثابتة', () {
      const expected = {
        'gram', 'kilogram', 'milliliter', 'liter',
        'cup', 'tablespoon', 'teaspoon', 'piece',
      };
      expect(RecipeUnit.values.map((u) => u.slug).toSet(), expected);
    });

    test('fromSlug يعرف المعلوم ويعيد null للمجهول', () {
      expect(RecipeUnit.fromSlug('cup'), RecipeUnit.cup);
      expect(RecipeUnit.fromSlug('كوب'), isNull); // المعرفات إنجليزية فقط.
      expect(RecipeUnit.fromSlug('nonexistent'), isNull);
      expect(RecipeUnit.fromSlug(null), isNull);
    });
  });

  group('المكوّن والوصفة', () {
    test('مكوّن صحيح يُقرأ وينُقل عبر JSON', () {
      const ing = Ingredient(name: 'أرز', amount: 2, unit: RecipeUnit.cup);
      final back = Ingredient.fromJson(ing.toJson());
      expect(back, isNotNull);
      expect(back!.name, 'أرز');
      expect(back.amount, 2);
      expect(back.unit, RecipeUnit.cup);
    });

    test('مكونات فاسدة تُرفض بعودة null: كمية صفر أو سالبة أو وحدة مجهولة أو اسم فارغ', () {
      expect(Ingredient.fromJson({'name': 'ملح', 'amount': 0, 'unit': 'gram'}), isNull);
      expect(Ingredient.fromJson({'name': 'ملح', 'amount': -1.5, 'unit': 'gram'}), isNull);
      expect(Ingredient.fromJson({'name': 'ملح', 'amount': 1, 'unit': 'cupx'}), isNull);
      expect(Ingredient.fromJson({'name': '   ', 'amount': 1, 'unit': 'gram'}), isNull);
    });

    test('وصفة كاملة صحيحة تُقرأ من JSON وتعود مطابقة', () {
      final json = {
        'id': 'r1',
        'title': 'شوربة عدس',
        'category': 'main',
        'difficulty': 'easy',
        'prepTimeMinutes': 30,
        'baseServings': 4,
        'ingredients': [
          {'name': 'عدس', 'amount': 200, 'unit': 'gram'},
        ],
        'steps': ['اغسل العدس', 'اطبخ 15 دقيقة'],
        'createdAt': DateTime(2026).toIso8601String(),
        'updatedAt': DateTime(2026).toIso8601String(),
      };
      final recipe = Recipe.fromJson(json);
      expect(recipe, isNotNull);
      expect(recipe!.title, 'شوربة عدس');
      expect(recipe.category.slug, 'main');
      expect(recipe.ingredients, hasLength(1));
      expect(recipe.steps, hasLength(2));
    });

    test('حقول فاسدة أو ناقصة تُرفض بـ null: لا إجهاض أبدًا', () {
      final base = {
        'id': 'r1',
        'title': 'شوربة عدس',
        'category': 'main',
        'difficulty': 'easy',
        'prepTimeMinutes': 30,
        'baseServings': 4,
        'ingredients': [
          {'name': 'عدس', 'amount': 200, 'unit': 'gram'},
        ],
        'steps': ['اطبخ'],
        'createdAt': DateTime(2026).toIso8601String(),
        'updatedAt': DateTime(2026).toIso8601String(),
      };

      Map<String, dynamic> mutate(Map<String, dynamic> delta) {
        final copy = Map<String, dynamic>.from(base);
        copy.addAll(delta);
        return copy;
      }

      expect(Recipe.fromJson(mutate({'title': '   '})), isNull);
      expect(Recipe.fromJson(mutate({'prepTimeMinutes': 0})), isNull);
      expect(Recipe.fromJson(mutate({'baseServings': -3})), isNull);
      expect(Recipe.fromJson(mutate({'category': 'nonexistent'})), isNull);
      expect(Recipe.fromJson(mutate({'difficulty': 'extreme'})), isNull);
      expect(Recipe.fromJson(mutate({'ingredients': <dynamic>[]})), isNull);
      expect(Recipe.fromJson(mutate({'steps': <dynamic>[]})), isNull);
      expect(Recipe.fromJson(mutate({'createdAt': 'not-a-date'})), isNull);
      // مكوّن فاسد داخل قائمة صحيحة → القائمة تُفرَّغ → الوصفة تُرفض.
      expect(
        Recipe.fromJson(mutate({
          'ingredients': [
            {'name': '', 'amount': 5, 'unit': 'gram'},
          ],
        })),
        isNull,
      );
    });
  });

  group('مدقق المرحلة 2 — كل الأخطاء مجتمعة لا الأولى فقط', () {
    test('نموذج سليم بلا أخطاء', () {
      const patch = RecipePatch(
        title: 'كبسة لحم',
        prepTimeMinutes: 60,
        baseServings: 4,
        ingredients: [
          Ingredient(name: 'أرز', amount: 2, unit: RecipeUnit.cup),
        ],
        steps: ['اسلق اللحم'],
      );
      expect(RecipeValidator.validate(patch), isEmpty);
    });

    test('كل الحقول الفاسدة تظهر معًا في النتيجة', () {
      const patch = RecipePatch(
        title: '   ',
        prepTimeMinutes: -5,
        baseServings: 0,
        ingredients: [
          Ingredient(name: '  ', amount: 0, unit: RecipeUnit.gram),
        ],
        steps: ['  '],
      );
      final errors = RecipeValidator.validate(patch);
      expect(errors, contains(ValidationError.titleEmpty));
      expect(errors, contains(ValidationError.prepTimeInvalid));
      expect(errors, contains(ValidationError.servingsInvalid));
      expect(errors, contains(ValidationError.ingredientNameEmpty));
      expect(errors, contains(ValidationError.amountInvalid));
      expect(errors, contains(ValidationError.stepEmpty));
      expect(errors, hasLength(6));
    });

    test('مدخل متطرف: عنوان 4000 حرف وحقول طويلة تُرفَض ولا تُجهاض', () {
      final patch = RecipePatch(
        title: 'ط' * 4000,
        prepTimeMinutes: 1,
        baseServings: 1,
        ingredients: [
          Ingredient(name: 'م' * 4000, amount: 0.001, unit: RecipeUnit.gram),
        ],
        steps: ['س' * 4000],
      );
      final errors = RecipeValidator.validate(patch);
      // عنوان 4000 حرف: يقفز حدّ الطول لا الفراغ — رسالتان مختلفتان مقصودتان.
      expect(errors, contains(ValidationError.titleTooLong));
      expect(errors, isNot(contains(ValidationError.titleEmpty)));
      // العناصر الحديّة (كمية موجبة صغيرة) مقبولة تقنيًا وتُخزَّن أمنًا.
      expect(errors, isNot(contains(ValidationError.amountInvalid)));
    });

    test('قيم حديّة سليمة تُقبَل: 24 ساعة و1000 شخص', () {
      const patch = RecipePatch(
        title: 'عنوان',
        prepTimeMinutes: 24 * 60,
        baseServings: 1000,
        ingredients: [
          Ingredient(name: 'مكون', amount: 999999, unit: RecipeUnit.kilogram),
        ],
        steps: ['خطوة'],
      );
      expect(RecipeValidator.validate(patch), isEmpty);
    });

    test('تجاوز الحدود الحديّة يُرفَض: 25 ساعة و1001 شخص', () {
      const patch = RecipePatch(
        title: 'عنوان',
        prepTimeMinutes: 24 * 60 + 1,
        baseServings: 1001,
        ingredients: [
          Ingredient(name: 'مكون', amount: 1, unit: RecipeUnit.cup),
        ],
        steps: ['خطوة'],
      );
      final errors = RecipeValidator.validate(patch);
      expect(errors, containsAll([ValidationError.prepTimeInvalid, ValidationError.servingsInvalid]));
    });

    test('حدّ طول العنوان: 500 حرف تُقبَل و501 تُرفَض بـ titleTooLong', () {
      final ok = RecipePatch(
        title: 'ط' * 500,
        prepTimeMinutes: 10,
        baseServings: 2,
        ingredients: [const Ingredient(name: 'مكون', amount: 1, unit: RecipeUnit.gram)],
        steps: ['خطوة'],
      );
      expect(RecipeValidator.validate(ok), isEmpty);

      final over = RecipePatch(
        title: 'ط' * 501,
        prepTimeMinutes: 10,
        baseServings: 2,
        ingredients: [const Ingredient(name: 'مكون', amount: 1, unit: RecipeUnit.gram)],
        steps: ['خطوة'],
      );
      final errors = RecipeValidator.validate(over);
      expect(errors, contains(ValidationError.titleTooLong));
      expect(errors, isNot(contains(ValidationError.titleEmpty)));
    });
  });
}
