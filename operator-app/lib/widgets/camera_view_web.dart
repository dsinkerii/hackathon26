import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Renders an MJPEG stream on web.
///
/// Browsers support `multipart/x-mixed-replace` in an `<img>` tag, which is the
/// only way to show a live camera feed without extra JavaScript players.
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
  static int _nextViewId = 0;

  String? _viewType;

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(covariant CameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.fit != widget.fit) {
      _register();
    }
  }

  void _register() {
    final url = widget.url;
    final fit = _cssFit(widget.fit);
    final viewType = 'camera-view-${_nextViewId++}';

    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final image = web.HTMLImageElement()
        ..src = url
        ..setAttribute('alt', 'camera feed');
      image.style
        ..setProperty('width', '100%')
        ..setProperty('height', '100%')
        ..setProperty('object-fit', fit)
        ..setProperty('display', 'block')
        ..setProperty('background-color', '#111114');
      image.onerror = ((web.Event event) {
        widget.onError?.call('Не удалось открыть видеопоток');
      }).toJS;
      return image;
    });

    setState(() => _viewType = viewType);
  }

  String _cssFit(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return 'contain';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.fitWidth:
      case BoxFit.fitHeight:
      case BoxFit.scaleDown:
        return 'contain';
      case BoxFit.none:
        return 'none';
      case BoxFit.cover:
        return 'cover';
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewType = _viewType;
    if (viewType == null) {
      return const SizedBox.expand();
    }
    return ClipRect(
      child: HtmlElementView(viewType: viewType),
    );
  }
}
