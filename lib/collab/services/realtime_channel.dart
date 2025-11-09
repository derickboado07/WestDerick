import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

abstract class RealTimeChannel {
  Stream<Map<String, dynamic>> get messages;
  Future<void> connect(String url, {required String sessionId});
  Future<void> send(Map<String, dynamic> message);
  Future<void> close();
}

class WebSocketRealTimeChannel implements RealTimeChannel {
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  @override
  Future<void> connect(String url, {required String sessionId}) async {
    await close();
    final uri = Uri.parse(url).replace(queryParameters: {
      ...(Uri.parse(url).queryParameters),
      'sessionId': sessionId,
    });
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen((event) {
      try {
        final data = event is String ? jsonDecode(event) : event as Map<String, dynamic>;
        _controller.add((data as Map).cast<String, dynamic>());
      } catch (_) {}
    }, onError: (_) {
      // no-op
    }, onDone: () {
      // socket closed
    });
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {
    _channel?.sink.add(jsonEncode(message));
  }

  @override
  Future<void> close() async {
    await _channel?.sink.close();
    _channel = null;
  }
}

/// Fallback in-memory channel useful for local/demo without server
class InMemoryRealTimeChannel implements RealTimeChannel {
  static final Map<String, StreamController<Map<String, dynamic>>> _buses = {};
  StreamController<Map<String, dynamic>>? _bus;

  @override
  Stream<Map<String, dynamic>> get messages => _bus!.stream;

  @override
  Future<void> connect(String url, {required String sessionId}) async {
    _bus ??= (_buses[sessionId] ??= StreamController.broadcast());
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {
    _bus?.add(message);
  }

  @override
  Future<void> close() async {
    // do not close shared bus to keep other peers alive
  }
}
