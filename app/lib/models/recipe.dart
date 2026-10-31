import 'units.dart';

/// تصنيفات الوصفة وفق PRD §4.1 (تُوسَّع لاحقًا بتقرير واختبار).
enum RecipeCategory {
  main('main'),
  appetizer('appetizer'),
  dessert('dessert'),
  drink('drink'),
  baked('baked');

  const RecipeCategory(this.slug);

  final String slug;

  static RecipeCategory? fromSlug(String? slug) =>
      RecipeCategory.values.where((c) => c.slug == slug).firstOrNull;
}

/// مستويات الصعوبة الثلاثة وفق PRD.
enum RecipeDifficulty {
  easy('easy'),
  medium('medium'),
  hard('hard');

  const RecipeDifficulty(this.slug);

  final String slug;

  static RecipeDifficulty? fromSlug(String? slug) =>
      RecipeDifficulty.values.where((d) => d.slug == slug).firstOrNull;
}

/// مكوّن واحد: اسم حر + كمية موجبة + وحدة معيارية (فق ADR-0005).
class Ingredient {
  const Ingredient({
    required this.name,
    required this.amount,
    required this.unit,
  });

  final String name;
  final double amount;
  final RecipeUnit unit;

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'unit': unit.slug,
      };

  static Ingredient? fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    final amount = (json['amount'] as num?)?.toDouble();
    final unit = RecipeUnit.fromSlug(json['unit']?.toString());
    if (name.trim().isEmpty || amount == null || unit == null) return null;
    // or حجم غير موجب يُرفَض (فق قواعد التحقق).
    if (amount <= 0) return null;
    return Ingredient(name: name.trim(), amount: amount, unit: unit);
  }
}

/// وصفة كاملة وفق PRD §4.1 — المرحلة 2 بلا صور (خارج نطاقها).
///
/// الحقول قابلة للنمو لاحقًا (تقييم، تعليقات...) دون إعادة هيكلة هنا.
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.category,
    required this.difficulty,
    required this.prepTimeMinutes,
    required this.baseServings,
    required this.ingredients,
    required this.steps,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final RecipeCategory category;
  final RecipeDifficulty difficulty;
  final int prepTimeMinutes;
  final int baseServings;
  final List<Ingredient> ingredients;
  final List<String> steps;
  final DateTime createdAt;
  final DateTime updatedAt;

  Recipe copyForEdit({
    String? title,
    RecipeCategory? category,
    RecipeDifficulty? difficulty,
    int? prepTimeMinutes,
    int? baseServings,
    List<Ingredient>? ingredients,
    List<String>? steps,
    required DateTime newUpdatedAt,
  }) {
    return Recipe(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      baseServings: baseServings ?? this.baseServings,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      createdAt: createdAt,
      updatedAt: newUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.slug,
        'difficulty': difficulty.slug,
        'prepTimeMinutes': prepTimeMinutes,
        'baseServings': baseServings,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'steps': steps,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static Recipe? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final title = json['title']?.toString() ?? '';
    final category = RecipeCategory.fromSlug(json['category']?.toString());
    final difficulty = RecipeDifficulty.fromSlug(json['difficulty']?.toString());
    final prep = (json['prepTimeMinutes'] as num?)?.toInt();
    final servings = (json['baseServings'] as num?)?.toInt();
    final ingredients = (json['ingredients'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Ingredient.fromJson)
        .whereType<Ingredient>()
        .toList(growable: false);
    final steps = (json['steps'] as List<dynamic>? ?? const [])
        .map((s) => s?.toString() ?? '')
        .where((s) => s.trim().isNotEmpty)
        .toList(growable: false);
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    if (id.isEmpty ||
        title.trim().isEmpty ||
        category == null ||
        difficulty == null ||
        prep == null ||
        prep <= 0 ||
        servings == null ||
        servings <= 0 ||
        ingredients.isEmpty ||
        steps.isEmpty ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }
    return Recipe(
      id: id,
      title: title.trim(),
      category: category,
      difficulty: difficulty,
      prepTimeMinutes: prep,
      baseServings: servings,
      ingredients: ingredients,
      steps: List.unmodifiable(steps),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// أخطاء التحقق (رموز ثابتة تُقابلها نصوص الترجمة في ar.json/en.json).
enum ValidationError {
  titleEmpty('validation_titleEmpty'),
  amountInvalid('validation_amountInvalid'),
  unitUnknown('validation_unitUnknown'),
  ingredientNameEmpty('validation_ingredientNameEmpty'),
  servingsInvalid('validation_servingsInvalid'),
  prepTimeInvalid('validation_prepTimeInvalid'),
  stepsEmpty('validation_stepsEmpty'),
  ingredientsEmpty('validation_ingredientsEmpty'),
  stepEmpty('validation_stepEmpty');

  const ValidationError(this.key);

  /// مفتاح النص في ملفات الترجمة.
  final String key;
}

class RecipePatch {
  const RecipePatch({
    this.title,
    this.category,
    this.difficulty,
    this.prepTimeMinutes,
    this.baseServings,
    this.ingredients,
    this.steps,
  });

  final String? title;
  final RecipeCategory? category;
  final RecipeDifficulty? difficulty;
  final int? prepTimeMinutes;
  final int? baseServings;
  final List<Ingredient>? ingredients;
  final List<String>? steps;
}

/// المدقق: يجمّع كل الأخطاء، لا يقف عند الأولى — لرؤية المستخدم كامل الملاحظة.
class RecipeValidator {
  static List<ValidationError> validate(RecipePatch patch) {
    final errors = <ValidationError>[];

    final title = patch.title?.trim();
    if (title == null || title.isEmpty) errors.add(ValidationError.titleEmpty);
    // حد أقصى حماية من مدخلات متطرفة (فق ROADMAP المرحلة 2 معيار 3) —
    // نص طويل لا يكسر الواجهة لكنه يُرفَض كطبق عنوان؛ الحد مبالغ فيه عمدًا.
    if (title != null && title.length > 500) {
      errors.add(ValidationError.titleEmpty);
    }

    if (patch.prepTimeMinutes != null && patch.prepTimeMinutes! <= 0) {
      errors.add(ValidationError.prepTimeInvalid);
    }
    if (patch.prepTimeMinutes != null && patch.prepTimeMinutes! > 24 * 60) {
      errors.add(ValidationError.prepTimeInvalid);
    }

    if (patch.baseServings != null && patch.baseServings! <= 0) {
      errors.add(ValidationError.servingsInvalid);
    }
    if (patch.baseServings != null && patch.baseServings! > 1000) {
      errors.add(ValidationError.servingsInvalid);
    }

    final ingredients = patch.ingredients;
    if (ingredients == null || ingredients.isEmpty) {
      errors.add(ValidationError.ingredientsEmpty);
    } else {
      for (final ing in ingredients) {
        if (ing.name.trim().isEmpty) {
          errors.add(ValidationError.ingredientNameEmpty);
        }
        if (ing.amount <= 0) errors.add(ValidationError.amountInvalid);
      }
    }

    final steps = patch.steps;
    if (steps == null || steps.isEmpty) {
      errors.add(ValidationError.stepsEmpty);
    } else {
      for (final step in steps) {
        if (step.trim().isEmpty) errors.add(ValidationError.stepEmpty);
      }
    }

    return errors;
  }
}
