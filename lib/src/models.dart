import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum RuzEntityType {
  group('group', 'Группа', Icons.groups_2_outlined),
  person('person', 'Преподаватель', Icons.school_outlined);

  const RuzEntityType(this.apiName, this.title, this.icon);

  final String apiName;
  final String title;
  final IconData icon;
}

enum ScheduleView {
  list('Список', Icons.view_agenda_outlined),
  week('Неделя', Icons.calendar_month_outlined),
  analytics('Итоги', Icons.query_stats_outlined);

  const ScheduleView(this.title, this.icon);

  final String title;
  final IconData icon;
}

class RuzEntity {
  const RuzEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
  });

  final String id;
  final String title;
  final String subtitle;
  final RuzEntityType type;

  factory RuzEntity.fromJson(Map<String, dynamic> json, RuzEntityType fallbackType) {
    final rawType = '${json['type'] ?? fallbackType.apiName}';
    return RuzEntity(
      id: '${json['id'] ?? ''}',
      title: '${json['label'] ?? ''}',
      subtitle: '${json['description'] ?? ''}'.trim(),
      type: RuzEntityType.values.firstWhere(
        (RuzEntityType value) => value.apiName == rawType,
        orElse: () => fallbackType,
      ),
    );
  }

  String get key => '${type.apiName}:$id';
}

class RuzLesson {
  const RuzLesson({
    required this.id,
    required this.date,
    required this.startsAt,
    required this.endsAt,
    required this.subject,
    required this.workKind,
    required this.lecturer,
    required this.group,
    required this.auditorium,
    required this.building,
    required this.note,
    required this.onlineUrl,
  });

  final int id;
  final DateTime date;
  final String startsAt;
  final String endsAt;
  final String subject;
  final String workKind;
  final String lecturer;
  final String group;
  final String auditorium;
  final String building;
  final String note;
  final String onlineUrl;

  factory RuzLesson.fromJson(Map<String, dynamic> json) {
    return RuzLesson(
      id: _asInt(json['lessonOid'] ?? json['id']),
      date: _parseRuzDate('${json['date'] ?? ''}'),
      startsAt: '${json['beginLesson'] ?? ''}',
      endsAt: '${json['endLesson'] ?? ''}',
      subject: _text(json['discipline'], fallback: 'Занятие без названия'),
      workKind: _text(json['kindOfWork']),
      lecturer: _text(json['lecturer']),
      group: _text(json['group'] ?? json['stream']),
      auditorium: _text(json['auditorium']),
      building: _text(json['building']),
      note: _text(json['note'] ?? json['detailInfo'] ?? json['parentschedule']),
      onlineUrl: _text(json['url1'] ?? json['url2']),
    );
  }

  String get dayTitle => DateFormat('EEEE, d MMMM', 'ru').format(date);

  String get compactDate => DateFormat('d MMM', 'ru').format(date);

  String get timeRange {
    if (startsAt.isEmpty && endsAt.isEmpty) {
      return 'Время не указано';
    }
    if (endsAt.isEmpty) {
      return startsAt;
    }
    return '$startsAt - $endsAt';
  }

  String get place {
    final parts = <String>[
      if (auditorium.isNotEmpty) auditorium,
      if (building.isNotEmpty) building,
    ];
    return parts.isEmpty ? 'Место не указано' : parts.join(', ');
  }

  int get weekdayIndex => date.weekday - 1;

  int get slotIndex {
    const starts = <String, int>{
      '08:30': 0,
      '09:00': 0,
      '10:10': 1,
      '11:50': 2,
      '14:00': 3,
      '15:40': 4,
      '17:20': 5,
      '18:55': 6,
      '20:30': 7,
    };
    return starts[startsAt] ?? _slotFromHour(startsAt);
  }

  Color get accentColor {
    final lower = workKind.toLowerCase();
    if (lower.contains('лек')) {
      return const Color(0xFF257A5E);
    }
    if (lower.contains('лаб')) {
      return const Color(0xFF7552A8);
    }
    if (lower.contains('экз') || lower.contains('зач')) {
      return const Color(0xFFC15F32);
    }
    if (lower.contains('прак') || lower.contains('сем')) {
      return const Color(0xFF2F68A8);
    }
    return const Color(0xFF52616B);
  }
}

class ScheduleSummary {
  const ScheduleSummary({
    required this.total,
    required this.online,
    required this.byKind,
    required this.byDay,
  });

  final int total;
  final int online;
  final Map<String, int> byKind;
  final Map<String, int> byDay;

  factory ScheduleSummary.fromLessons(List<RuzLesson> lessons) {
    final byKind = <String, int>{};
    final byDay = <String, int>{};
    var online = 0;

    for (final lesson in lessons) {
      if (lesson.onlineUrl.isNotEmpty) {
        online++;
      }
      final kind = lesson.workKind.isEmpty ? 'Без типа' : lesson.workKind;
      byKind[kind] = (byKind[kind] ?? 0) + 1;
      byDay[lesson.dayTitle] = (byDay[lesson.dayTitle] ?? 0) + 1;
    }

    return ScheduleSummary(
      total: lessons.length,
      online: online,
      byKind: byKind,
      byDay: byDay,
    );
  }
}

String _text(dynamic value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text == 'null' ? fallback : text;
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse('$value') ?? 0;
}

DateTime _parseRuzDate(String value) {
  for (final pattern in <String>['yyyy-MM-dd', 'yyyy.MM.dd']) {
    try {
      return DateFormat(pattern).parseStrict(value);
    } catch (_) {
      // Try another known RUZ date format.
    }
  }
  return DateTime.now();
}

int _slotFromHour(String value) {
  final hour = int.tryParse(value.split(':').first) ?? 8;
  if (hour < 10) return 0;
  if (hour < 12) return 1;
  if (hour < 14) return 2;
  if (hour < 16) return 3;
  if (hour < 18) return 4;
  if (hour < 19) return 5;
  if (hour < 21) return 6;
  return 7;
}
