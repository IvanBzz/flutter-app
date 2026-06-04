import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:furshed/src/app.dart';
import 'package:furshed/src/models.dart';
import 'package:furshed/src/widgets/week_timeline.dart';

void main() {
  testWidgets('shows RUZ search home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FinanceScheduleApp());

    expect(find.text('Расписание Финуниверситета'), findsWidgets);
    expect(find.text('Группа'), findsOneWidget);
    expect(find.text('Преподаватель'), findsOneWidget);
    expect(find.text('Начните поиск'), findsOneWidget);
  });

  testWidgets('renders week timeline without layout exceptions', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 420,
            child: WeekTimeline(
              lessons: <RuzLesson>[
                RuzLesson(
                  id: 1,
                  date: DateTime(2026, 6, 2),
                  startsAt: '09:00',
                  endsAt: '10:30',
                  subject: 'Mobile API',
                  workKind: 'practice',
                  lecturer: 'Ivanov',
                  group: 'PI22-1',
                  auditorium: 'B4/2517',
                  building: 'Campus',
                  note: '',
                  onlineUrl: '',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Mobile API'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
