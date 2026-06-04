import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'ruz_api_client.dart';

class ScheduleStore extends ChangeNotifier {
  ScheduleStore(this.api);

  final RuzApiClient api;

  RuzEntityType searchType = RuzEntityType.group;
  String searchText = '';
  List<RuzEntity> searchResults = <RuzEntity>[];
  List<RuzLesson> lessons = <RuzLesson>[];
  RuzEntity? selectedEntity;
  DateTime weekStart = monday(DateTime.now());
  ScheduleView view = ScheduleView.list;
  bool searching = false;
  bool loadingSchedule = false;
  String? error;

  final Set<String> _favoriteKeys = <String>{};
  final List<RuzEntity> _recent = <RuzEntity>[];
  Timer? _searchTimer;

  List<RuzEntity> get recent => List<RuzEntity>.unmodifiable(_recent);

  List<RuzEntity> get favorites {
    final known = <String, RuzEntity>{};
    for (final entity in <RuzEntity>[..._recent, ...searchResults]) {
      known[entity.key] = entity;
    }
    return _favoriteKeys.map((String key) => known[key]).whereType<RuzEntity>().toList();
  }

  ScheduleSummary get summary => ScheduleSummary.fromLessons(lessons);

  bool get isUsingProxy => api.useProxy;

  Uri? get currentApiUri {
    final entity = selectedEntity;
    if (entity == null) {
      return null;
    }
    return api.scheduleUri(
      entity: entity,
      start: weekStart,
      finish: weekStart.add(const Duration(days: 6)),
    );
  }

  void setProxy(bool value) {
    api.useProxy = value;
    notifyListeners();
    if (searchText.trim().length >= 3) {
      searchNow(searchText);
    }
  }

  void setSearchType(RuzEntityType type) {
    searchType = type;
    searchResults = <RuzEntity>[];
    error = null;
    notifyListeners();
    if (searchText.trim().length >= 3) {
      searchNow(searchText);
    }
  }

  void queueSearch(String value) {
    searchText = value;
    _searchTimer?.cancel();
    if (value.trim().length < 3) {
      searching = false;
      searchResults = <RuzEntity>[];
      error = null;
      notifyListeners();
      return;
    }
    searching = true;
    notifyListeners();
    _searchTimer = Timer(const Duration(milliseconds: 380), () => searchNow(value));
  }

  Future<void> searchNow(String value) async {
    searchText = value;
    if (value.trim().length < 3) {
      return;
    }
    searching = true;
    error = null;
    notifyListeners();

    try {
      final results = await api.search(query: value, type: searchType);
      searchResults = results;
      if (results.isEmpty) {
        error = 'Ничего не найдено. Попробуйте другой запрос.';
      }
    } on RuzApiException catch (exception) {
      searchResults = <RuzEntity>[];
      error = exception.message;
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  Future<void> openSchedule(RuzEntity entity) async {
    selectedEntity = entity;
    _remember(entity);
    await reloadSchedule();
  }

  Future<void> reloadSchedule() async {
    final entity = selectedEntity;
    if (entity == null) {
      return;
    }
    loadingSchedule = true;
    error = null;
    notifyListeners();

    try {
      lessons = await api.schedule(
        entity: entity,
        start: weekStart,
        finish: weekStart.add(const Duration(days: 6)),
      );
    } on RuzApiException catch (exception) {
      lessons = <RuzLesson>[];
      error = exception.message;
    } finally {
      loadingSchedule = false;
      notifyListeners();
    }
  }

  void shiftWeek(int delta) {
    weekStart = weekStart.add(Duration(days: delta * 7));
    reloadSchedule();
  }

  void setView(ScheduleView value) {
    view = value;
    notifyListeners();
  }

  bool isFavorite(RuzEntity entity) => _favoriteKeys.contains(entity.key);

  void toggleFavorite(RuzEntity entity) {
    if (!_favoriteKeys.add(entity.key)) {
      _favoriteKeys.remove(entity.key);
    }
    _remember(entity);
    notifyListeners();
  }

  void _remember(RuzEntity entity) {
    _recent.removeWhere((RuzEntity item) => item.key == entity.key);
    _recent.insert(0, entity);
    if (_recent.length > 8) {
      _recent.removeRange(8, _recent.length);
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}

DateTime monday(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}
