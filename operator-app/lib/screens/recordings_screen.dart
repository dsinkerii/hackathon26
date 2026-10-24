import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/camera.dart';
import '../models/video_recording.dart';
import '../services/admin_repository.dart';
import '../widgets/adaptivity.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({
    super.key,
    required this.repository,
    required this.isAdmin,
  });

  final AdminRepository repository;
  final bool isAdmin;

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  late Future<List<Camera>> _cameras;
  Future<List<VideoRecording>>? _recordings;
  DateTimeRange? _selectedRange;
  String? _cameraId;
  bool _withoutCamera = false;

  @override
  void initState() {
    super.initState();
    _cameras = widget.repository.fetchCameras();
    _loadRecordings();
  }

  DateTime? get _from => _selectedRange == null
      ? null
      : DateTime(
          _selectedRange!.start.year,
          _selectedRange!.start.month,
          _selectedRange!.start.day,
        );

  DateTime? get _to => _selectedRange == null
      ? null
      : DateTime(
          _selectedRange!.end.year,
          _selectedRange!.end.month,
          _selectedRange!.end.day + 1,
        );

  void _loadRecordings() {
    _recordings = widget.repository.fetchRecordings(
      cameraId: _withoutCamera ? null : _cameraId,
      withoutCamera: _withoutCamera ? true : null,
      from: _from,
      to: _to,
    );
  }

  void _refresh() => setState(() {
        _cameras = widget.repository.fetchCameras();
        _loadRecordings();
      });

  Future<void> _selectRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      initialDateRange: _selectedRange ??
          DateTimeRange(
              start: DateTime(now.year, now.month, now.day), end: now),
    );
    if (range != null && mounted) {
      setState(() {
        _selectedRange = range;
        _loadRecordings();
      });
    }
  }

  Future<void> _editRecording(
    List<Camera> cameras, [
    VideoRecording? recording,
  ]) async {
    final input = await showDialog<_RecordingInput>(
      context: context,
      builder: (_) => _RecordingEditor(cameras: cameras, recording: recording),
    );
    if (input == null) return;
    try {
      if (recording == null) {
        await widget.repository.createRecording(
          cameraId: input.cameraId,
          title: input.title,
          eventType: input.eventType,
          recordedAt: input.recordedAt,
          durationSeconds: input.durationSeconds,
          videoUrl: input.videoUrl,
        );
      } else {
        await widget.repository.updateRecording(
          recording.id,
          cameraId: input.cameraId,
          title: input.title,
          eventType: input.eventType,
          recordedAt: input.recordedAt,
          durationSeconds: input.durationSeconds,
          videoUrl: input.videoUrl,
        );
      }
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) _message('Не удалось сохранить запись: $error');
    }
  }

  Future<void> _deleteRecording(VideoRecording recording) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить запись из каталога?'),
        content: Text(
            'Удалить метаданные «${recording.title}»? Сам видеофайл этим действием не удаляется.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (delete != true) return;
    try {
      await widget.repository.deleteRecording(recording.id);
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) _message('Не удалось удалить запись: $error');
    }
  }

  Future<void> _play(VideoRecording recording) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _RecordingPlayer(recording: recording),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Видеоархив',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    const Text(
                        'Каталог записей: фильтр по камере и периоду'),
                  ],
                ),
              ),
              if (widget.isAdmin)
                FilledButton.icon(
                  onPressed: () async {
                    final cameras = await _cameras;
                    if (mounted) _editRecording(cameras);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить запись'),
                ),
              IconButton(
                onPressed: _refresh,
                tooltip: 'Обновить',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Camera>>(
            future: _cameras,
            builder: (context, cameraSnapshot) {
              if (cameraSnapshot.hasError) {
                return _LoadError(
                  message: cameraSnapshot.error.toString(),
                  onRetry: _refresh,
                );
              }
              if (!cameraSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final cameras = cameraSnapshot.data!;
              final cameraOptions = cameras
                  .map(
                    (camera) => DropdownMenuItem(
                      value: camera.id,
                      child: Text(camera.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String>(
                          initialValue: _cameraId ?? '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Камера',
                            prefixIcon: Icon(Icons.camera_alt_outlined),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('Все камеры'),
                            ),
                            ...cameraOptions.map(
                              (item) => DropdownMenuItem<String>(
                                value: item.value,
                                child: item.child,
                              ),
                            ),
                          ],
                          onChanged: (id) => setState(() {
                            _withoutCamera = false;
                            _cameraId = id == null || id.isEmpty ? null : id;
                            _loadRecordings();
                          }),
                        ),
                      ),
                      if (widget.isAdmin)
                        FilterChip(
                          label: const Text('Без камеры'),
                          selected: _withoutCamera,
                          tooltip:
                              'Записи без привязки к камере (видны только администраторам)',
                          onSelected: (selected) => setState(() {
                            _withoutCamera = selected;
                            if (selected) _cameraId = null;
                            _loadRecordings();
                          }),
                        ),
                      OutlinedButton.icon(
                        onPressed: _selectRange,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(_rangeLabel),
                      ),
                      if (_cameraId != null ||
                          _selectedRange != null ||
                          _withoutCamera)
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _cameraId = null;
                            _selectedRange = null;
                            _withoutCamera = false;
                            _loadRecordings();
                          }),
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: const Text('Сбросить'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<VideoRecording>>(
                    future: _recordings,
                    builder: (context, recordingSnapshot) {
                      if (recordingSnapshot.hasError) {
                        return _LoadError(
                          message: recordingSnapshot.error.toString(),
                          onRetry: _refresh,
                        );
                      }
                      if (!recordingSnapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final recordings = recordingSnapshot.data!;
                      if (recordings.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Center(
                              child: Text(cameras.isEmpty
                                  ? 'Записей пока нет — добавьте камеры или зарегистрируйте запись без камеры.'
                                  : 'За выбранный период записей нет.'),
                            ),
                          ),
                        );
                      }
                      return Card(
                        child: Column(
                          children: [
                            for (final recording in recordings)
                              _RecordingTile(
                                recording: recording,
                                isAdmin: widget.isAdmin,
                                onPlay: () => _play(recording),
                                onEdit: () =>
                                    _editRecording(cameras, recording),
                                onDelete: () => _deleteRecording(recording),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Архив содержит ссылки на видеофайлы видеосервиса. '
                    'Удаление записи из каталога не стирает сам файл.',
                  ),
                ],
              );
            },
          ),
        ],
      );

  String get _rangeLabel {
    if (_selectedRange == null) return 'Весь период';
    return '${_formatDate(_selectedRange!.start)} — '
        '${_formatDate(_selectedRange!.end)}';
  }

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';
}

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({
    required this.recording,
    required this.isAdmin,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
  });

  final VideoRecording recording;
  final bool isAdmin;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = recording.recordedAt.toLocal();
    final timestamp = '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.play_circle_outline)),
      title: Text(recording.title),
      subtitle: Text(
        '$timestamp · ${recording.cameraName ?? 'Без камеры'}'
        '${recording.eventType == null ? '' : ' · ${recording.eventType}'}',
      ),
      isThreeLine: recording.eventType != null,
      onTap: onPlay,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onPlay,
            tooltip: 'Воспроизвести',
            icon: const Icon(Icons.play_arrow),
          ),
          if (isAdmin)
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') onEdit();
                if (action == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Изменить')),
                PopupMenuItem(
                    value: 'delete', child: Text('Удалить из каталога')),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecordingInput {
  const _RecordingInput({
    this.cameraId,
    required this.title,
    required this.eventType,
    required this.recordedAt,
    required this.durationSeconds,
    required this.videoUrl,
  });

  final String? cameraId;
  final String title;
  final String? eventType;
  final DateTime recordedAt;
  final int? durationSeconds;
  final String videoUrl;
}

class _RecordingEditor extends StatefulWidget {
  const _RecordingEditor({required this.cameras, this.recording});
  final List<Camera> cameras;
  final VideoRecording? recording;

  @override
  State<_RecordingEditor> createState() => _RecordingEditorState();
}

class _RecordingEditorState extends State<_RecordingEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _eventType;
  late final TextEditingController _videoUrl;
  late String _cameraId;
  late DateTime _recordedAt;

  @override
  void initState() {
    super.initState();
    final recording = widget.recording;
    _cameraId = recording?.cameraId ?? '';
    _recordedAt = recording?.recordedAt.toLocal() ?? DateTime.now();
    _title = TextEditingController(text: recording?.title ?? '');
    _eventType = TextEditingController(text: recording?.eventType ?? '');
    _videoUrl = TextEditingController(text: recording?.videoUrl ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _eventType.dispose();
    _videoUrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime(_recordedAt.year - 10),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
    );
    if (time != null && mounted) {
      setState(() => _recordedAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          ));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
            widget.recording == null ? 'Добавить запись' : 'Изменить запись'),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: adaptiveWidth(context, 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _cameraId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Камера'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Без камеры'),
                      ),
                      ...widget.cameras
                          .map((camera) => DropdownMenuItem(
                                value: camera.id,
                                child: Text(camera.name),
                              )),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _cameraId = value);
                    },
                  ),
                  TextFormField(
                    controller: _title,
                    decoration:
                        const InputDecoration(labelText: 'Название записи'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Укажите название'
                        : null,
                  ),
                  TextFormField(
                    controller: _eventType,
                    decoration: const InputDecoration(
                        labelText: 'Тип события (необязательно)'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Дата и время'),
                    subtitle: Text(_recordedAt.toString()),
                    trailing: IconButton(
                      onPressed: _pickDateTime,
                      tooltip: 'Выбрать дату',
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                  TextFormField(
                    controller: _videoUrl,
                    decoration: const InputDecoration(
                      labelText: 'Ссылка на видео',
                      hintText: 'https://archive.example/video.mp4',
                    ),
                    validator: (value) {
                      final uri = Uri.tryParse(value ?? '');
                      return uri == null ||
                              !uri.hasAuthority ||
                              !const {'http', 'https'}.contains(uri.scheme)
                          ? 'Укажите абсолютный URL HTTP или HTTPS'
                          : null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                _RecordingInput(
                  cameraId: _cameraId.isEmpty ? null : _cameraId,
                  title: _title.text.trim(),
                  eventType: _eventType.text.trim().isEmpty
                      ? null
                      : _eventType.text.trim(),
                  recordedAt: _recordedAt,
                  // Длительность не спрашиваем: при изменении существующей
                  // записи она сохраняется, новая запись хранится без неё.
                  durationSeconds: widget.recording?.durationSeconds,
                  videoUrl: _videoUrl.text.trim(),
                ),
              );
            },
            child: const Text('Сохранить'),
          ),
        ],
      );
}

class _RecordingPlayer extends StatefulWidget {
  const _RecordingPlayer({required this.recording});
  final VideoRecording recording;

  @override
  State<_RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends State<_RecordingPlayer> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialized;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.recording.videoUrl));
    _initialized = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.recording.title),
        content: SizedBox(
          width: adaptiveWidth(context, 720),
          child: FutureBuilder<void>(
            future: _initialized,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Не удалось открыть видео: ${snapshot.error}');
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    VideoProgressIndicator(_controller, allowScrubbing: true),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() {
              _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play();
            }),
            icon: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
            label:
                Text(_controller.value.isPlaying ? 'Пауза' : 'Воспроизвести'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: const Text('Не удалось загрузить записи'),
          subtitle: Text(message),
          trailing: IconButton(
            onPressed: onRetry,
            tooltip: 'Повторить',
            icon: const Icon(Icons.refresh),
          ),
        ),
      );
}
