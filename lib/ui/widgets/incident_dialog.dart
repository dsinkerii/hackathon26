import 'package:flutter/material.dart';
import '../../models/incident_model.dart';
import '../../state/app_state.dart';

class IncidentDetailDialog extends StatelessWidget {
  final Incident incident;
  final AppState state;

  const IncidentDetailDialog({
    super.key,
    required this.incident,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isCar = incident.type == IncidentType.carOnPlayground;
    final isStranger = incident.type == IncidentType.strangerDetected;

    IconData dialogIcon = Icons.info_outline;
    Color iconColor = colorScheme.primary;

    if (isCar) {
      dialogIcon = Icons.warning_amber_rounded;
      iconColor = colorScheme.error;
    } else if (isStranger) {
      dialogIcon = Icons.person_search_outlined;
      iconColor = Colors.orange;
    } else if (incident.type == IncidentType.doorOpened) {
      dialogIcon = Icons.door_sliding_outlined;
      iconColor = Colors.blue;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon + Title matching Penpot Simple Dialog
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(dialogIcon, size: 36, color: iconColor),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              incident.type.labelRu,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              incident.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            if (incident.snapshotUrl != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  incident.snapshotUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: Icon(Icons.image_not_supported,
                          color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildMetaRow(
                    context,
                    label: 'Время:',
                    value: _formatDate(incident.occurredAt),
                  ),
                  if (incident.confidence != null) ...[
                    const SizedBox(height: 6),
                    _buildMetaRow(
                      context,
                      label: 'Уверенность ИИ:',
                      value: '${(incident.confidence! * 100).toInt()}%',
                    ),
                  ],
                  if (incident.stranger != null) ...[
                    const SizedBox(height: 6),
                    _buildMetaRow(
                      context,
                      label: 'Посещений:',
                      value: '${incident.stranger!.visitCount} раза',
                    ),
                  ],
                  const SizedBox(height: 6),
                  _buildMetaRow(
                    context,
                    label: 'Статус:',
                    value: incident.processed ? 'Обработано' : 'Требует внимания',
                    valueColor: incident.processed ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Actions matching Penpot Text Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'),
                ),
                const SizedBox(width: 8),
                if (isStranger && !incident.processed)
                  FilledButton.tonal(
                    onPressed: () {
                      state.approveStranger(incident.stranger!.id, 'Сосед');
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Посетитель добавлен в белый список'),
                        ),
                      );
                    },
                    child: const Text('В белый список'),
                  ),
                if (!incident.processed) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      state.acknowledgeIncident(incident.id);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Событие подтверждено и закрыто'),
                        ),
                      );
                    },
                    child: const Text('Принять'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(BuildContext context,
      {required String label, required String value, Color? valueColor}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} мин назад';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} ч назад';
    } else {
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}
