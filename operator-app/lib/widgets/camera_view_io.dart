import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Plays a camera feed on desktop and mobile.
///
/// `media_kit` (mpv) understands MJPEG-over-HTTP, RTSP and progressive files,
/// so the same widget works for the camera hub and for local clips.
class CameraView extends StatefulWidget {
  const CameraView({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.onError,
  });

  final String url;
  final BoxFit fit;
  final ValueChanged<String>? onError;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  Player? _player;
  VideoController? _controller;
  StreamSubscription<String>? _errors;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant CameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _open();
    }
  }

  void _open() {
    MediaKit.ensureInitialized();

    _errors?.cancel();
    _errors = null;
    final previous = _player;
    _player = null;
    _controller = null;
    previous?.dispose();

    final player = Player(
      configuration: const PlayerConfiguration(
        osc: false,
        muted: true,
        logLevel: MPVLogLevel.error,
        title: 'camera',
      ),
    );
    final controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _player = player;
    _controller = controller;

    _errors = player.stream.error.listen((message) {
      widget.onError?.call(message);
    });

    player.open(Media(widget.url), play: true).catchError((Object error) {
      if (mounted) widget.onError?.call(error.toString());
    });

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _errors?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.expand();
    }
    return Video(
      controller: controller,
      controls: NoVideoControls,
      fit: widget.fit,
      wakelock: true,
    );
  }
}
