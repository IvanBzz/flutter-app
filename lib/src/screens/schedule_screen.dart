import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../models.dart';
import '../widgets/week_timeline.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ScheduleScope.of(context);
    final entity = store.selectedEntity;
    if (entity == null) {
      return const Scaffold(
        body: Center(child: Text('Расписание не выбрано')),
      );
    }

    final weekEnd = store.weekStart.add(const Duration(days: 6));

    return Scaffold(
      appBar: AppBar(
        title: Text(entity.title),
        actions: <Widget>[
          IconButton(
            tooltip: store.isFavorite(entity) ? 'Убрать из избранного' : 'В избранное',
            icon: Icon(store.isFavorite(entity) ? Icons.star : Icons.star_border),
            onPressed: () => store.toggleFavorite(entity),
          ),
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: store.reloadSchedule,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(entity.type.title, style: Theme.of(context).textTheme.labelLarge),
                      if (entity.subtitle.isNotEmpty)
                        Text(
                          entity.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          IconButton.filledTonal(
                            tooltip: 'Предыдущая неделя',
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => store.shiftWeek(-1),
                          ),
                          Expanded(
                            child: Text(
                              '${DateFormat('d MMM', 'ru').format(store.weekStart)} - ${DateFormat('d MMM y', 'ru').format(weekEnd)}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Следующая неделя',
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => store.shiftWeek(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<ScheduleView>(
                        segments: ScheduleView.values
                            .map(
                              (ScheduleView view) => ButtonSegment<ScheduleView>(
                                value: view,
                                icon: Icon(view.icon),
                                label: Text(view.title),
                              ),
                            )
                            .toList(),
                        selected: <ScheduleView>{store.view},
                        onSelectionChanged: (Set<ScheduleView> values) => store.setView(values.first),
                      ),
                      const SizedBox(height: 10),
                      _ApiLine(uri: store.currentApiUri),
                    ],
                  ),
                ),
                Expanded(
                  child: _ScheduleBody(
                    lessons: store.lessons,
                    loading: store.loadingSchedule,
                    error: store.error,
                    view: store.view,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleBody extends StatelessWidget {
  const _ScheduleBody({
    required this.lessons,
    required this.loading,
    required this.error,
    required this.view,
  });

  final List<RuzLesson> lessons;
  final bool loading;
  final String? error;
  final ScheduleView view;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    if (lessons.isEmpty) {
      return const Center(child: Text('На выбранной неделе занятий нет'));
    }

    return switch (view) {
      ScheduleView.list => _LessonList(lessons: lessons),
      ScheduleView.week => WeekTimeline(lessons: lessons),
      ScheduleView.analytics => _AnalyticsPanel(lessons: lessons),
    };
  }
}

class _LessonList extends StatelessWidget {
  const _LessonList({required this.lessons});

  final List<RuzLesson> lessons;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      itemCount: lessons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final lesson = lessons[index];
        return _LessonCard(lesson: lesson);
      },
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson});

  final RuzLesson lesson;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showLessonDetails(context, lesson),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 6,
                height: 96,
                decoration: BoxDecoration(
                  color: lesson.accentColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(lesson.subject, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _MetaLine(icon: Icons.event_outlined, text: '${lesson.dayTitle}, ${lesson.timeRange}'),
                    _MetaLine(icon: Icons.category_outlined, text: lesson.workKind),
                    _MetaLine(icon: Icons.place_outlined, text: lesson.place),
                    _MetaLine(icon: Icons.person_outline, text: lesson.lecturer),
                    _MetaLine(icon: Icons.groups_outlined, text: lesson.group),
                    if (lesson.onlineUrl.isNotEmpty)
                      const _MetaLine(icon: Icons.video_call_outlined, text: 'Есть онлайн-ссылка'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsPanel extends StatelessWidget {
  const _AnalyticsPanel({required this.lessons});

  final List<RuzLesson> lessons;

  @override
  Widget build(BuildContext context) {
    final summary = ScheduleSummary.fromLessons(lessons);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _MetricCard(title: 'Всего занятий', value: '${summary.total}', icon: Icons.event_available_outlined),
            _MetricCard(title: 'Онлайн', value: '${summary.online}', icon: Icons.video_call_outlined),
            _MetricCard(title: 'Дней с занятиями', value: '${summary.byDay.length}', icon: Icons.date_range_outlined),
          ],
        ),
        const SizedBox(height: 16),
        _Breakdown(title: 'По типам занятий', values: summary.byKind),
        const SizedBox(height: 12),
        _Breakdown(title: 'По дням', values: summary.byDay),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                  Text(title),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.title,
    required this.values,
  });

  final String title;
  final Map<String, int> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.values.fold<int>(1, (int a, int b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...values.entries.map(
              (MapEntry<String, int> entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: <Widget>[
                    SizedBox(width: 170, child: Text(entry.key, maxLines: 2, overflow: TextOverflow.ellipsis)),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: entry.value / maxValue,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${entry.value}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApiLine extends StatelessWidget {
  const _ApiLine({required this.uri});

  final Uri? uri;

  @override
  Widget build(BuildContext context) {
    if (uri == null) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: <Widget>[
            const Icon(Icons.link, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$uri',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
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

void showLessonDetails(BuildContext context, RuzLesson lesson) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          shrinkWrap: true,
          children: <Widget>[
            Text(lesson.subject, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _MetaLine(icon: Icons.event_outlined, text: '${lesson.dayTitle}, ${lesson.timeRange}'),
            _MetaLine(icon: Icons.category_outlined, text: lesson.workKind),
            _MetaLine(icon: Icons.place_outlined, text: lesson.place),
            _MetaLine(icon: Icons.person_outline, text: lesson.lecturer),
            _MetaLine(icon: Icons.groups_outlined, text: lesson.group),
            _MetaLine(icon: Icons.notes_outlined, text: lesson.note),
            _MetaLine(icon: Icons.video_call_outlined, text: lesson.onlineUrl),
          ],
        ),
      );
    },
  );
}
