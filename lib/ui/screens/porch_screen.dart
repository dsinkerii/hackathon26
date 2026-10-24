import 'package:flutter/material.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import '../../models/incident_model.dart';
import '../../state/app_state.dart';
import '../widgets/incident_dialog.dart';
import 'camera_view_screen.dart';

class PorchScreen extends StatefulWidget {
  final AppState state;

  const PorchScreen({super.key, required this.state});

  @override
  State<PorchScreen> createState() => _PorchScreenState();
}

class _PorchScreenState extends State<PorchScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _doorOpening = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerOpenDoor() async {
    if (_doorOpening) return;
    setState(() => _doorOpening = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _doorOpening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: const Text('Дверь подъезда открыта'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = widget.state;

    final unreadIncidents =
        state.incidents.where((i) => !i.processed).take(3).toList();

    return RefreshIndicator(
      onRefresh: () => state.refreshAll(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Camera Card
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CameraViewScreen(state: state),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Camera Stream Preview
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Hero(
                            tag: 'camera_preview_main',
                            child: Image.asset(
                              'assets/images/porch_camera.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: Center(
                                  child: Icon(
                                    Icons.videocam_outlined,
                                    size: 48,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Gradient overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.25),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Play icon
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: colorScheme.primary,
                              size: 36,
                            ),
                          ),
                        ),
                      ),

                      // Animated Live Badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FadeTransition(
                                opacity: _pulseAnimation,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Card Body
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.settings.address,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Подъезд №1 • Видеонаблюдение онлайн',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick Action Cards
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 0,
                  color: colorScheme.secondaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _triggerOpenDoor,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      child: Column(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _doorOpening
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: colorScheme.onSecondaryContainer,
                                    ),
                                  )
                                : Icon(
                                    Icons.lock_open_rounded,
                                    color: colorScheme.onSecondaryContainer,
                                    size: 26,
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _doorOpening ? 'Открываем...' : 'Открыть дверь',
                            style: TextStyle(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CameraViewScreen(state: state),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.fullscreen_rounded,
                            color: colorScheme.onSurface,
                            size: 26,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Развернуть',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Unread Activity Notifications Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Новые события',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (state.unprocessedIncidentsCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
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
              TextButton(
                onPressed: () => state.selectTab(2),
                child: const Text('Все события'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Unread Notifications Column (up to 3 with quick icon-only actions)
          if (unreadIncidents.isEmpty)
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Все спокойно. Новых инцидентов нет.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...unreadIncidents.map(
              (incident) => _buildUnreadIncidentCard(context, incident),
            ),
        ],
      ),
    );
  }

  Widget _buildUnreadIncidentCard(BuildContext context, Incident incident) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = widget.state;
    final isStranger = incident.type == IncidentType.strangerDetected;

    IconData iconData = Icons.warning_amber_rounded;
    Color iconBg = colorScheme.errorContainer;
    Color iconFg = colorScheme.onErrorContainer;
    Shapes m3Shape = Shapes.gem;

    if (incident.type == IncidentType.strangerDetected) {
      iconData = Icons.person_search_outlined;
      iconBg = colorScheme.tertiaryContainer;
      iconFg = colorScheme.onTertiaryContainer;
      m3Shape = Shapes.slanted;
    } else if (incident.type == IncidentType.doorOpened) {
      iconData = Icons.door_sliding_outlined;
      iconBg = colorScheme.secondaryContainer;
      iconFg = colorScheme.onSecondaryContainer;
      m3Shape = Shapes.arch;
    } else if (incident.type == IncidentType.deliveryArrived) {
      iconData = Icons.local_shipping_outlined;
      iconBg = colorScheme.surfaceContainerHighest;
      iconFg = colorScheme.onSurfaceVariant;
      m3Shape = Shapes.square;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => IncidentDetailDialog(
                incident: incident,
                state: state,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // M3 Expressive Shape Icon
                M3Container(
                  m3Shape,
                  width: 38,
                  height: 38,
                  color: iconBg,
                  child: Center(
                    child: Icon(iconData, color: iconFg, size: 19),
                  ),
                ),
                const SizedBox(width: 12),

                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incident.type.labelRu,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        incident.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Easy Access Icon Buttons (No labels)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Action 1: Dismiss / Reject
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 19),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Отклонить',
                      onPressed: () {
                        state.acknowledgeIncident(incident.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Событие скрыто'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),

                    // Action 2: Allow once / Confirm
                    IconButton.filledTonal(
                      icon: const Icon(Icons.check_rounded, size: 19),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Разрешить один раз',
                      onPressed: () {
                        state.acknowledgeIncident(incident.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Событие подтверждено'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),

                    // Action 3: Allow forever (for stranger) or View details
                    if (isStranger && incident.stranger != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: IconButton.filled(
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Разрешить навсегда (в белый список)',
                          onPressed: () {
                            state.approveStranger(incident.stranger!.id, 'Сосед');
                            state.acknowledgeIncident(incident.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Добавлен в белый список'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: IconButton.outlined(
                          icon: const Icon(Icons.info_outline_rounded, size: 17),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Подробнее',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => IncidentDetailDialog(
                                incident: incident,
                                state: state,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
