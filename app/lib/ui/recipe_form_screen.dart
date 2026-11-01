import 'package:flutter/material.dart';

import '../data/recipe_repository.dart';
import '../models/recipe.dart';
import '../models/units.dart';

class RecipeFormScreen extends StatefulWidget {
  const RecipeFormScreen({
    super.key,
    required this.strings,
    required this.repository,
    this.initial,
  });

  final dynamic strings;
  final RecipeRepository repository;
  final Recipe? initial;

  @override
  State<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends State<RecipeFormScreen> {
  final _titleController = TextEditingController();
  final _prepController = TextEditingController();
  final _servingsController = TextEditingController();

  RecipeCategory _category = RecipeCategory.main;
  RecipeDifficulty _difficulty = RecipeDifficulty.easy;

  final List<_IngredientRow> _ingredients = [];
  final List<TextEditingController> _steps = [];

  List<String> _errors = const [];
  bool _saving = false;

  String _s(String key) => widget.strings.get(key) as String;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _titleController.text = initial.title;
      _prepController.text = initial.prepTimeMinutes.toString();
      _servingsController.text = initial.baseServings.toString();
      _category = initial.category;
      _difficulty = initial.difficulty;
      for (final ing in initial.ingredients) {
        _ingredients.add(_IngredientRow(
          name: ing.name,
          amount: ing.amount.toString(),
          unit: ing.unit,
        ));
      }
      for (final step in initial.steps) {
        final c = TextEditingController(text: step);
        _steps.add(c);
      }
    }
    if (_ingredients.isEmpty) {
      _ingredients.add(_IngredientRow(name: '', amount: '', unit: RecipeUnit.gram));
    }
    if (_steps.isEmpty) {
      _steps.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _prepController.dispose();
    _servingsController.dispose();
    for (final r in _ingredients) {
      r.dispose();
    }
    for (final c in _steps) {
      c.dispose();
    }
    super.dispose();
  }

  RecipePatch _buildPatch() {
    final ingredients = _ingredients
        .map((r) => Ingredient(
              name: r.nameController.text,
              amount: double.tryParse(r.amountController.text.trim()) ?? 0,
              unit: r.unit,
            ))
        .toList();
    final steps = _steps.map((c) => c.text).toList();
    return RecipePatch(
      title: _titleController.text,
      category: _category,
      difficulty: _difficulty,
      prepTimeMinutes: int.tryParse(_prepController.text.trim()),
      baseServings: int.tryParse(_servingsController.text.trim()),
      ingredients: ingredients,
      steps: steps,
    );
  }

  Future<void> _save() async {
    setState(() => _errors = const []);
    final patch = _buildPatch();
    final errors = RecipeValidator.validate(patch);
    if (errors.isNotEmpty) {
      setState(() => _errors = errors.map((e) => _s(e.key)).toList());
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now().toUtc();
    final initial = widget.initial;
    final recipe = Recipe(
      id: initial?.id ?? 'u${now.microsecondsSinceEpoch}',
      title: patch.title!.trim(),
      category: patch.category!,
      difficulty: patch.difficulty!,
      prepTimeMinutes: patch.prepTimeMinutes!,
      baseServings: patch.baseServings!,
      ingredients: patch.ingredients!,
      steps: patch.steps!.map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      createdAt: initial?.createdAt ?? now,
      updatedAt: now,
    );
    await widget.repository.save(recipe);
    if (mounted) Navigator.of(context).pop(true);
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? _s('createRecipe') : _s('editRecipe')),
      ),
      body: Column(
        children: [
          if (_errors.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _errors.map((e) => Text(e)).toList(),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(labelText: _s('recipeTitle')),
            maxLength: 5000,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<RecipeCategory>(
            initialValue: _category,
            decoration: InputDecoration(labelText: _s('recipeCategory')),
            items: RecipeCategory.values
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(_s('category_${c.slug}')),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<RecipeDifficulty>(
            initialValue: _difficulty,
            decoration: InputDecoration(labelText: _s('recipeDifficulty')),
            items: RecipeDifficulty.values
                .map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(_s('difficulty_${d.slug}')),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _difficulty = v ?? _difficulty),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _prepController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: _s('recipePrepTime')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _servingsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: _s('recipeServings')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _s('recipeIngredients'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ..._ingredients.asMap().entries.map((e) {
            final row = e.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: row.nameController,
                      decoration: InputDecoration(labelText: _s('ingredientName')),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: row.amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: _s('ingredientAmount')),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<RecipeUnit>(
                      isExpanded: true,
                       initialValue: row.unit,
                      items: RecipeUnit.values
                          .map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(_s('unit_${u.slug}')),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => row.unit = v ?? row.unit),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      row.dispose();
                      _ingredients.removeAt(e.key);
                      if (_ingredients.isEmpty) {
                        _ingredients.add(_IngredientRow(
                          name: '',
                          amount: '',
                          unit: RecipeUnit.gram,
                        ));
                      }
                    }),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _ingredients.add(
                  _IngredientRow(name: '', amount: '', unit: RecipeUnit.gram),
                )),
            icon: const Icon(Icons.add),
            label: Text(_s('addIngredient')),
          ),
          const SizedBox(height: 16),
          Text(
            _s('recipeSteps'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ..._steps.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: e.value,
                      decoration: InputDecoration(
                        labelText: '${_s('stepLabel')} ${e.key + 1}',
                      ),
                      maxLines: null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      e.value.dispose();
                      _steps.removeAt(e.key);
                      if (_steps.isEmpty) _steps.add(TextEditingController());
                    }),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _steps.add(TextEditingController())),
            icon: const Icon(Icons.add),
            label: Text(_s('addStep')),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? _s('saving') : _s('saveRecipe')),
          ),
        ],
      ),
    ),
  ],
  ),
  );
  }
}

class _IngredientRow {
  _IngredientRow({required String name, required String amount, required this.unit})
      : nameController = TextEditingController(text: name),
        amountController = TextEditingController(text: amount);

  final TextEditingController nameController;
  final TextEditingController amountController;
  RecipeUnit unit;

  String get name => nameController.text;
  String get amount => amountController.text;

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}
