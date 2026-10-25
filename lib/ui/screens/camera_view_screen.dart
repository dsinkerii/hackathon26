import 'dart:async';
import 'package:flutter/material.dart';
import '../../state/app_state.dart';

class CameraViewScreen extends StatefulWidget {
  final AppState state;

  const CameraViewScreen({super.key, required this.state});

  @override
  State<CameraViewScreen> createState() => _CameraViewScreenState();
}

class _CameraViewScreenState extends State<CameraViewScreen>
    with TickerProviderStateMixin {
  late Timer _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Zoom & Pan controller
  late TransformationController _transformationController;

  // Swipe-to-dismiss gesture state & animation
  double _dragOffsetY = 0.0;
  late AnimationController _dismissAnimController;
  Animation<double>? _dragOffsetAnimation;

  DateTime _currentTime = DateTime.now();
  bool _isMicActive = false;
  bool _isDoorOpening = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutCubic,
    );

    _dismissAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    _dismissAnimController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  bool get _isZoomed =>
      _transformationController.value.getMaxScaleOnAxis() > 1.05;

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    setState(() {
      _dragOffsetY += details.delta.dy;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isZoomed) return;

    final velocity = details.primaryVelocity ?? 0.0;
    // Hard swipe or dragged beyond threshold
    if (velocity > 500 || velocity < -500 || _dragOffsetY.abs() > 120) {
      final targetY = _dragOffsetY >= 0
          ? MediaQuery.sizeOf(context).height
          : -MediaQuery.sizeOf(context).height;

      _dragOffsetAnimation = Tween<double>(
        begin: _dragOffsetY,
        end: targetY,
      ).animate(
        CurvedAnimation(
          parent: _dismissAnimController,
          curve: Curves.easeOutCubic,
        ),
      )..addListener(() {
          setState(() {
            _dragOffsetY = _dragOffsetAnimation!.value;
          });
        });

      _dismissAnimController.forward().then((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } else {
      // Spring back to original position
      _dragOffsetAnimation = Tween<double>(
        begin: _dragOffsetY,
        end: 0.0,
      ).animate(
        CurvedAnimation(
          parent: _dismissAnimController,
          curve: Curves.easeOutCubic,
        ),
      )..addListener(() {
          setState(() {
            _dragOffsetY = _dragOffsetAnimation!.value;
          });
        });

      _dismissAnimController.forward(from: 0.0);
    }
  }

  void _openDoor() async {
    if (_isDoorOpening) return;
    setState(() => _isDoorOpening = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _isDoorOpening = false);
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

    final timeString =
        '${_currentTime.year}-${_currentTime.month.toString().padLeft(2, '0')}-${_currentTime.day.toString().padLeft(2, '0')} '
        '${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}';

    final dragFraction = (_dragOffsetY.abs() / 350.0).clamp(0.0, 1.0);
    final bgAlpha = ((1.0 - dragFraction) * 255).round().clamp(0, 255);
    final scale = (1.0 - (dragFraction * 0.12)).clamp(0.88, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withAlpha(bgAlpha),
      body: GestureDetector(
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Transform.translate(
          offset: Offset(0, _dragOffsetY),
          child: Transform.scale(
            scale: scale,
            child: Column(
              children: [
                // Top App Bar
                AppBar(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: const Text('Камера подъезда №1'),
                  actions: [
                    if (_isZoomed)
                      IconButton(
                        icon: const Icon(Icons.zoom_out_map),
                        tooltip: 'Сбросить зум',
                        onPressed: () {
                          setState(() {
                            _transformationController.value = Matrix4.identity();
                          });
                        },
                      ),
                  ],
                ),

                // Video Player HUD Container with InteractiveViewer Zoom
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 1.0,
                        maxScale: 4.5,
                        clipBehavior: Clip.none,
                        onInteractionEnd: (_) => setState(() {}),
                        child: Hero(
                          tag: 'camera_preview_main',
                          child: Center(
                            child: Image.asset(
                              'assets/images/porch_camera.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Container(
                                color: Colors.grey[900],
                                child: const Center(
                                  child: Icon(
                                    Icons.videocam_off,
                                    color: Colors.white54,
                                    size: 64,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Vignette overlay
                      IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.4),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Stream HUD Overlay (Top)
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                timeString,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Stream Specs Overlay (Bottom)
                      const Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Text(
                          'PlayGuard Cam #1 • Зум двумя пальцами • Свайп вниз для закрытия',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Controls Panel
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Open Door
                            _buildControlButton(
                              context,
                              icon: Icons.lock_open_rounded,
                              label: _isDoorOpening ? 'Открываем...' : 'Открыть',
                              isLoading: _isDoorOpening,
                              onTap: _openDoor,
                            ),

                            // Intercom Microphone
                            _buildControlButton(
                              context,
                              icon: _isMicActive ? Icons.mic : Icons.mic_none_outlined,
                              label: _isMicActive ? 'Говорите...' : 'Связь',
                              isActive: _isMicActive,
                              onTap: () {
                                setState(() {
                                  _isMicActive = !_isMicActive;
                                });
                              },
                            ),

                            // Snapshot
                            _buildControlButton(
                              context,
                              icon: Icons.camera_alt_outlined,
                              label: 'Снимок',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    content: const Text('Кадр сохранен'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.settings.address,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    bool isLoading = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final bg = isActive
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHigh;
    final fg = isActive
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(28),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubicEmphasized,
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.primary,
                      ),
                    )
                  : Icon(icon, color: fg, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
