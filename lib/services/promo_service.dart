import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/promo_item.dart';
import 'user_agent_service.dart';

class PromoService {
  static final PromoService instance = PromoService._internal();
  PromoService._internal();

  List<PromoItem> _promos = [];
  bool _isLoaded = false;

  List<PromoItem> get promos => _promos;

  Future<void> fetchPromos() async {
    if (_isLoaded && _promos.isNotEmpty) return;
    try {
      final dio = UserAgentService.createDio();
      final response = await dio.get('https://www.moely.link/promos.json');
      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> listData = [];
        if (data is List) {
          listData = data;
        } else if (data is String) {
          // In case it's returned as raw string
          listData = jsonDecode(data);
        }
        _promos = listData.map((e) => PromoItem.fromJson(e)).toList();
        _isLoaded = true;
      }
    } catch (e) {
      debugPrint('Failed to fetch promos: $e');
    }
  }

  PromoItem? getRandomPromo() {
    if (_promos.isEmpty) return null;
    final rand = Random();
    return _promos[rand.nextInt(_promos.length)];
  }
}
