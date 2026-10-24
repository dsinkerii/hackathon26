import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  static const _demoVideoUrl =
      'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4';

  late final List<_Recording> _recordings;
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    _recordings = [
      _Recording(
        title: 'Тестовая запись',
        cameraName: 'Демонстрационная камера',
        event: 'Проверка видеоплеера',
        recordedAt: DateTime.now().subtract(const Duration(minutes: 20)),
        videoUrl: _demoVideoUrl,
      ),
    ];
  }

  Future<void> _selectRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _selectedRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: now,
          ),
    );
    if (range != null && mounted) {
      setState(() => _selectedRange = range);
    }
  }

  Future<void> _playRecording(_Recording recording) {
    return showDialog<void>(
      context: context,
      builder: (_) => _RecordingPlayerDialog(recording: recording),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleRecordings = _selectedRange == null
        ? _recordings
        : _recordings.where((recording) {
            final start = DateTime(
              _selectedRange!.start.year,
              _selectedRange!.start.month,
              _selectedRange!.start.day,
            );
            final endExclusive = DateTime(
              _selectedRange!.end.year,
              _selectedRange!.end.month,
              _selectedRange!.end.day + 1,
            );
            return !recording.recordedAt.isBefore(start) &&
                recording.recordedAt.isBefore(endExclusive);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Записи видео'),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_selectedRange != null)
            IconButton(
              tooltip: 'Сбросить период',
              onPressed: () => setState(() => _selectedRange = null),
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
          TextButton.icon(
            onPressed: _selectRange,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(_rangeLabel),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: visibleRecordings.isEmpty
              ? const _EmptyRecordings()
              : ListView.separated(
                  itemCount: visibleRecordings.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final recording = visibleRecordings[index];
                    return _RecordingCard(
                      recording: recording,
                      onPlay: () => _playRecording(recording),
                    );
                  },
                ),
        ),
      ),
    );
  }

  String get _rangeLabel {
    final range = _selectedRange;
    if (range == null) return 'Период';
    return '${_formatDate(range.start)} — ${_formatDate(range.end)}';
  }

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}

class _Recording {
  const _Recording({
    required this.title,
    required this.cameraName,
    required this.event,
    required this.recordedAt,
    required this.videoUrl,
  });

  final String title;
  final String cameraName;
  final String event;
  final DateTime recordedAt;
  final String videoUrl;
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({
    required this.recording,
    required this.onPlay,
  });

  final _Recording recording;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final date = recording.recordedAt;
    final time = '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minVerticalPadding: 12,
        leading: const SizedBox(
          width: 64,
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFF17211E)),
            child: Icon(Icons.play_circle_outline, color: Colors.white),
          ),
        ),
        title: Text(recording.title),
        subtitle: Text(
          '$time · ${recording.cameraName}\n${recording.event} · Демо, CC0',
        ),
        isThreeLine: true,
        trailing: IconButton(
          onPressed: onPlay,
          tooltip: 'Воспроизвести запись',
          icon: const Icon(Icons.play_arrow),
        ),
        onTap: onPlay,
      ),
    );
  }
}

class _RecordingPlayerDialog extends StatefulWidget {
  const _RecordingPlayerDialog({required this.recording});

  final _Recording recording;

  @override
  State<_RecordingPlayerDialog> createState() => _RecordingPlayerDialogState();
}

class _RecordingPlayerDialogState extends State<_RecordingPlayerDialog> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialized;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.recording.videoUrl),
    );
    _initialized = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.recording.title),
      content: SizedBox(
        width: 720,
        child: FutureBuilder<void>(
          future: _initialized,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                  'Не удалось загрузить тестовое видео: ${snapshot.error}');
            }
            if (!snapshot.hasData &&
                snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!_controller.value.isInitialized) {
              return const Text('Видеозапись недоступна.');
            }
            return AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
        FilledButton.icon(
          onPressed: _controller.value.isInitialized ? _togglePlayback : null,
          icon: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _controller,
            builder: (context, value, child) => Icon(
              value.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
          ),
          label: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _controller,
            builder: (context, value, child) =>
                Text(value.isPlaying ? 'Пауза' : 'Смотреть'),
          ),
        ),
      ],
    );
  }

  Future<void> _togglePlayback() async {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
    if (mounted) setState(() {});
  }
}

class _EmptyRecordings extends StatelessWidget {
  const _EmptyRecordings();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('За выбранный период записей нет.'),
        ),
      ),
    );
  }
}
