import 'dart:convert';
import 'package:dio/dio.dart';
import 'user_agent_service.dart';
import 'settings_service.dart';

class TranslationService {
  static final Dio _dio = UserAgentService.createDio(
    options: BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  /// Main translation method with engine selection & automatic fallback
  static Future<String> translate(String text, {String? engine, String? toLanguage}) async {
    if (text.trim().isEmpty) return '';
    
    final targetLang = toLanguage ?? AppSettings.instance.translationLanguage;
    final preferredEngine = engine ?? AppSettings.instance.translationEngine;

    if (preferredEngine == 'google') {
      try {
        return await _translateWithGoogle(text, targetLang);
      } catch (e) {
        // Fallback to Microsoft Edge
        try {
          return await _translateWithMicrosoft(text, targetLang);
        } catch (microsoftError) {
          throw Exception('Translation failed on both engines: $microsoftError');
        }
      }
    } else {
      // 'microsoft' is the default
      try {
        return await _translateWithMicrosoft(text, targetLang);
      } catch (e) {
        // Fallback to Google GTX
        try {
          return await _translateWithGoogle(text, targetLang);
        } catch (googleError) {
          throw Exception('Translation failed on both engines: $googleError');
        }
      }
    }
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
