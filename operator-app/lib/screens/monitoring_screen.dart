import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/camera.dart';
import '../models/incident.dart';
import '../services/operator_repository.dart';
import '../widgets/camera_view.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({
    super.key,
    required this.repository,
    this.onOpenRecordings,
  });

  final OperatorRepository repository;
  final VoidCallback? onOpenRecordings;

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  late Future<List<Incident>> _latestIncidents;
  late Future<List<Camera>> _cameras;

  @override
  void initState() {
    super.initState();
    _latestIncidents = widget.repository.fetchIncidents();
    _cameras = widget.repository.fetchCameras();
  }

  void _refresh() {
    setState(() {
      _latestIncidents = widget.repository.fetchIncidents();
      _cameras = widget.repository.fetchCameras();
    });
  }

  Future<void> _openRecordings() {
    if (widget.onOpenRecordings case final callback?) {
      callback();
      return Future<void>.value();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Раздел архива доступен после подключения API.')),
    );
    return Future<void>.value();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final padding = compact ? 12.0 : 20.0;
        final videoPanel = _CameraPanel(
          compact: compact,
          cameras: _cameras,
          onOpenRecordings: _openRecordings,
          onRefresh: _refresh,
        );
        final activityPanel = _ActivityPanel(
          incidents: _latestIncidents,
          onRefresh: _refresh,
        );

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _ServiceStatus(incidents: _latestIncidents),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: compact
                    ? Column(
                        children: [
                          Expanded(flex: 6, child: videoPanel),
                          const SizedBox(height: 10),
                          Expanded(flex: 4, child: activityPanel),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 7, child: videoPanel),
                          const SizedBox(width: 16),
                          SizedBox(width: 320, child: activityPanel),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServiceStatus extends StatelessWidget {
  const _ServiceStatus({required this.incidents});

  final Future<List<Incident>> incidents;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Incident>>(
      future: incidents,
      builder: (context, snapshot) {
        final connected = snapshot.hasData;
        final failed = snapshot.hasError;
        final color = connected
            ? Theme.of(context).colorScheme.primary
            : failed
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.secondary;
        return Chip(
          backgroundColor:
              connected ? const Color(0xFFE7F7ED) : const Color(0xFFF5F5F7),
          side: BorderSide.none,
          avatar: Icon(
            connected
                ? Icons.cloud_done_outlined
                : failed
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_sync_outlined,
            size: 18,
            color: color,
          ),
          label: Text(
            connected
                ? 'Сервис подключён'
                : failed
                    ? 'Сервис не подключён'
                    : 'Подключение...',
          ),
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }
}

class _CameraPanel extends StatefulWidget {
  const _CameraPanel({
    required this.compact,
    required this.cameras,
    required this.onOpenRecordings,
    required this.onRefresh,
  });

  final bool compact;
  final Future<List<Camera>> cameras;
  final VoidCallback onOpenRecordings;
  final VoidCallback onRefresh;

  @override
  State<_CameraPanel> createState() => _CameraPanelState();
}

class _CameraPanelState extends State<_CameraPanel> {
  String? _selectedCameraId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF25252A), Color(0xFF111114)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FutureBuilder<List<Camera>>(
                future: widget.cameras,
                builder: (context, snapshot) {
                  final cameras = snapshot.data ?? const <Camera>[];
                  final streamingCameras = cameras
                      .where((c) =>
                          c.enabled &&
                          c.streamUrl != null &&
                          c.streamUrl!.trim().isNotEmpty)
                      .toList();

                  Camera? activeCamera;
                  if (streamingCameras.isNotEmpty) {
                    activeCamera = streamingCameras.firstWhere(
                      (c) => c.id == _selectedCameraId,
                      orElse: () => streamingCameras.first,
                    );
                  }

                  final streamUrl = activeCamera?.streamUrl?.trim();
                  final hasStream = activeCamera != null &&
                      streamUrl != null &&
                      streamUrl.isNotEmpty;

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: hasStream
                            ? _LiveCameraPlayer(
                                streamUrl: streamUrl,
                                cameraName: activeCamera.name,
                              )
                            : const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Color(0x1FFFFFFF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(18),
                                        child: Icon(
                                          Icons.videocam_off_outlined,
                                          color: Colors.white70,
                                          size: 34,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 14),
                                    Text(
                                      'Видеопоток не подключён',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Добавьте камеру, чтобы начать мониторинг',
                                      style: TextStyle(
                                        color: Color(0xFFB7B7BC),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      Positioned(
                        top: 18,
                        left: 18,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0x66000000),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.videocam_outlined,
                                      size: 15, color: Colors.white70),
                                  SizedBox(width: 6),
                                  Text(
                                    'ОБЗОР КАМЕР',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hasStream) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xCCB00020),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.fiber_manual_record,
                                        size: 10, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      'В ЭФИРЕ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0x66000000),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  activeCamera.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (streamingCameras.length > 1)
                        Positioned(
                          top: 14,
                          right: 18,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0x99000000),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: activeCamera?.id,
                                dropdownColor: const Color(0xFF25252A),
                                icon: const Icon(Icons.arrow_drop_down,
                                    color: Colors.white70),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                                items: [
                                  for (final cam in streamingCameras)
                                    DropdownMenuItem(
                                      value: cam.id,
                                      child: Text(cam.name),
                                    ),
                                ],
                                onChanged: (id) {
                                  if (id != null) {
                                    setState(() => _selectedCameraId = id);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: widget.onOpenRecordings,
            icon: const Icon(Icons.video_library_outlined),
            label: Text(widget.compact ? 'Записи' : 'Записи видео'),
          ),
        ),
      ],
    );
  }
}

/// Live camera panel.
///
/// The camera is served as MJPEG (`http://<host>:8090/stream.mjpg`) by
/// `cv_branch/camera_hub.py`, which also feeds the CV service. Browsers render
/// that in a plain `<img>`; desktop builds use media_kit.
class _LiveCameraPlayer extends StatefulWidget {
  const _LiveCameraPlayer({
    required this.streamUrl,
    required this.cameraName,
  });

  final String streamUrl;
  final String cameraName;

  @override
  State<_LiveCameraPlayer> createState() => _LiveCameraPlayerState();
}

class _LiveCameraPlayerState extends State<_LiveCameraPlayer> {
  String? _error;
  late String _url;

  @override
  void initState() {
    super.initState();
    _validate();
  }

  @override
  void didUpdateWidget(covariant _LiveCameraPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _validate();
    }
  }

  /// `0.0.0.0` is a bind address, not a destination. Browsers allow it in the
  /// address bar but refuse it for subresources such as the MJPEG `<img>`, so
  /// normalise it to loopback instead of failing with a blank player.
  String _normalise(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;
    if (uri.host == '0.0.0.0' || uri.host == '[::]' || uri.host == '::') {
      return uri.replace(host: '127.0.0.1').toString();
    }
    return raw;
  }

  void _validate() {
    final raw = widget.streamUrl.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      setState(() {
        _url = raw;
        _error = 'Некорректный адрес потока: $raw';
      });
      return;
    }
    if (kIsWeb && (uri.scheme == 'rtsp' || uri.scheme == 'rtsps')) {
      setState(() {
        _url = raw;
        _error = 'Браузер не умеет воспроизводить RTSP. '
            'Укажите MJPEG-адрес камеры, например '
            'http://127.0.0.1:8090/stream.mjpg';
      });
      return;
    }
    setState(() {
      _url = _normalise(raw);
      _error = null;
    });
  }

  void _retry() {
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return _PlayerMessage(
        icon: Icons.error_outline,
        title: 'Не удалось запустить видеопоток',
        message: error,
        onRetry: _retry,
      );
    }

    return CameraView(
      key: ValueKey(_url),
      url: _url,
      fit: BoxFit.cover,
      onError: (message) {
        if (!mounted) return;
        setState(() => _error = message);
      },
    );
  }
}

class _PlayerMessage extends StatelessWidget {
  const _PlayerMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.orangeAccent, size: 36),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Повторить'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({
    required this.incidents,
    required this.onRefresh,
  });

  final Future<List<Incident>> incidents;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'События',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Последние инциденты',
                        style: TextStyle(color: Color(0xFF6B6B6F), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Обновить',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Incident>>(
              future: incidents,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Text(
                      'Не удалось загрузить события: ${snapshot.error}',
                      style: const TextStyle(color: Color(0xFF6B6B6F)),
                    ),
                  );
                }
                final items = snapshot.data ?? const <Incident>[];
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Событий пока нет',
                      style: TextStyle(color: Color(0xFF6B6B6F)),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final incident = items[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFF2F2F7),
                        child: Icon(
                          incident.type == 'INTRUSION'
                              ? Icons.warning_amber_rounded
                              : Icons.person_outline,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                      title: Text(incident.description ?? incident.type),
                      subtitle: Text(_formatDateTime(incident.occurredAt)),
                      dense: true,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(time.day)}.${two(time.month)}.${time.year} ${two(time.hour)}:${two(time.minute)}';
  }
}
