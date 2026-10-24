import 'package:flutter/material.dart';

import '../models/camera.dart';
import '../services/admin_repository.dart';
import '../widgets/adaptivity.dart';

class CamerasScreen extends StatefulWidget {
  const CamerasScreen({
    super.key,
    required this.repository,
    required this.isAdmin,
  });

  final AdminRepository repository;
  final bool isAdmin;

  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  late Future<List<Camera>> _cameras;

  @override
  void initState() {
    super.initState();
    _cameras = widget.repository.fetchCameras();
  }

  void _reload() => setState(() {
        _cameras = widget.repository.fetchCameras();
      });

  Future<void> _editCamera([Camera? camera]) async {
    final input = await showDialog<_CameraInput>(
      context: context,
      builder: (_) => _CameraEditor(camera: camera),
    );
    if (input == null) return;
    try {
      if (camera == null) {
        await widget.repository.createCamera(
          name: input.name,
          location: input.location,
          streamUrl: input.streamUrl,
        );
      } else {
        await widget.repository.updateCamera(
          camera.id,
          name: input.name,
          location: input.location,
          streamUrl: input.streamUrl,
          enabled: input.enabled,
        );
      }
      if (mounted) _reload();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _deleteCamera(Camera camera) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить камеру?'),
        content: Text(
            'Удалить «${camera.name}»? Камеру с архивными записями удалить нельзя.'),
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
    if (confirmed != true) return;
    try {
      await widget.repository.deleteCamera(camera.id);
      if (mounted) _reload();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Операция не выполнена: $error')),
    );
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
                    Text('Камеры',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    const Text('Каталог камер и адресов видеопотоков'),
                  ],
                ),
              ),
              if (widget.isAdmin)
                FilledButton.icon(
                  onPressed: _editCamera,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить камеру'),
                ),
              IconButton(
                tooltip: 'Обновить',
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Camera>>(
            future: _cameras,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('Не удалось загрузить камеры'),
                    subtitle: Text(snapshot.error.toString()),
                    trailing: IconButton(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final cameras = snapshot.data!;
              if (cameras.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                      child: Text(
                          'Камер пока нет. Добавьте камеру для привязки архива.'),
                    ),
                  ),
                );
              }
              final cameraCardWidth = adaptiveWidth(context, 360);
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final camera in cameras)
                    SizedBox(
                      width: cameraCardWidth,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.videocam_outlined),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(camera.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                  ),
                                  if (widget.isAdmin)
                                    PopupMenuButton<String>(
                                      onSelected: (action) {
                                        if (action == 'edit') {
                                          _editCamera(camera);
                                        }
                                        if (action == 'delete') {
                                          _deleteCamera(camera);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Изменить'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Удалить'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              Text(camera.location ?? 'Место не указано'),
                              const SizedBox(height: 10),
                              Chip(
                                avatar: Icon(
                                  camera.enabled
                                      ? Icons.check_circle_outline
                                      : Icons.pause_circle_outline,
                                  size: 18,
                                ),
                                label: Text(
                                    camera.enabled ? 'Активна' : 'Отключена'),
                                visualDensity: VisualDensity.compact,
                              ),
                              if (camera.streamUrl != null)
                                SelectableText(
                                  camera.streamUrl!,
                                  maxLines: 1,
                                  style: Theme.of(context).textTheme.bodySmall,
                                )
                              else
                                Text(
                                  'Видеопоток не настроен',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Каталог хранит метаданные и URL потока. Сам поток и видеоархив '
            'должны предоставляться камерой или подключённым видеосервисом.',
          ),
        ],
      );
}

class _CameraInput {
  const _CameraInput(this.name, this.location, this.streamUrl, this.enabled);
  final String name;
  final String? location;
  final String? streamUrl;
  final bool enabled;
}

class _CameraEditor extends StatefulWidget {
  const _CameraEditor({this.camera});
  final Camera? camera;

  @override
  State<_CameraEditor> createState() => _CameraEditorState();
}

class _CameraEditorState extends State<_CameraEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _streamUrl;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.camera?.name ?? '');
    _location = TextEditingController(text: widget.camera?.location ?? '');
    _streamUrl = TextEditingController(text: widget.camera?.streamUrl ?? '');
    _enabled = widget.camera?.enabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _streamUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title:
            Text(widget.camera == null ? 'Добавить камеру' : 'Изменить камеру'),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: adaptiveWidth(context, 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Название'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Укажите название'
                      : null,
                ),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(labelText: 'Расположение'),
                ),
                TextFormField(
                  controller: _streamUrl,
                  decoration: const InputDecoration(
                    labelText: 'URL видеопотока (необязательно)',
                    hintText: 'https://camera.example/stream',
                  ),
                  validator: (value) => value != null &&
                          value.isNotEmpty &&
                          !(Uri.tryParse(value)?.hasAuthority == true &&
                              const {'http', 'https'}
                                  .contains(Uri.tryParse(value)?.scheme))
                      ? 'Укажите абсолютный URL'
                      : null,
                ),
                if (widget.camera != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _enabled,
                    title: const Text('Камера активна'),
                    onChanged: (enabled) => setState(() => _enabled = enabled),
                  ),
              ],
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
                _CameraInput(
                  _name.text.trim(),
                  _location.text.trim().isEmpty ? null : _location.text.trim(),
                  _streamUrl.text.trim().isEmpty
                      ? null
                      : _streamUrl.text.trim(),
                  _enabled,
                ),
              );
            },
            child: const Text('Сохранить'),
          ),
        ],
      );
}
