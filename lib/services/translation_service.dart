import 'dart:convert';
import 'package:dio/dio.dart';
import 'user_agent_service.dart';
import 'settings_service.dart';

class TranslationResult {
  final String text;
  final String engine; // 'google', 'microsoft' or 'reverso'

  TranslationResult({required this.text, required this.engine});
}

class TranslationService {
  static final Dio _dio = UserAgentService.createDio(
    options: BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  /// Main translation method with engine selection & automatic fallback
  static Future<TranslationResult> translate(String text, {String? engine, String? toLanguage}) async {
    if (text.trim().isEmpty) {
      return TranslationResult(
        text: '',
        engine: engine ?? AppSettings.instance.translationEngine,
      );
    }
    
    final targetLang = toLanguage ?? AppSettings.instance.translationLanguage;
    final preferredEngine = engine ?? AppSettings.instance.translationEngine;

    final orderedEngines = <String>[];
    if (preferredEngine == 'google') {
      orderedEngines.addAll(['google', 'microsoft', 'reverso']);
    } else if (preferredEngine == 'reverso') {
      orderedEngines.addAll(['reverso', 'google', 'microsoft']);
    } else {
      orderedEngines.addAll(['microsoft', 'reverso', 'google']);
    }

    final errors = <String>[];
    for (final eng in orderedEngines) {
      try {
        if (eng == 'google') {
          final res = await _translateWithGoogle(text, targetLang);
          return TranslationResult(text: res, engine: 'google');
        } else if (eng == 'reverso') {
          final res = await _translateWithReverso(text, targetLang);
          return TranslationResult(text: res, engine: 'reverso');
        } else {
          final res = await _translateWithMicrosoft(text, targetLang);
          return TranslationResult(text: res, engine: 'microsoft');
        }
      } catch (e) {
        errors.add('$eng: $e');
      }
    }
    throw Exception('Translation failed on all engines: ${errors.join("; ")}');
  }

  /// Reverso Translation Engine
  static Future<String> _translateWithReverso(String text, String toLanguage) async {
    final fromLang = _detectSourceLanguage(text, toLanguage);
    final destinationLang = _mapLanguageToReverso(toLanguage);

    const url = 'https://api.reverso.net/translate/v1/translation';
    final response = await _dio.post(
      url,
      data: jsonEncode({
        'input': text,
        'from': fromLang,
        'to': destinationLang,
        'format': 'text',
        'options': {
          'origin': 'reversomobile',
          'sentenceSplitter': false,
          'contextResults': false,
          'languageDetection': true
        }
      }),
      options: Options(
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json, text/plain, */*',
          'User-Agent': 'ReversoContext/4.6.0 (Android; 30)',
          'X-Reverso-Origin': 'reversomobile',
          'Origin': 'https://translation.reverso.net',
          'Referer': 'https://translation.reverso.net/',
        },
      ),
    );

    if (response.statusCode == 200 && response.data != null) {
      var data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      if (data is Map && data.containsKey('translation')) {
        final List<dynamic> translations = data['translation'];
        if (translations.isNotEmpty) {
          return translations[0].toString();
        }
      }
    }
    throw Exception('Invalid response from Reverso Translator');
  }

  static String _mapLanguageToReverso(String lang) {
    switch (lang.toLowerCase()) {
      case 'zh-cn':
      case 'zh-tw':
      case 'zh':
        return 'chi';
      case 'en':
        return 'eng';
      case 'ja':
        return 'jpn';
      case 'ko':
        return 'kor';
      default:
        if (lang.length == 3) return lang.toLowerCase();
        throw Exception('Language $lang is not supported by Reverso');
    }
  }

  static String _detectSourceLanguage(String text, String targetLang) {
    // If the text contains Hiragana or Katakana, it's Japanese
    final hasJapaneseKana = RegExp(r'[\u3040-\u309f\u30a0-\u30ff]').hasMatch(text);
    if (hasJapaneseKana) {
      return 'jpn';
    }
    
    // If target language is English (which means we might be translating CJK text)
    final hasCJK = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    if (hasCJK) {
      return targetLang.toLowerCase().startsWith('en') ? 'chi' : 'jpn';
    }
    
    // Default to English
    return 'eng';
  }

  /// Microsoft Edge Translation Engine
  static Future<String> _translateWithMicrosoft(String text, String toLanguage) async {
    // Step A: Fetch Edge Auth JWT Token
    final tokenResponse = await _dio.get('https://edge.microsoft.com/translate/auth');
    if (tokenResponse.statusCode != 200 || tokenResponse.data == null) {
      throw Exception('Failed to fetch Microsoft Edge JWT token');
    }
    final jwtToken = tokenResponse.data.toString().trim();

    // Step B: Send translation request
    final url = 'https://api-edge.cognitive.microsofttranslator.com/translate?from=&to=$toLanguage&api-version=3.0&includeSentenceLength=true';
    final response = await _dio.post(
      url,
      data: jsonEncode([{'Text': text}]),
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      ),
    );

    if (response.statusCode == 200 && response.data is List) {
      final List<dynamic> data = response.data;
      if (data.isNotEmpty) {
        final translations = data[0]['translations'];
        if (translations != null && translations is List && translations.isNotEmpty) {
          return translations[0]['text'].toString();
        }
      }
    }
    throw Exception('Invalid response from Microsoft Edge Translator');
  }

  /// Google Translation Engine (GTX client fallback)
  static Future<String> _translateWithGoogle(String text, String toLanguage) async {
    final encodedText = Uri.encodeComponent(text);
    final url = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$toLanguage&dt=t&q=$encodedText';
    
    final response = await _dio.get(
      url,
      options: Options(
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ),
    );

    if (response.statusCode == 200 && response.data is List) {
      final List<dynamic> data = response.data;
      if (data.isNotEmpty && data[0] is List) {
        final List<dynamic> parts = data[0];
        final StringBuffer buffer = StringBuffer();
        for (var part in parts) {
          if (part is List && part.isNotEmpty) {
            buffer.write(part[0].toString());
          }
        }
        return buffer.toString();
      }
    }
    throw Exception('Invalid response from Google GTX Translator');
  }
}
