import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import 'schedule_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ScheduleScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Расписание Финуниверситета'),
        actions: <Widget>[
          Tooltip(
            message: 'Web-прокси localhost:3000',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.hub_outlined, size: 18),
                Switch(
                  value: store.isUsingProxy,
                  onChanged: store.setProxy,
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: <Widget>[
                    _SearchPanel(controller: searchController),
                    const SizedBox(height: 14),
                    if (store.error != null && store.searchResults.isEmpty)
                      _ErrorBanner(message: store.error!),
                    if (store.favorites.isNotEmpty) ...<Widget>[
                      _EntityRail(
                        title: 'Избранное',
                        entities: store.favorites,
                        onOpen: _openSchedule,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (store.recent.isNotEmpty) ...<Widget>[
                      _EntityRail(
                        title: 'Недавно открывали',
                        entities: store.recent,
                        onOpen: _openSchedule,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _SearchResults(onOpen: _openSchedule),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openSchedule(RuzEntity entity) async {
    final store = ScheduleScope.of(context);
    await store.openSchedule(entity);
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ScheduleScreen(),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final store = ScheduleScope.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SegmentedButton<RuzEntityType>(
              segments: RuzEntityType.values
                  .map(
                    (RuzEntityType type) => ButtonSegment<RuzEntityType>(
                      value: type,
                      icon: Icon(type.icon),
                      label: Text(type.title),
                    ),
                  )
                  .toList(),
              selected: <RuzEntityType>{store.searchType},
              onSelectionChanged: (Set<RuzEntityType> values) => store.setSearchType(values.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Очистить',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          controller.clear();
                          store.queueSearch('');
                        },
                      ),
                border: const OutlineInputBorder(),
                hintText: store.searchType == RuzEntityType.group
                    ? 'Введите группу, например ПИ22-1'
                    : 'Введите фамилию преподавателя',
              ),
              onChanged: (String value) {
                store.queueSearch(value);
              },
              onSubmitted: store.searchNow,
            ),
            const SizedBox(height: 8),
            Text(
              store.isUsingProxy
                  ? 'Запросы идут через localhost:3000. Для web-показа прокси должен быть запущен.'
                  : 'Прямой режим подходит для Windows-приложения; в браузере обычно нужен прокси.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.onOpen});

  final ValueChanged<RuzEntity> onOpen;

  @override
  Widget build(BuildContext context) {
    final store = ScheduleScope.of(context);

    if (store.searching) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (store.searchText.trim().length < 3) {
      return const _EmptyState(
        icon: Icons.manage_search_outlined,
        title: 'Начните поиск',
        text: 'Введите минимум 3 символа. Можно искать группы и преподавателей.',
      );
    }
    if (store.searchResults.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off_outlined,
        title: 'Нет результатов',
        text: 'Попробуйте другой запрос или переключите тип поиска.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Результаты поиска', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...store.searchResults.map(
          (RuzEntity entity) => _EntityTile(
            entity: entity,
            onOpen: onOpen,
          ),
        ),
      ],
    );
  }
}

class _EntityRail extends StatelessWidget {
  const _EntityRail({
    required this.title,
    required this.entities,
    required this.onOpen,
  });

  final String title;
  final List<RuzEntity> entities;
  final ValueChanged<RuzEntity> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entities.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int index) {
              final entity = entities[index];
              return ActionChip(
                avatar: Icon(entity.type.icon, size: 18),
                label: Text(entity.title),
                onPressed: () => onOpen(entity),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EntityTile extends StatelessWidget {
  const _EntityTile({
    required this.entity,
    required this.onOpen,
  });

  final RuzEntity entity;
  final ValueChanged<RuzEntity> onOpen;

  @override
  Widget build(BuildContext context) {
    final store = ScheduleScope.of(context);
    final isFavorite = store.isFavorite(entity);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(entity.type.icon),
        title: Text(entity.title),
        subtitle: entity.subtitle.isEmpty ? Text(entity.type.title) : Text(entity.subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: isFavorite ? 'Убрать из избранного' : 'В избранное',
              icon: Icon(isFavorite ? Icons.star : Icons.star_border),
              onPressed: () => store.toggleFavorite(entity),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => onOpen(entity),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
