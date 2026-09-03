import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _CommanderScreenState extends State<CommanderScreen> with SingleTickerProviderStateMixin {
  final WebSocketService _wsService = WebSocketService();
  late TabController _tabController;
  final ScrollController _logScrollController = ScrollController();

  String _selectedAgent = 'codex';
  final TextEditingController _workingDirCtrl = TextEditingController(text: '.');
  final TextEditingController _promptCtrl = TextEditingController();
  final List<String> _logs = [];
  String _activeStatus = '空闲 (未连接电脑)';
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _wsService.addListener(_onWsStateChange);
    _wsService.eventStream.listen(_onAgentEvent);
  }

  @override
  void dispose() {
    _wsService.removeListener(_onWsStateChange);
    _wsService.dispose();
    _tabController.dispose();
    _logScrollController.dispose();
    _workingDirCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  void _onWsStateChange() {
    setState(() {
      if (_wsService.isConnected) {
        _activeStatus = '已连接到 ${_wsService.connectedHost ?? '电脑'}';
        if (_wsService.serverWorkingDir.isNotEmpty && _wsService.serverWorkingDir != '.') {
          _workingDirCtrl.text = _wsService.serverWorkingDir;
        }
      } else {
        _activeStatus = '未连接电脑 (请点击右上角扫码)';
      }
    });
  }

  void _onAgentEvent(AgentEvent ev) {
    setState(() {
      _activeStatus = ev.status;
      if (ev.message != null && ev.message!.isNotEmpty) {
        _logs.add(ev.message!);
      } else if (ev.rawOutput != null && ev.rawOutput!.isNotEmpty) {
        _logs.add(ev.rawOutput!);
      }
    });

    if (_autoScroll && _logScrollController.hasClients) {
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }

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
      _tabController.animateTo(1); // 自动切换至终端日志页
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _wsService.isConnected;

    return Scaffold(
      backgroundColor: const Color(0xFF090D13),
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF58A6FF),
          labelColor: const Color(0xFF58A6FF),
          unselectedLabelColor: const Color(0xFF8B949E),
          tabs: [
            const Tab(text: '🎮 遥控指挥'),
            Tab(text: '📜 终端日志 ${_logs.isNotEmpty ? "(${_logs.length})" : ""}'),
            const Tab(text: '📁 工作区'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildControlTab(isConnected),
          _buildLogsTab(),
          _buildWorkspaceTab(),
        ],
      ),
    );
  }

  Widget _buildControlTab(bool isConnected) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                child: const Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: Color(0xFF58A6FF), size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('点击扫描电脑屏幕二维码', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 2),
                          Text('支持 Cloudflare 隧道公网与 Wi-Fi 局域网直连', style: TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Color(0xFF8B949E), size: 14),
                  ],
                ),
              ),
            ),

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
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🚀 派发任务给受控 Agent', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('零配置 · 凭据本地继承', style: TextStyle(color: Color(0xFF3FB950), fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 14),
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
                    _buildChip('🧪 运行测试', '运行所有单元测试并修复发现的错误'),
                    _buildChip('🔍 审查代码', '详细审查当前项目的最近改动，指出安全隐患'),
                    _buildChip('📝 编写文档', '为当前模块补充清晰规范的架构文档与使用说明'),
                    _buildChip('🧹 代码精简', '精简当前模块的多余代码与未使用的依赖'),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _promptCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '输入要交给 AI Agent 自动执行的编程指令...',
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('📡 电脑端会话状态', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                Text(_activeStatus, style: const TextStyle(color: Color(0xFF58A6FF), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: const Color(0xFF161B22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('输出条目: ${_logs.length}', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
              Row(
                children: [
                  TextButton.icon(
                    icon: Icon(_autoScroll ? Icons.arrow_downward : Icons.pause, size: 14),
                    label: Text(_autoScroll ? '滚屏: 开' : '滚屏: 关', style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF58A6FF)),
                    onPressed: () => setState(() => _autoScroll = !_autoScroll),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: Color(0xFF8B949E)),
                    tooltip: '复制日志',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _logs.join('\n')));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制日志到剪贴板')));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF8B949E)),
                    tooltip: '清空日志',
                    onPressed: () => setState(() => _logs.clear()),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF0D1117),
            padding: const EdgeInsets.all(12),
            child: ListView.builder(
              controller: _logScrollController,
              itemCount: _logs.length,
              itemBuilder: (ctx, i) {
                final line = _logs[i];
                Color color = const Color(0xFFC9D1D9);
                if (line.contains('✅') || line.contains('成功')) {
                  color = const Color(0xFF3FB950);
                } else if (line.contains('⚠️') || line.contains('审批')) {
                  color = const Color(0xFFD29922);
                } else if (line.contains('❌') || line.contains('错误') || line.contains('FAIL')) {
                  color = const Color(0xFFF85149);
                } else if (line.startsWith('>>>') || line.contains('⚡')) {
                  color = const Color(0xFF58A6FF);
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SelectableText(
                    line,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: color, height: 1.4),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkspaceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('快速切换项目工作目录', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ListTile(
          tileColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: const Icon(Icons.folder_open, color: Color(0xFF58A6FF)),
          title: const Text('当前项目根目录', style: TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: const Text('.', style: TextStyle(color: Color(0xFF8B949E), fontFamily: 'monospace', fontSize: 12)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF8B949E)),
          onTap: () {
            setState(() => _workingDirCtrl.text = '.');
            _tabController.animateTo(0);
          },
        ),
        const SizedBox(height: 8),
        ListTile(
          tileColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: const Icon(Icons.folder_special, color: Color(0xFF58A6FF)),
          title: const Text('cloudwork 主工作区', style: TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: const Text('E:\\privateproject\\cloudwork', style: TextStyle(color: Color(0xFF8B949E), fontFamily: 'monospace', fontSize: 12)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF8B949E)),
          onTap: () {
            setState(() => _workingDirCtrl.text = 'E:\\privateproject\\cloudwork');
            _tabController.animateTo(0);
          },
        ),
      ],
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
