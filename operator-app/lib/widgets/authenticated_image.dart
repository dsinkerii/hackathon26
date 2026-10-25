import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';

/// Loads a protected image with the bearer token even on Flutter web.
///
/// `Image.network` accepts headers, but browsers ignore them for <img>
/// elements, so the web build would receive 401 from /media. Fetching the bytes
/// explicitly works on every platform.
class AuthenticatedImage extends StatefulWidget {
  const AuthenticatedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  State<AuthenticatedImage> createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends State<AuthenticatedImage> {
  static final Map<String, Future<Uint8List>> _cache = {};

  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _load(widget.url);
  }

  @override
  void didUpdateWidget(covariant AuthenticatedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytes = _load(widget.url);
    }
  }

  Future<Uint8List> _load(String url) {
    final cached = _cache[url];
    if (cached != null) return cached;
    if (_cache.length > 200) {
      _cache.remove(_cache.keys.first);
    }
    final future = _fetch(url).catchError((Object error, StackTrace stack) {
      // Allow a retry after the backend restarts or the token is refreshed.
      _cache.remove(url);
      Error.throwWithStackTrace(error, stack);
    });
    _cache[url] = future;
    return future;
  }

  Future<Uint8List> _fetch(String url) async {
    final token = AuthService.activeAccessToken;
    final response = await http.get(
      Uri.parse(url),
      headers: token == null ? null : {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(
            bytes,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            gaplessPlayback: true,
          );
        }
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: snapshot.hasError
              ? (widget.errorWidget ?? widget.placeholder)
              : widget.placeholder,
        );
      },
    );
  }
}
