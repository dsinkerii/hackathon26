import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import 'camera_view_screen.dart';

class PorchScreen extends StatelessWidget {
  final AppState state;

  const PorchScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: () => state.refreshAll(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Camera Elevated Card matching Penpot MainScreen exactly
          Card(
            elevation: 1,
            color: colorScheme.surfaceContainerLow,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
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
                  // Image Placeholder with Play Circle Overlay
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.asset(
                            'assets/images/porch_camera.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: const Center(
                                child: Icon(Icons.videocam, size: 48),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Play Circle Button from Penpot
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'LIVE',
                            style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Content Container from Penpot
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.settings.address,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ваш подъезд в реальном времени',
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
        ],
      ),
    );
  }
}
