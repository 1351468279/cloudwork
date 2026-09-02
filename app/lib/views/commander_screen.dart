import 'package:flutter/material.dart';
import '../models/agent_event.dart';
import 'approval_dialog.dart';

class CommanderScreen extends StatefulWidget {
  const CommanderScreen({super.key});

  @override
  State<CommanderScreen> createState() => _CommanderScreenState();
}

class _CommanderScreenState extends State<CommanderScreen> {
  String _selectedAgent = 'codex';
  final TextEditingController _workingDirCtrl = TextEditingController(text: 'E:\\privateproject\\cloudwork');
  final TextEditingController _promptCtrl = TextEditingController();
  final List<String> _logs = [];
  bool _isConnected = true;
  String _activeStatus = '空闲 (就绪)';

  void _setPrompt(String text) {
    setState(() {
      _promptCtrl.text = text;
    });
  }

  void _dispatchTask() {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _logs.add('>>> 派发任务给 [$_selectedAgent]: $prompt');
      _activeStatus = '正在执行任务...';
      _promptCtrl.clear();
    });

    // 模拟测试：触发一个审批弹窗展示
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ApprovalDialog(
          event: AgentEvent(
            sessionId: 'sess_live_test',
            agentType: _selectedAgent,
            type: 'tool_call_request',
            status: 'awaiting_approval',
            message: 'Agent 请求执行构建与测试命令',
            toolCall: ToolCallPayload(
              toolId: 't1',
              toolName: 'Bash',
              command: 'go test -v ./...',
              description: '运行测试以验证代码稳定性',
            ),
            timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
          onDecide: (allow) {
            setState(() {
              _logs.add(allow ? '>>> [手机审批] ✅ 允许执行测试' : '>>> [手机审批] ❌ 拒绝执行测试');
              _activeStatus = allow ? '执行中 (测试已放行)' : '已中断 (用户拒绝)';
            });
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Row(
          children: [
            const Text('⚡ CloudWork 指挥官', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isConnected ? const Color(0x333FB950) : const Color(0x33F85149),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isConnected ? const Color(0x663FB950) : const Color(0x66F85149)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _isConnected ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isConnected ? '已连电脑' : '断开',
                    style: TextStyle(color: _isConnected ? const Color(0xFF3FB950) : const Color(0xFFF85149), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 任务派发面板
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🚀 派发任务给本地 Agent (零配置)', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedAgent,
                    dropdownColor: const Color(0xFF161B22),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: '目标 Agent',
                      labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                      filled: true,
                      fillColor: const Color(0xFF0D1117),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'codex', child: Text('OpenAI Codex CLI (codex)')),
                      DropdownMenuItem(value: 'claude', child: Text('Anthropic Claude Code (claude)')),
                      DropdownMenuItem(value: 'aider', child: Text('Aider (aider)')),
                      DropdownMenuItem(value: 'generic', child: Text('通用 CLI 工具 (cmd/bash)')),
                    ],
                    onChanged: (val) => setState(() => _selectedAgent = val!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _workingDirCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      labelText: '当前工作区 (Working Directory)',
                      labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                      filled: true,
                      fillColor: const Color(0xFF0D1117),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('常用 Prompt 快捷芯片:', style: TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip('🧪 运行测试', '运行单元测试并修复报错'),
                      _buildChip('📝 编写文档', '为当前模块编写详细的 README'),
                      _buildChip('🔍 审查代码', '审查最近 Git 改动是否存在潜在缺陷'),
                      _buildChip('🧹 精简重构', '重构当前文件并精简冗余代码'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _promptCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '输入要交给 AI Agent 自动执行的编程需求...',
                      hintStyle: const TextStyle(color: Color(0xFF484F58)),
                      filled: true,
                      fillColor: const Color(0xFF0D1117),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _dispatchTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF58A6FF),
                        foregroundColor: const Color(0xFF0D1117),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('🚀 派发至电脑执行', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 2. 状态看板与实时流
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.between,
                    children: [
                      const Text('📡 电脑端实时输出', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(_activeStatus, style: const TextStyle(color: Color(0xFF58A6FF), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 180,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (ctx, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          _logs[i],
                          style: const TextStyle(color: Color(0xFF8B949E), fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, String prompt) {
    return InkWell(
      onTap: () => _setPrompt(prompt),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Text(label, style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 12)),
      ),
    );
  }
}
