import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:time_scheduler_table/time_scheduler_table.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  runApp(const ScheduleApp());
}

class ScheduleApp extends StatelessWidget {
  const ScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Расписание ФА',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF256D63),
        scaffoldBackgroundColor: const Color(0xFFF7F8F6),
      ),
      home: const SearchPage(),
    );
  }
}

enum SearchKind {
  group('group', 'Группы'),
  person('person', 'Преподаватели');

  const SearchKind(this.apiValue, this.title);

  final String apiValue;
  final String title;
}

enum ViewMode {
  list('Список', Icons.view_agenda_outlined),
  calendar('Календарь', Icons.calendar_month_outlined);

  const ViewMode(this.title, this.icon);

  final String title;
  final IconData icon;
}

class SearchItem {
  const SearchItem({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  factory SearchItem.fromJson(Map<String, dynamic> json) {
    return SearchItem(
      id: '${json['id'] ?? ''}',
      label: '${json['label'] ?? ''}',
      description: '${json['description'] ?? ''}',
    );
  }
}

class Lesson {
  const Lesson({
    required this.id,
    required this.date,
    required this.beginLesson,
    required this.endLesson,
    required this.discipline,
    required this.kindOfWork,
    required this.lecturer,
    required this.auditorium,
    required this.building,
    required this.group,
  });

  final int id;
  final DateTime date;
  final String beginLesson;
  final String endLesson;
  final String discipline;
  final String kindOfWork;
  final String lecturer;
  final String auditorium;
  final String building;
  final String group;

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: _asInt(json['lessonOid'] ?? json['id']),
      date: _parseDate('${json['date'] ?? ''}'),
      beginLesson: '${json['beginLesson'] ?? ''}',
      endLesson: '${json['endLesson'] ?? ''}',
      discipline: '${json['discipline'] ?? 'Без названия'}',
      kindOfWork: '${json['kindOfWork'] ?? ''}',
      lecturer: '${json['lecturer'] ?? ''}',
      auditorium: '${json['auditorium'] ?? ''}',
      building: '${json['building'] ?? ''}',
      group: '${json['group'] ?? ''}',
    );
  }

  String get dateLabel => DateFormat('EEEE, d MMMM', 'ru').format(date);

  String get timeLabel {
    if (beginLesson.isEmpty && endLesson.isEmpty) {
      return 'Время не указано';
    }
    return '$beginLesson - $endLesson';
  }

  String get placeLabel {
    final parts = <String>[
      if (auditorium.isNotEmpty) auditorium,
      if (building.isNotEmpty) building,
    ];
    return parts.isEmpty ? 'Аудитория не указана' : parts.join(', ');
  }

  String get peopleLabel {
    final parts = <String>[
      if (group.isNotEmpty) group,
      if (lecturer.isNotEmpty) lecturer,
    ];
    return parts.join(' • ');
  }

  Event toEvent() {
    return Event(
      title: discipline,
      time: '$timeLabel\n$placeLabel',
      color: _lessonColor(kindOfWork),
      columnIndex: date.weekday - 1,
      rowIndex: _lessonRow(beginLesson),
    );
  }
}

class RuzApi {
  RuzApi({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 12)));

  final Dio _dio;
  bool useProxy = false;

  String get _baseUrl => useProxy ? 'http://localhost:3000' : 'https://ruz.fa.ru/api';

  Future<List<SearchItem>> search(String term, SearchKind kind) async {
    final query = term.trim();
    if (query.length < 3) {
      return <SearchItem>[];
    }

    final response = await _dio.get<dynamic>(
      '$_baseUrl/search',
      queryParameters: <String, dynamic>{
        'term': query,
        'type': kind.apiValue,
      },
    );

    final data = response.data;
    if (data is! List) {
      return <SearchItem>[];
    }

    return data
        .map((dynamic item) => SearchItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .where((SearchItem item) => item.id.isNotEmpty && item.label.isNotEmpty)
        .toList();
  }

  Future<List<Lesson>> schedule({
    required String id,
    required SearchKind kind,
    required DateTime start,
    required DateTime finish,
  }) async {
    final response = await _dio.get<dynamic>(
      '$_baseUrl/schedule/${kind.apiValue}/$id',
      queryParameters: <String, dynamic>{
        'start': _apiDate(start),
        'finish': _apiDate(finish),
      },
    );

    final data = response.data;
    if (data is! List) {
      return <Lesson>[];
    }

    final lessons = data
        .map((dynamic item) => Lesson.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    lessons.sort((Lesson a, Lesson b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) {
        return byDate;
      }
      return a.beginLesson.compareTo(b.beginLesson);
    });
    return lessons;
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final RuzApi _api = RuzApi();
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  SearchKind _kind = SearchKind.group;
  List<SearchItem> _items = <SearchItem>[];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _items = <SearchItem>[];
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _api.search(query, _kind);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
        _error = items.isEmpty ? 'Ничего не найдено' : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _items = <SearchItem>[];
        _error = 'Не удалось загрузить данные. Проверьте интернет или включите прокси.';
      });
    }
  }

  void _openSchedule(SearchItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SchedulePage(
          api: _api,
          item: item,
          kind: _kind,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Расписание ФА'),
        actions: <Widget>[
          Tooltip(
            message: 'Использовать localhost:3000',
            child: Switch(
              value: _api.useProxy,
              onChanged: (bool value) {
                setState(() => _api.useProxy = value);
                _search(_controller.text);
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              SegmentedButton<SearchKind>(
                segments: const <ButtonSegment<SearchKind>>[
                  ButtonSegment<SearchKind>(
                    value: SearchKind.group,
                    label: Text('Группы'),
                    icon: Icon(Icons.groups_2_outlined),
                  ),
                  ButtonSegment<SearchKind>(
                    value: SearchKind.person,
                    label: Text('Преподаватели'),
                    icon: Icon(Icons.school_outlined),
                  ),
                ],
                selected: <SearchKind>{_kind},
                onSelectionChanged: (Set<SearchKind> values) {
                  setState(() {
                    _kind = values.first;
                    _items = <SearchItem>[];
                    _error = null;
                  });
                  _search(_controller.text);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Очистить',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controller.clear();
                            _onSearchChanged('');
                          },
                        ),
                  border: const OutlineInputBorder(),
                  hintText: _kind == SearchKind.group
                      ? 'Например: ПИ22-1'
                      : 'Фамилия преподавателя',
                ),
                onChanged: (String value) {
                  setState(() {});
                  _onSearchChanged(value);
                },
                onSubmitted: _search,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _SearchResults(
                  loading: _loading,
                  error: _error,
                  items: _items,
                  onTap: _openSchedule,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.loading,
    required this.error,
    required this.items,
    required this.onTap,
  });

  final bool loading;
  final String? error;
  final List<SearchItem> items;
  final ValueChanged<SearchItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Text(
          error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    if (items.isEmpty) {
      return const Center(
        child: Text('Введите минимум 3 символа и выберите результат поиска'),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final item = items[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.chevron_right),
            title: Text(item.label),
            subtitle: item.description.isEmpty ? null : Text(item.description),
            onTap: () => onTap(item),
          ),
        );
      },
    );
  }
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({
    super.key,
    required this.api,
    required this.item,
    required this.kind,
  });

  final RuzApi api;
  final SearchItem item;
  final SearchKind kind;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late DateTime _weekStart;
  ViewMode _mode = ViewMode.list;
  List<Lesson> _lessons = <Lesson>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _weekStart = _monday(DateTime.now());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final lessons = await widget.api.schedule(
        id: widget.item.id,
        kind: widget.kind,
        start: _weekStart,
        finish: _weekStart.add(const Duration(days: 6)),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _lessons = lessons;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _lessons = <Lesson>[];
        _error = 'Расписание не загрузилось. Попробуйте другую неделю или прокси.';
      });
    }
  }

  void _shiftWeek(int delta) {
    setState(() => _weekStart = _weekStart.add(Duration(days: 7 * delta)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.label),
        actions: <Widget>[
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(widget.kind.title, style: titleStyle),
                  if (widget.item.description.isNotEmpty)
                    Text(
                      widget.item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      IconButton.filledTonal(
                        tooltip: 'Предыдущая неделя',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _shiftWeek(-1),
                      ),
                      Expanded(
                        child: Text(
                          '${DateFormat('d MMM', 'ru').format(_weekStart)} - ${DateFormat('d MMM y', 'ru').format(weekEnd)}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Следующая неделя',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _shiftWeek(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ViewMode>(
                    segments: ViewMode.values
                        .map(
                          (ViewMode mode) => ButtonSegment<ViewMode>(
                            value: mode,
                            label: Text(mode.title),
                            icon: Icon(mode.icon),
                          ),
                        )
                        .toList(),
                    selected: <ViewMode>{_mode},
                    onSelectionChanged: (Set<ViewMode> values) {
                      setState(() => _mode = values.first);
                    },
                  ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    if (_lessons.isEmpty) {
      return const Center(child: Text('На выбранной неделе занятий нет'));
    }

    if (_mode == ViewMode.calendar) {
      return _CalendarSchedule(lessons: _lessons);
    }
    return _LessonList(lessons: _lessons);
  }
}

class _LessonList extends StatelessWidget {
  const _LessonList({required this.lessons});

  final List<Lesson> lessons;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: lessons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final lesson = lessons[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  lesson.discipline,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _IconLine(icon: Icons.event_outlined, text: '${lesson.dateLabel}, ${lesson.timeLabel}'),
                _IconLine(icon: Icons.category_outlined, text: lesson.kindOfWork),
                _IconLine(icon: Icons.place_outlined, text: lesson.placeLabel),
                if (lesson.peopleLabel.isNotEmpty)
                  _IconLine(icon: Icons.person_outline, text: lesson.peopleLabel),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CalendarSchedule extends StatelessWidget {
  const _CalendarSchedule({required this.lessons});

  final List<Lesson> lessons;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 860,
        child: TimeSchedulerTable(
          eventList: lessons.map((Lesson lesson) => lesson.toEvent()).toList(),
          cellHeight: 70,
          cellWidth: 110,
          currentColumnTitleIndex: DateTime.now().weekday - 1,
          columnLabels: const <String>['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
          rowLabels: const <String>[
            '08:30 - 10:00',
            '10:10 - 11:40',
            '11:50 - 13:20',
            '14:00 - 15:30',
            '15:40 - 17:10',
            '17:20 - 18:50',
            '18:55 - 20:25',
            '20:30 - 22:00',
          ],
          eventAlert: EventAlert(),
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

DateTime _monday(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

String _apiDate(DateTime date) {
  return DateFormat('yyyy.MM.dd').format(date);
}

DateTime _parseDate(String value) {
  for (final pattern in <String>['yyyy.MM.dd', 'yyyy-MM-dd']) {
    try {
      return DateFormat(pattern).parseStrict(value);
    } catch (_) {
      // Try next API date format.
    }
  }
  return DateTime.now();
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse('$value') ?? 0;
}

int _lessonRow(String time) {
  final rowByStart = <String, int>{
    '08:30': 0,
    '10:10': 1,
    '11:50': 2,
    '14:00': 3,
    '15:40': 4,
    '17:20': 5,
    '18:55': 6,
    '20:30': 7,
  };
  if (rowByStart.containsKey(time)) {
    return rowByStart[time]!;
  }

  final parts = time.split(':');
  if (parts.length != 2) {
    return 0;
  }
  final hour = int.tryParse(parts[0]) ?? 8;
  if (hour < 10) {
    return 0;
  }
  if (hour < 12) {
    return 1;
  }
  if (hour < 14) {
    return 2;
  }
  if (hour < 16) {
    return 3;
  }
  if (hour < 18) {
    return 4;
  }
  if (hour < 19) {
    return 5;
  }
  if (hour < 21) {
    return 6;
  }
  return 7;
}

Color _lessonColor(String kind) {
  final normalized = kind.toLowerCase();
  if (normalized.contains('лек')) {
    return const Color(0xFF2E7D32);
  }
  if (normalized.contains('прак') || normalized.contains('сем')) {
    return const Color(0xFF1565C0);
  }
  if (normalized.contains('лаб')) {
    return const Color(0xFF6A1B9A);
  }
  return const Color(0xFF455A64);
}
