import 'package:speech_to_text/speech_to_text.dart';

/// محرك بحث صوتي مبعثر عن تفاصيل الحزمة (فق AGENTS §2.1: الحقن) —
/// الواجهة تختبر فروعها على وهمي كامل، والتنفيذ الحي (إذن
/// المايك على كل منصة) يظل «لم يُختبر بعد» تركبًا لـ AGENTS §4.1.
abstract class VoiceSearchEngine {
  /// false = المنصة لا تدعم أو إذن مرفوض — الواجهة تعرض رسالة
  /// الترجمة بدل انهيار أو سفك صامت.
  Future<bool> init(String language);

  Future<void> listen({required void Function(String) onPartial});

  Future<void> stop();
}

/// التنفيذ الإنتاجي فوق حزمة speech_to_text — إدخال عربي أولًا
/// (فق ADR-0002) بمقياس لغة لكل لغة واجهة.
class SpeechVoiceSearchEngine implements VoiceSearchEngine {
  final SpeechToText _speech = SpeechToText();
  String _locale = 'ar-SA';

  static String speechLocale(String uiLanguage) {
    // 'ar' الأصل العتيقة؛ خريطة صريحة لا تركيب آلي.
    switch (uiLanguage) {
      case 'ar':
        return 'ar-SA';
      case 'en':
        return 'en-US';
      default:
        return 'ar-SA';
    }
  }

  @override
  Future<bool> init(String language) {
    _locale = speechLocale(language);
    return _speech.initialize(
      onStatus: (status) {},
      onError: (error) {},
      finalTimeout: const Duration(seconds: 3),
    );
  }

  @override
  Future<void> listen({required void Function(String) onPartial}) {
    return _speech.listen(
      onResult: (result) => onPartial(result.recognizedWords),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.search,
        localeId: _locale,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();
}
