import 'package:flutter/material.dart';

import 'ruz_api_client.dart';
import 'schedule_store.dart';
import 'screens/home_screen.dart';

class FinanceScheduleApp extends StatefulWidget {
  const FinanceScheduleApp({super.key});

  @override
  State<FinanceScheduleApp> createState() => _FinanceScheduleAppState();
}

class _FinanceScheduleAppState extends State<FinanceScheduleApp> {
  late final ScheduleStore store;

  @override
  void initState() {
    super.initState();
    store = ScheduleStore(RuzApiClient());
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScheduleScope(
      store: store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Расписание Финуниверситета',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F6F62),
            primary: const Color(0xFF0F6F62),
            secondary: const Color(0xFFB1633E),
            surface: const Color(0xFFF8FAF8),
          ),
          scaffoldBackgroundColor: const Color(0xFFF4F7F5),
          cardTheme: const CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class ScheduleScope extends InheritedNotifier<ScheduleStore> {
  const ScheduleScope({
    super.key,
    required ScheduleStore store,
    required super.child,
  }) : super(notifier: store);

  static ScheduleStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ScheduleScope>();
    assert(scope != null, 'ScheduleScope not found');
    return scope!.notifier!;
  }
}
