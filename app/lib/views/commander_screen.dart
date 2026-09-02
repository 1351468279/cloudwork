import 'package:flutter/material.dart';
import '../models/agent_event.dart';
import '../models/device_pair.dart';
import '../services/websocket_client.dart';
import 'approval_dialog.dart';
import 'scanner_screen.dart';

class CommanderScreen extends StatefulWidget {
  const CommanderScreen({super.key});

  @override
  State<CommanderScreen> createState() => _CommanderScreenState();
}

class _CommanderScreenState extends State<CommanderScreen> {
  final WebSocketService _wsService = WebSocketService();
  String _selectedAgent = 'codex';
  final TextEditingController _workingDirCtrl = TextEditingController(text: 'E:\\privateproject\\cloudwork');
  final TextEditingController _promptCtrl = TextEditingController();
  final List<String> _logs = [];
  String _activeStatus = '空闲 (未连接电脑)';

  @override
  void initState() {
    super.initState();
    _wsService.addListener(_onWsStateChange);
    _wsService.eventStream.listen(_onAgentEvent);
  }

  @override
  void dispose() {
    _wsService.removeListener(_onWsStateChange);
    _wsService.dispose();
    _workingDirCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  void _onWsStateChange() {
    setState(() {
      if (_wsService.isConnected) {
        _activeStatus = '已连接到 ${_wsService.connectedHost ?? '电脑'}';
      } else {
        _activeStatus = '未连接电脑 (请点击右上角扫码)';
      }
    });
  }

  void _onAgentEvent(AgentEvent ev) {
    setState(() {
      _logs.add('[${ev.agentType}] [${ev.status}] ${ev.message ?? ''}\n${ev.rawOutput ?? ''}');
      _activeStatus = ev.status;
    });

    if (ev.type == 'tool_call_request') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ApprovalDialog(
          event: ev,
          onDecide: (allow) {
            if (allow) {
              _wsService.approveTool(ev.sessionId);
              setState(() => _logs.add('>>> 手机端已批准执行命令 ✅'));
            } else {
              _wsService.rejectTool(ev.sessionId);
              setState(() => _logs.add('>>> 手机端已拒绝执行命令 ❌'));
            }
          },
        ),
      );
    }
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ScannerScreen(
          onPairSuccess: (DevicePair pair) {
            String targetWs = '';
            if (pair.relayUrl.isNotEmpty) {
              targetWs = pair.relayUrl;
            } else if (pair.localIps.isNotEmpty) {
              String bestIp = pair.localIps.first;
              for (final ip in pair.localIps) {
                if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
                  bestIp = ip;
                  break;
                }
              }
              targetWs = 'ws://$bestIp:${pair.port}/ws';
            }

            if (!targetWs.startsWith('ws://') && !targetWs.startsWith('wss://')) {
              if (targetWs.startsWith('https://')) {
                targetWs = targetWs.replaceFirst('https://', 'wss://');
              } else if (targetWs.startsWith('http://')) {
                targetWs = targetWs.replaceFirst('http://', 'ws://');
              } else {
                targetWs = 'ws://$targetWs';
              }
            }

            setState(() {
              _logs.add('>>> 正在连接至电脑: $targetWs');
            });
            _wsService.connect(targetWs);
          },
        ),
      ),
    );
  }

  void _setPrompt(String text) {
    setState(() {
      _promptCtrl.text = text;
    });
  }

  void _dispatchTask() {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;

    if (!_wsService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ 请先点击右上角【扫码/连接】电脑！'),
          action: SnackBarAction(label: '去扫码', onPressed: _openScanner),
        ),
      );
      return;
    }

    _wsService.startSession(_selectedAgent, prompt, _workingDirCtrl.text.trim());

    setState(() {
      _logs.add('>>> 派发任务给 [$_selectedAgent]: $prompt');
      _activeStatus = '正在执行任务...';
      _promptCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _wsService.isConnected;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text('⚡ CloudWork 指挥官', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF58A6FF)),
            tooltip: '扫码配对连接电脑',
            onPressed: _openScanner,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: _openScanner,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isConnected ? const Color(0x333FB950) : const Color(0x33F85149),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isConnected ? const Color(0x663FB950) : const Color(0x66F85149)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isConnected ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? '已连电脑' : '未连接(点击)',
                      style: TextStyle(color: isConnected ? const Color(0xFF3FB950) : const Color(0xFFF85149), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 未连接提示卡片
            if (!isConnected)
              InkWell(
                onTap: _openScanner,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2128),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF58A6FF).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_scanner, color: Color(0xFF58A6FF), size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('点击扫描电脑屏幕二维码', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            SizedBox(height: 2),
                            Text('扫码完成端到端加密握手即可遥控', style: TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Color(0xFF8B949E), size: 14),
                    ],
                  ),
                ),
              ),

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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('📡 电脑端实时输出', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(_activeStatus, style: const TextStyle(color: Color(0xFF58A6FF), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 200,
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
