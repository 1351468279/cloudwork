import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/agent_event.dart';

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  String? _connectedHost;
  String _activeSessionId = '';
  String _serverWorkingDir = '.';
  List<String> _availableAgents = [];

  bool get isConnected => _isConnected;
  String? get connectedHost => _connectedHost;
  String get activeSessionId => _activeSessionId;
  String get serverWorkingDir => _serverWorkingDir;
  List<String> get availableAgents => _availableAgents;

  final StreamController<AgentEvent> _eventController = StreamController<AgentEvent>.broadcast();
  Stream<AgentEvent> get eventStream => _eventController.stream;

  void connect(String wsUrl) {
    disconnect();
    try {
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);
      _connectedHost = uri.host;
      _isConnected = true;
      notifyListeners();

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onDone: () {
          _isConnected = false;
          notifyListeners();
        },
        onError: (err) {
          _isConnected = false;
          notifyListeners();
        },
      );

      // 请求电脑端当前状态与可用 Agent
      sendAction('get_status', {});
    } catch (e) {
      _isConnected = false;
      notifyListeners();
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    notifyListeners();
  }

  void _handleMessage(dynamic raw) {
    try {
      final Map<String, dynamic> data = jsonDecode(raw.toString());
      final type = data['type'];

      if (type == 'status' && data['action'] == 'get_status') {
        if (data['data'] != null) {
          final d = data['data'];
          _serverWorkingDir = d['working_dir'] ?? '.';
          if (d['available_agents'] is List) {
            _availableAgents = (d['available_agents'] as List).map((e) => e.toString()).toList();
          }
          notifyListeners();
        }
      } else if (type == 'event' && data['data'] != null) {
        final ev = AgentEvent.fromJson(data['data']);
        if (ev.sessionId.isNotEmpty) {
          _activeSessionId = ev.sessionId;
        }
        _eventController.add(ev);
      } else if (type == 'response' && data['action'] == 'start_session') {
        if (data['success'] == true && data['data'] != null) {
          _activeSessionId = data['data']['id'] ?? '';
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error parsing message: $e');
    }
  }

  void startSession(String agentType, String prompt, String workingDir) {
    sendAction('start_session', {
      'agent_type': agentType,
      'prompt': prompt,
      'working_dir': workingDir,
    });
  }

  void approveTool(String sessionId) {
    sendAction('approve', {'session_id': sessionId});
  }

  void rejectTool(String sessionId) {
    sendAction('reject', {'session_id': sessionId});
  }

  void sendAction(String action, Map<String, dynamic> payload) {
    if (_channel == null) return;
    final msg = jsonEncode({
      'action': action,
      'session_id': _activeSessionId,
      'payload': payload,
    });
    _channel!.sink.add(msg);
  }

  @override
  void dispose() {
    _eventController.close();
    disconnect();
    super.dispose();
  }
}
