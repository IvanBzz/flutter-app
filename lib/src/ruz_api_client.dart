import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'models.dart';

class RuzApiException implements Exception {
  const RuzApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RuzApiClient {
  RuzApiClient({
    Dio? dio,
    bool? useProxy,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
              ),
            ),
        useProxy = useProxy ?? kIsWeb;

  final Dio _dio;
  bool useProxy;

  String get baseUrl => useProxy ? 'http://localhost:3000' : 'https://ruz.fa.ru/api';

  Future<List<RuzEntity>> search({
    required String query,
    required RuzEntityType type,
  }) async {
    final term = query.trim();
    if (term.length < 3) {
      return <RuzEntity>[];
    }

    final data = await _getList(
      '/search',
      <String, dynamic>{
        'term': term,
        'type': type.apiName,
      },
    );

    return data
        .map((dynamic item) => RuzEntity.fromJson(Map<String, dynamic>.from(item as Map), type))
        .where((RuzEntity item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList();
  }

  Future<List<RuzLesson>> schedule({
    required RuzEntity entity,
    required DateTime start,
    required DateTime finish,
  }) async {
    final data = await _getList(
      '/schedule/${entity.type.apiName}/${entity.id}',
      <String, dynamic>{
        'start': _formatDate(start),
        'finish': _formatDate(finish),
        'lng': '1',
      },
    );

    final lessons = data
        .map((dynamic item) => RuzLesson.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    lessons.sort((RuzLesson a, RuzLesson b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return a.startsAt.compareTo(b.startsAt);
    });
    return lessons;
  }

  Uri scheduleUri({
    required RuzEntity entity,
    required DateTime start,
    required DateTime finish,
  }) {
    return Uri.parse('$baseUrl/schedule/${entity.type.apiName}/${entity.id}').replace(
      queryParameters: <String, String>{
        'start': _formatDate(start),
        'finish': _formatDate(finish),
        'lng': '1',
      },
    );
  }

  Future<List<dynamic>> _getList(String path, Map<String, dynamic> queryParameters) async {
    try {
      final response = await _dio.get<dynamic>(
        '$baseUrl$path',
        queryParameters: queryParameters,
      );
      final data = response.data;

      if (data is Map && data['error'] == 1) {
        throw RuzApiException('${data['message'] ?? 'RUZ API вернул ошибку'}');
      }
      if (data is! List) {
        throw const RuzApiException('RUZ API вернул неожиданный формат данных');
      }
      return data;
    } on DioException catch (error) {
      throw RuzApiException(_networkMessage(error));
    }
  }
}

String _formatDate(DateTime date) => DateFormat('yyyy.MM.dd').format(date);

String _networkMessage(DioException error) {
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout) {
    return 'RUZ API не ответил вовремя';
  }
  if (kIsWeb) {
    return 'Не удалось загрузить данные. Для web-запуска должен работать прокси localhost:3000';
  }
  return 'Не удалось загрузить данные: ${error.message ?? error.type.name}';
}
