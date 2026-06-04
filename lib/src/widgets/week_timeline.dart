import 'package:flutter/material.dart';

import '../models.dart';
import '../screens/schedule_screen.dart';

class WeekTimeline extends StatelessWidget {
  const WeekTimeline({super.key, required this.lessons});

  final List<RuzLesson> lessons;

  static const List<String> days = <String>['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  static const List<String> slots = <String>[
    '08:30\n10:00',
    '10:10\n11:40',
    '11:50\n13:20',
    '14:00\n15:30',
    '15:40\n17:10',
    '17:20\n18:50',
    '18:55\n20:25',
    '20:30\n22:00',
  ];

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<RuzLesson>>{};
    for (final lesson in lessons) {
      final key = '${lesson.weekdayIndex}:${lesson.slotIndex}';
      grouped.putIfAbsent(key, () => <RuzLesson>[]).add(lesson);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 980,
          child: Column(
            children: <Widget>[
              const _HeaderRow(days: days),
              const SizedBox(height: 6),
              for (var slotIndex = 0; slotIndex < slots.length; slotIndex++) ...<Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    _TimeCell(label: slots[slotIndex]),
                    const SizedBox(width: 6),
                    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) ...<Widget>[
                      Expanded(
                        child: _LessonBucket(
                          lessons: grouped['$dayIndex:$slotIndex'] ?? <RuzLesson>[],
                        ),
                      ),
                      if (dayIndex != days.length - 1) const SizedBox(width: 6),
                    ],
                  ],
                ),
                if (slotIndex != slots.length - 1) const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.days});

  final List<String> days;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox(width: 76),
        const SizedBox(width: 6),
        for (var index = 0; index < days.length; index++) ...<Widget>[
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: DateTime.now().weekday - 1 == index
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  days[index],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          ),
          if (index != days.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 96,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}

class _LessonBucket extends StatelessWidget {
  const _LessonBucket({required this.lessons});

  final List<RuzLesson> lessons;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: lessons.isEmpty
            ? const SizedBox.shrink()
            : ListView.separated(
                padding: const EdgeInsets.all(5),
                itemCount: lessons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (BuildContext context, int index) {
                  final lesson = lessons[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => showLessonDetails(context, lesson),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: lesson.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: lesson.accentColor.withValues(alpha: 0.35)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              lesson.subject,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            Text(
                              lesson.auditorium.isEmpty ? lesson.timeRange : '${lesson.timeRange} • ${lesson.auditorium}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
