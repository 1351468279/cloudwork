import 'package:flutter/material.dart';
import '../models/agent_event.dart';

class ApprovalDialog extends StatelessWidget {
  final AgentEvent event;
  final Function(bool) onDecide;

  const ApprovalDialog({
    super.key,
    required this.event,
    required this.onDecide,
  });

  @override
  Widget build(BuildContext context) {
    final toolCall = event.toolCall;
    return Dialog(
      backgroundColor: const Color(0xFF1C2128),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFD29922), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFD29922), size: 28),
                const SizedBox(width: 8),
                Text(
                  '${event.agentType.toUpperCase()} 权限审批请求',
                  style: const TextStyle(
                    color: Color(0xFFD29922),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event.message ?? 'Agent 正在请求执行以下危险命令，请确认是否允许：',
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(10),
                border: Border.Border.all(color: const Color(0xFF30363D)),
              ),
              child: SelectableText(
                toolCall?.command ?? toolCall?.description ?? '未知操作',
                style: const TextStyle(
                  color: Color(0xFF7EE787),
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDecide(false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF85149),
                      side: const BorderSide(color: Color(0xFFDA3633)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('❌ 拒绝执行', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDecide(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('✅ 允许执行', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
