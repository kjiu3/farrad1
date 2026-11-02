import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../data/recipe_repository.dart';
import '../l10n.dart';
import '../models/recipe.dart';
import '../search/search_engine.dart';
import '../search/voice_search.dart';
import '../supabase/app_backend.dart';
import '../ui/auth_screen.dart';
import '../ui/recipe_detail_screen.dart';
import '../ui/recipe_form_screen.dart';

/// شاشة البحث + فلاتر + قائمة النتائج (PRD §4.2).
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.strings,
    required this.repository,
    this.engine = const SearchEngine(),
    this.onToggleLanguage,
    this.otherLanguageLabel,
    this.authService = const SupabaseAuthService(),
    this.voiceEngine,
  });

  /// الحقن للاختبار — null = المحرك الواقعي (speech_to_text).
  final VoiceSearchEngine? voiceEngine;

  final AppStrings strings; // من l10n.dart — نوع ثابت لا dynamic.
  final RecipeRepository repository;
  final SearchEngine engine;
  final VoidCallback? onToggleLanguage;
  final String? otherLanguageLabel;
  final AuthService authService; // حقن للاختبار — الإنتاج عبر Supabase.

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _maxPrepController = TextEditingController();

  /// المحرك الفعلي: المحقون أو الواقعي (بما أن الصنف غير const).
  VoiceSearchEngine get _voiceEngine =>
      widget.voiceEngine ?? SpeechVoiceSearchEngine();

  List<Recipe> _recipes = const [];
  List<Recipe> _results = const [];
  RecipeCategory? _category;
  RecipeDifficulty? _difficulty;
  bool _loading = true;

  bool _voiceInitialized = false;
  bool _voiceListening = false;
  String? _voiceErrorKey;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await widget.repository.list();
    if (!mounted) return;
    setState(() {
      _recipes = list;
      _loading = false;
    });
    _runSearch();
  }

  void _runSearch() {
    final maxPrep = int.tryParse(_maxPrepController.text.trim());
    final query = RecipeQuery(
      text: _controller.text,
      category: _category,
      difficulty: _difficulty,
      maxPrepMinutes: maxPrep,
    );
    final result = widget.engine.search(_recipes, query);
    setState(() => _results = result.recipes);
  }

  String _s(String key) => widget.strings.get(key);

  /// البحث الصوتي العربي (P3-7): فق ADR-0002 العربية أولًا —
  /// منطقة الصوت ar-SA في هذه المرحلة. لا شبكة عادةً: الإذن
  /// والتعرف بيد المنصة (speech_to_text)، والفشل رسالة لا انهيار.
  Future<void> _toggleVoice() async {
    if (_voiceListening) {
      setState(() => _voiceListening = false);
      await _voiceEngine.stop();
      return;
    }
    setState(() => _voiceErrorKey = null);
    if (!_voiceInitialized) {
      final ok = await _voiceEngine.init('ar');
      if (!mounted) return;
      if (!ok) {
        setState(() => _voiceErrorKey = 'voiceUnavailable');
        return;
      }
      _voiceInitialized = true;
    }
    try {
      await _voiceEngine.listen(
        onPartial: (text) {
          if (!mounted) return;
          setState(() {
            _controller.text = text;
            _voiceErrorKey = null;
          });
          _runSearch();
        },
      );
      if (!mounted) return;
      setState(() => _voiceListening = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _voiceErrorKey = 'voiceFailed');
    }
  }

  @override
  void dispose() {
    // أطع حذف الحالة — على المستمع أن يموت معها، فلا ميكروفون
    // مفتوح بعد مغادرة الشاشة في منتصف الاستماع (AGENTS §2.2).
    if (_voiceListening) {
      _voiceEngine.stop();
    }
    _controller.dispose();
    _maxPrepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_s('appTitle')),
        actions: [
          if (widget.onToggleLanguage != null)
            TextButton(
              onPressed: widget.onToggleLanguage,
              child: Text(widget.otherLanguageLabel ?? ''),
            ),
          IconButton(
            key: const Key('auth_open'),
            icon: const Icon(Icons.person_outline),
            tooltip: _s('authSignIn'),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AuthScreen(
                    strings: widget.strings,
                    service: widget.authService,
                  ),
                ),
              );
              // الجلسة قد تغيّرت (دخول/خروج/انتهاء) — أعد بناء البانر.
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // بانر الوضع المحلي (فق ADR-0009 §2): يظهر فقط حين لا
          // تُهيَّأ الخلفية — يخبر المستخدم بلغة واضحة لماذا يغيب
          // الحساب والتعليق بدل ظهورهما مكسورين أو صامتين.
          if (!AppBackend.instance.configured)
            Material(
              key: const Key('local_mode_banner'),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    _s('localModeBanner'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const Key('search_field'),
              controller: _controller,
              decoration: InputDecoration(
                hintText: _s('searchHint'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  key: const Key('voice_mic'),
                  tooltip: _s('voiceMic'),
                  color: _voiceListening
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  onPressed: _toggleVoice,
                  icon: Icon(
                    _voiceListening ? Icons.stop : Icons.mic_none,
                  ),
                ),
              ),
              onChanged: (_) => _runSearch(),
            ),
          ),
          if (_voiceErrorKey != null)
            Padding(
              key: const Key('voice_error'),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _s(_voiceErrorKey!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<RecipeCategory?>(
                    initialValue: _category,
                    decoration: InputDecoration(labelText: _s('filterCategory')),
                    items: [
                      DropdownMenuItem<RecipeCategory?>(
                        value: null,
                        child: Text(_s('filterAll')),
                      ),
                      ...RecipeCategory.values.map(
                        (c) => DropdownMenuItem<RecipeCategory?>(
                          value: c,
                          child: Text(_s('category_${c.slug}')),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _category = v);
                      _runSearch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<RecipeDifficulty?>(
                    initialValue: _difficulty,
                    decoration: InputDecoration(labelText: _s('filterDifficulty')),
                    items: [
                      DropdownMenuItem<RecipeDifficulty?>(
                        value: null,
                        child: Text(_s('filterAll')),
                      ),
                      ...RecipeDifficulty.values.map(
                        (d) => DropdownMenuItem<RecipeDifficulty?>(
                          value: d,
                          child: Text(_s('difficulty_${d.slug}')),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _difficulty = v);
                      _runSearch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _maxPrepController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: _s('filterMaxPrep')),
                    onChanged: (_) => _runSearch(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(child: Text(_s('noResults')))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          return Card(
                            child: ListTile(
                              title: Text(r.title),
                              subtitle: Text(
                                '${_s('category_${r.category.slug}')} • '
                                '${r.prepTimeMinutes} ${_s('minutesUnit')}',
                              ),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => RecipeDetailScreen(
                                      strings: widget.strings,
                                      repository: widget.repository,
                                      recipeId: r.id,
                                      authService: widget.authService,
                                    ),
                                  ),
                                );
                                _reload();
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RecipeFormScreen(
                strings: widget.strings,
                repository: widget.repository,
              ),
            ),
          );
          _reload();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
