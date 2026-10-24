import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Implemented by repositories that can expose the live backend alert stream.
///
/// Kept separate from [OperatorRepository], so fakes and offline repositories
/// don't have to carry a URL they never use.
abstract interface class AlertStreamSource {
  Uri alertsStreamUri();
}

/// Minimal Server-Sent Events client for the backend alert feed.
///
/// It handles the `event:`/`data:` framing, ignores comment (heartbeat) lines
/// and reconnects automatically when the stream drops. Uses only the already
/// available `http` package, so no extra dependencies are needed.
class AlertStreamService {
  AlertStreamService({
    required this.streamUri,
    http.Client? client,
    this.onAlert,
    this.onStatusChange,
    this.reconnectDelay = const Duration(seconds: 3),
  }) : _client = client ?? http.Client();

  final Uri streamUri;
  final http.Client _client;
  final void Function(Map<String, dynamic> alert)? onAlert;
  final void Function(bool connected)? onStatusChange;
  final Duration reconnectDelay;

  bool _running = false;
  bool _connected = false;
  Timer? _reconnectTimer;
  String? _eventName;
  final List<String> _dataLines = [];

  bool get running => _running;
  bool get connected => _connected;

  void start() {
    if (_running) return;
    _running = true;
    _connect();
  }

  /// Stops listening and closes the connection without further reconnects.
  Future<void> dispose() async {
    _running = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _setStatus(false);
    _client.close();
  }

  Future<void> _connect() async {
    if (!_running) return;
    try {
      final request = http.Request('GET', streamUri)
        ..headers['Accept'] = 'text/event-stream';
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        _scheduleReconnect();
        return;
      }
      _setStatus(true);
      _listen(response);
    } on Exception {
      _setStatus(false);
      _scheduleReconnect();
    }
  }

  Future<void> _listen(http.StreamedResponse response) async {
    try {
      await for (final line in response.stream
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())) {
        if (!_running) return;
        _handleLine(line);
      }
    } on Exception {
      // The connection dropped — fall through to the reconnect path.
    }
    if (_running) {
      _setStatus(false);
      _scheduleReconnect();
    }
  }

  void _handleLine(String line) {
    if (line.isEmpty) {
      _dispatch();
      return;
    }
    if (line.startsWith(':')) {
      return; // comment/heartbeat
    }
    if (line.startsWith('event:')) {
      _eventName = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      _dataLines.add(line.substring(5).trim());
    }
  }

  void _dispatch() {
    final name = _eventName;
    final data = _dataLines.join('\n').trim();
    _eventName = null;
    _dataLines.clear();
    if (name != 'alert' || data.isEmpty) return;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        onAlert?.call(decoded);
      }
    } on FormatException {
      // Ignore malformed payloads: a hurting feed must not break the console.
    }
  }

  void _scheduleReconnect() {
    if (!_running || _reconnectTimer != null) return;
    _reconnectTimer = Timer(reconnectDelay, () {
      _reconnectTimer = null;
      _connect();
    });
  }

  void _setStatus(bool connected) {
    if (_connected == connected) return;
    _connected = connected;
    onStatusChange?.call(connected);
  }
}
