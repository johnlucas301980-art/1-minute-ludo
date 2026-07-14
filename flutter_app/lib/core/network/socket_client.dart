import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

/// Socket.IO client wrapper for 1 Minute Ludo realtime communication.
///
/// Manages the persistent WebSocket connection to the backend.
/// Use [instance] to access the singleton throughout the app.
class SocketClient {
  SocketClient._();

  static final SocketClient instance = SocketClient._();

  io.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  /// Initialize and connect the socket.
  /// Call this once after the user has authenticated.
  void connect({String? authToken}) {
    if (_socket != null && _socket!.connected) return;

    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setReconnectionDelay(
            AppConfig.socketReconnectDelay.inMilliseconds.toDouble(),
          )
          .setExtraHeaders(
            authToken != null ? {'Authorization': 'Bearer $authToken'} : {},
          )
          .enableReconnection()
          .build(),
    );

    _socket!
      ..onConnect((_) => _log('Connected: ${_socket!.id}'))
      ..onDisconnect((_) => _log('Disconnected'))
      ..onConnectError((err) => _log('Connect error: $err'))
      ..onError((err) => _log('Error: $err'));
  }

  /// Disconnect and clean up the socket.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  /// Emit an event to the server.
  void emit(String event, [dynamic data]) {
    assert(_socket != null, 'Call connect() before emitting events.');
    _socket?.emit(event, data);
  }

  /// Register a listener for a server event.
  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  /// Remove a listener for a server event.
  void off(String event, [Function(dynamic)? handler]) {
    _socket?.off(event, handler);
  }

  void _log(String message) {
    // ignore: avoid_print
    print('[SocketClient] $message');
  }
}
