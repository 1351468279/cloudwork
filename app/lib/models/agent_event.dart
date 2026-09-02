class ToolCallPayload {
  final String toolId;
  final String toolName;
  final String command;
  final String? filePath;
  final String description;
  final String? diff;

  ToolCallPayload({
    required this.toolId,
    required this.toolName,
    required this.command,
    this.filePath,
    required this.description,
    this.diff,
  });

  factory ToolCallPayload.fromJson(Map<String, dynamic> json) {
    return ToolCallPayload(
      toolId: json['tool_id'] ?? '',
      toolName: json['tool_name'] ?? 'Command',
      command: json['command'] ?? '',
      filePath: json['file_path'],
      description: json['description'] ?? '',
      diff: json['diff'],
    );
  }
}

class AgentEvent {
  final String sessionId;
  final String agentType;
  final String type; // "status_change", "tool_call_request", "file_diff", "std_output", "session_finished"
  final String status;
  final String? message;
  final ToolCallPayload? toolCall;
  final String? rawOutput;
  final int timestamp;

  AgentEvent({
    required this.sessionId,
    required this.agentType,
    required this.type,
    required this.status,
    this.message,
    this.toolCall,
    this.rawOutput,
    required this.timestamp,
  });

  factory AgentEvent.fromJson(Map<String, dynamic> json) {
    return AgentEvent(
      sessionId: json['session_id'] ?? '',
      agentType: json['agent_type'] ?? 'generic',
      type: json['type'] ?? 'std_output',
      status: json['status'] ?? 'thinking',
      message: json['message'],
      toolCall: json['tool_call'] != null
          ? ToolCallPayload.fromJson(json['tool_call'])
          : null,
      rawOutput: json['raw_output'],
      timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }
}
