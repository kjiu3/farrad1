import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/recipe.dart';

/// مُحمّل الوصفات النموذجية من بيانات المستودع (صلب عبر ADR-0008).
///
/// البيانات مصدر حقيقة للـ25 اختبارًا القياسيين: 20 وصفة أصلاً أوجبها
/// معيار المرحلة 2، وتُعيد نفسها في كل بيئة (بلا دروس ولا إنترنت).
class SampleRecipeLoader {
  const SampleRecipeLoader._();

  /// مسار البيانات في ليسا التطبيق.
  static const assetPath = 'assets/data/sample_recipes.json';

  static Future<List<Recipe>> load() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final list = decoded['recipes'] as List<dynamic>;
    final recipes = list
        .whereType<Map<String, dynamic>>()
        .map(Recipe.fromJson)
        .whereType<Recipe>()
        .toList(growable: false);
    return List.unmodifiable(recipes);
  }
}
