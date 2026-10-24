import 'package:flutter/material.dart';
import '../../models/incident_model.dart';
import '../../state/app_state.dart';
import '../widgets/incident_dialog.dart';

class ActivityLogsScreen extends StatefulWidget {
  final AppState state;

  const ActivityLogsScreen({super.key, required this.state});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  IncidentType? _selectedTypeFilter;
  bool _onlyUnprocessed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = widget.state;

    final filteredIncidents = state.incidents.where((i) {
      if (_selectedTypeFilter != null && i.type != _selectedTypeFilter) {
        return false;
      }
      if (_onlyUnprocessed && i.processed) {
        return false;
      }
      if (state.searchQuery.isNotEmpty) {
        final q = state.searchQuery.toLowerCase();
        return i.description.toLowerCase().contains(q) ||
            i.type.labelRu.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    // Group incidents logically: Pending (urgent) vs History
    final pending = filteredIncidents.where((i) => !i.processed).toList();
    final processed = filteredIncidents.where((i) => i.processed).toList();

    return Column(
      children: [
        // Harmonized Filter Chips Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Все'),
                selected: _selectedTypeFilter == null && !_onlyUnprocessed,
                onSelected: (_) {
                  setState(() {
                    _selectedTypeFilter = null;
                    _onlyUnprocessed = false;
                  });
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Новые'),
                    if (state.unprocessedIncidentsCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${state.unprocessedIncidentsCount}',
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                selected: _onlyUnprocessed,
                onSelected: (val) {
                  setState(() {
                    _onlyUnprocessed = val;
                  });
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Безопасность'),
                selected: _selectedTypeFilter == IncidentType.carOnPlayground,
                onSelected: (val) {
                  setState(() {
                    _selectedTypeFilter =
                        val ? IncidentType.carOnPlayground : null;
                  });
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Незнакомцы'),
                selected: _selectedTypeFilter == IncidentType.strangerDetected,
                onSelected: (val) {
                  setState(() {
                    _selectedTypeFilter =
                        val ? IncidentType.strangerDetected : null;
                  });
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Доступ'),
                selected: _selectedTypeFilter == IncidentType.doorOpened,
                onSelected: (val) {
                  setState(() {
                    _selectedTypeFilter =
                        val ? IncidentType.doorOpened : null;
                  });
                },
              ),
            ],
          ),
        ),

        // Logs List with Grouping and Bottom System Padding
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => state.refreshAll(),
            child: filteredIncidents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_outlined,
                            size: 48, color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(
                          'Событий не найдено',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: [
                      if (pending.isNotEmpty) ...[
                        _buildSectionHeader(
                          context,
                          title: 'Требуют внимания',
                          count: pending.length,
                          isWarning: true,
                        ),
                        ...pending.map((i) => _buildIncidentTile(context, i)),
                        const SizedBox(height: 16),
                      ],
                      if (processed.isNotEmpty) ...[
                        if (pending.isNotEmpty)
                          _buildSectionHeader(
                            context,
                            title: 'История событий',
                            count: processed.length,
                            isWarning: false,
                          ),
                        ...processed.map((i) => _buildIncidentTile(context, i)),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    required bool isWarning,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isWarning
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isWarning
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isWarning
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentTile(BuildContext context, Incident incident) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    IconData iconData;
    Color iconBg;
    Color iconFg;

    // Segmented into 3 tonal M3 categories
    switch (incident.type) {
      case IncidentType.carOnPlayground:
        // Category 1: Urgent safety alerts
        iconData = Icons.warning_amber_rounded;
        iconBg = colorScheme.errorContainer;
        iconFg = colorScheme.onErrorContainer;
        break;
      case IncidentType.strangerDetected:
      case IncidentType.doorOpened:
        // Category 2: Access & stranger detection
        iconData = incident.type == IncidentType.strangerDetected
            ? Icons.person_search_outlined
            : Icons.door_sliding_outlined;
        iconBg = colorScheme.secondaryContainer;
        iconFg = colorScheme.onSecondaryContainer;
        break;
      case IncidentType.deliveryArrived:
      case IncidentType.motionDetected:
        // Category 3: General service & routine events
        iconData = incident.type == IncidentType.deliveryArrived
            ? Icons.local_shipping_outlined
            : Icons.notifications_none;
        iconBg = colorScheme.surfaceContainerHighest;
        iconFg = colorScheme.onSurfaceVariant;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        color: incident.processed
            ? colorScheme.surfaceContainerLowest
            : colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: incident.processed
                ? colorScheme.outlineVariant.withValues(alpha: 0.3)
                : colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => IncidentDetailDialog(
                incident: incident,
                state: widget.state,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tonal circle icon matching M3 specs
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: iconFg, size: 20),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              incident.type.labelRu,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatTime(incident.occurredAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        incident.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} мин';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} ч';
    } else {
      return '${dt.day}.${dt.month}';
    }
  }
}
