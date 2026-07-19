import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/app_config.dart';

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

/// Thrown when the Socket.IO connection is rejected by the server —
/// typically because the JWT is absent, expired, or invalid.
class SocketConnectionException implements Exception {
  const SocketConnectionException(this.message);
  final String message;

  @override
  String toString() => 'SocketConnectionException: $message';
}

// ---------------------------------------------------------------------------
// SocketClient
// ---------------------------------------------------------------------------

/// A thin, injectable wrapper around [socket_io_client].
///
/// Responsibilities:
///  - Fetch the JWT from the injected [tokenProvider] at connect time.
///  - Connect to the backend with `{ auth: { token } }` in the handshake.
///  - Expose [emit], [on], [off] so callers never touch the raw socket.
///  - Throw [SocketConnectionException] when the server rejects the
///    connection (e.g. expired JWT → "unauthorized" error).
///
/// Design for testability:
///   All methods are non-final (overridable). Tests create a subclass
///   (`_FakeSocketClient`) that overrides [connect], [disconnect], [emit],
///   [on], and [off] without touching any platform channel.
///
/// Usage (production):
/// ```dart
/// final client = SocketClient(
///   tokenProvider: () => tokenStorage.getAccessToken(),
/// );
/// await client.connect();
/// client.on('match_found', (data) { ... });
/// client.emit('find_match');
/// client.dispose();
/// ```
class SocketClient {
  SocketClient({required Future<String?> Function() tokenProvider})
      : _tokenProvider = tokenProvider;

  final Future<String?> Function() _tokenProvider;

  io.Socket? _socket;

  /// Whether the underlying socket is currently connected.
  bool get isConnected => _socket?.connected ?? false;

  // ── Connection ─────────────────────────────────────────────────────────────

  /// Connect to the Socket.IO server.
  ///
  /// Fetches the current JWT via [tokenProvider]. If the token is absent,
  /// throws [SocketConnectionException] immediately without opening a socket.
  ///
  /// If the server rejects the connection (e.g. expired token), the server
  /// emits a `connect_error` event. This method wraps that in
  /// [SocketConnectionException] so callers see a typed Dart exception.
  ///
  /// Calling [connect] when already connected is a no-op.
  Future<void> connect() async {
    if (_socket != null && (_socket!.connected)) return;

    final token = await _tokenProvider();
    if (token == null) {
      throw const SocketConnectionException('No access token available.');
    }

    final completer = Completer<void>();

    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['polling', 'websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    void onConnect(_) {
      if (!completer.isCompleted) completer.complete();
    }

    void onConnectError(dynamic err) {
      if (!completer.isCompleted) {
        completer.completeError(
          SocketConnectionException(err?.toString() ?? 'Connection failed'),
        );
      }
    }

    _socket!.once('connect', onConnect);
    _socket!.once('connect_error', onConnectError);
    _socket!.connect();

    return completer.future;
  }

  /// Disconnect the socket and release the underlying resource.
  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  // ── Event I/O ──────────────────────────────────────────────────────────────

  /// Emit [event] to the server with an optional [data] payload.
  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  /// Register [handler] for incoming [event].
  /// Calling [on] multiple times with the same event is safe — socket.io
  /// queues additional listeners.
  void on(String event, void Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  /// Remove all listeners for [event].
  void off(String event) {
    _socket?.off(event);
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Disconnect and release all resources. Safe to call multiple times.
  void dispose() {
    disconnect();
  }
}
