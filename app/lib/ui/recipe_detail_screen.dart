import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../community/comment_service.dart';
import '../community/rating_service.dart';
import '../data/recipe_repository.dart';
import '../l10n.dart';
import '../models/recipe.dart';
import '../models/units.dart';
import '../ui/recipe_form_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.strings,
    required this.repository,
    required this.recipeId,
    this.commentService = const SupabaseCommentService(),
    this.ratingService = const SupabaseRatingService(),
    this.authService = const SupabaseAuthService(),
  });

  final AppStrings strings;
  final RecipeRepository repository;
  final String recipeId;
  /// الحقن للاختبار (AGENTS §2.1). الافتراضي لا يلمس الشبكة ما دامت
  /// الخلفية غير مهيأة — SupabaseCommentService يعيد قائمة فاضية
  /// ويمنع النشر بلا مفاتيح (فق ADR-0009 §2).
  final CommentService commentService;
  final RatingService ratingService;
  final AuthService authService;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Recipe? _recipe;
  bool _loading = true;

  int? _myRating;
  RatingSummary? _ratingSummary;
  bool _ratingBusy = false;
  String? _ratingErrorKey;

  List<RecipeComment> _comments = const <RecipeComment>[];
  bool _commentsLoading = true;
  final TextEditingController _commentController = TextEditingController();
  bool _commentBusy = false;
  String? _commentErrorKey;

  String _s(String key) => widget.strings.get(key);

  @override
  void initState() {
    super.initState();
    _load();
    _loadComments();
    _loadRating();
  }

  Future<void> _loadRating() async {
    final scores = await widget.ratingService.listScores(widget.recipeId);
    if (!mounted) return;
    final my = await widget.ratingService.getMyRating(widget.recipeId);
    if (!mounted) return;
    setState(() {
      _ratingSummary = RatingSummary.fromScores(scores);
      _myRating = my;
    });
  }

  Future<void> _rate(int score) async {
    if (_ratingBusy) return;
    setState(() {
      _ratingErrorKey = null;
    });
    if (widget.authService.userId == null) {
      setState(() => _ratingErrorKey = 'ratingRequireAuth');
      return;
    }
    setState(() => _ratingBusy = true);
    final outcome = await widget.ratingService.rate(widget.recipeId, score);
    if (!mounted) return;
    if (outcome.ok) {
      setState(() {
        _ratingBusy = false;
        _myRating = score;
      });
      // تحديث الملخص مع الدرجة الجديدة دون إعادة قراءة الشبكة —
      // نفس منطق fromScores المختبر، إضافة درجة واحدة فلا اتساع.
      await _loadRating();
      return;
    }
    setState(() {
      _ratingBusy = false;
      _ratingErrorKey = outcome.errorKey ?? 'ratingFailed';
    });
  }

  Future<void> _loadComments() async {
    final comments = await widget.commentService.list(widget.recipeId);
    if (!mounted) return;
    setState(() {
      _comments = comments;
      _commentsLoading = false;
    });
  }

  Future<void> _submitComment() async {
    if (_commentBusy) return;
    final body = _commentController.text.trim();
    setState(() => _commentErrorKey = null);
    if (body.isEmpty) {
      setState(() => _commentErrorKey = 'commentEmptyInput');
      return;
    }
    if (widget.authService.userId == null) {
      setState(() => _commentErrorKey = 'commentRequireAuth');
      return;
    }
    setState(() => _commentBusy = true);
    final outcome = await widget.commentService.add(widget.recipeId, body);
    if (!mounted) return;
    if (outcome.ok) {
      setState(() {
        _commentBusy = false;
        _commentController.clear();
      });
      await _loadComments();
      return;
    }
    setState(() {
      _commentBusy = false;
      _commentErrorKey = outcome.errorKey ?? 'commentFailed';
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await widget.repository.get(widget.recipeId);
    if (!mounted) return;
    setState(() {
      _recipe = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_s('appTitle'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final r = _recipe;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_s('appTitle'))),
        body: Center(child: Text(_s('recipeNotFound'))),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(r.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RecipeFormScreen(
                    strings: widget.strings,
                    repository: widget.repository,
                    initial: r,
                  ),
                ),
              );
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              // الحذف لا يتم إلا بعد تأكيد — نقرة واحدة لا تُلغي بيانات.
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(_s('deleteConfirmTitle')),
                  content: Text(_s('deleteConfirmBody')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(_s('deleteConfirmNo')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(_s('deleteConfirmYes')),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              await widget.repository.delete(r.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            r.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(_s('category_${r.category.slug}'))),
              Chip(label: Text(_s('difficulty_${r.difficulty.slug}'))),
              Chip(
                label: Text(
                  '${r.prepTimeMinutes} ${_s('minutesUnit')}',
                ),
              ),
              Chip(
                label: Text(
                  '${r.baseServings} ${_s('servingsUnit')}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _s('recipeIngredients'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...r.ingredients.map(
            (i) => ListTile(
              dense: true,
              title: Text(i.name),
              trailing: Text('${i.amount} ${_unitLabel(i.unit)}'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _s('recipeSteps'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...r.steps.asMap().entries.map(
                (e) => ListTile(
                  leading: CircleAvatar(child: Text('${e.key + 1}')),
                  title: Text(e.value),
                ),
              ),
          const SizedBox(height: 16),
          Text(
            _s('ratingTitle'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Row(
            children: [
              for (var s = 1; s <= 5; s++)
                IconButton(
                  key: Key('rating_star_$s'),
                  onPressed: _ratingBusy ? null : () => _rate(s),
                  icon: Icon(
                    (_myRating != null && s <= _myRating!)
                        ? Icons.star
                        : Icons.star_border,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                key: const Key('rating_summary'),
                _summaryText(context),
              ),
            ],
          ),
          if (_ratingErrorKey != null)
            Padding(
              key: const Key('rating_error'),
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _s(_ratingErrorKey!),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            _s('commentsTitle'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_commentsLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                key: const Key('comments_empty'),
                _s('commentEmpty'),
              ),
            )
          else
            ..._comments.map(
              (c) => ListTile(
                key: Key('comment_${c.id}'),
                dense: true,
                title: Text(c.body),
              ),
            ),
          TextField(
            key: const Key('comment_input'),
            controller: _commentController,
            maxLength: 1000, // حد المخطط نفسه (recipe_comments.body)
            decoration: InputDecoration(
              hintText: _s('commentHint'),
            ),
          ),
          if (_commentErrorKey != null)
            Padding(
              key: const Key('comment_error'),
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _s(_commentErrorKey!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('comment_send'),
            onPressed: _commentBusy ? null : _submitComment,
            icon: const Icon(Icons.send),
            label: Text(_s('commentSend')),
          ),
        ],
      ),
    );
  }

  String _unitLabel(RecipeUnit u) => _s('unit_${u.slug}');

  /// صيغة الملخص: متوسط من رقم واحد + عدّاد. بلا تقييمات: نص
  /// «بلا تقييم بعد» من الترجمة لا رقم كاذب.
  String _summaryText(BuildContext context) {
    final s = _ratingSummary;
    if (s == null || s.count == 0) return _s('ratingNone');
    return '${s.average!.toStringAsFixed(1)} ★ (${s.count})';
  }
}
