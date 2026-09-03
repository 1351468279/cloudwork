import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/agent_event.dart';
import '../models/device_pair.dart';
import '../services/websocket_client.dart';
import 'scanner_screen.dart';

// 消息项基类
abstract class ChatItem {}

class UserChatItem extends ChatItem {
  final String text;
  final DateTime time;
  UserChatItem(this.text, this.time);
}

class AgentChatItem extends ChatItem {
  final String agent;
  final String text;
  final DateTime time;
  AgentChatItem(this.agent, this.text, this.time);
}

class ThinkingChatItem extends ChatItem {
  String text;
  bool isPulsing;
  bool isExpanded;
  ThinkingChatItem(this.text, {this.isPulsing = true, this.isExpanded = true});
}

class ToolChatItem extends ChatItem {
  final String command;
  String output;
  bool isRunning;
  bool isSuccess;
  bool isExpanded;
  ToolChatItem(this.command, {this.output = '', this.isRunning = true, this.isSuccess = false, this.isExpanded = false});
}

class ApprovalChatItem extends ChatItem {
  final AgentEvent event;
  bool isDecided;
  bool wasAllowed;
  ApprovalChatItem(this.event, {this.isDecided = false, this.wasAllowed = false});
}

class CommanderScreen extends StatefulWidget {
  const CommanderScreen({super.key});

  @override
  State<CommanderScreen> createState() => _CommanderScreenState();
}

class _CommanderScreenState extends State<CommanderScreen> {
  final WebSocketService _wsService = WebSocketService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _promptCtrl = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _selectedAgent = 'claude';
  final List<ChatItem> _chatItems = [];
  bool _showSlashMenu = false;
  String _activeTimer = '00:00';
  int _seconds = 0;
  bool _isExecuting = false;
  ThinkingChatItem? _currentThinking;
  ToolChatItem? _currentTool;

  String _gitDiffStat = '';
  String _gitDiffBody = '';

  @override
  void initState() {
    super.initState();
    _wsService.addListener(_onWsStateChange);
    _wsService.eventStream.listen(_onAgentEvent);

    // 欢迎气泡
    _chatItems.add(AgentChatItem(
      'CLOUDFLOW',
      '👋 你好！我是你的 CloudWork 远程协同指挥官。你可以随时在下方输入指令或 / 快捷命令，我将无感调度你家中电脑的 Claude Code / Codex 为你编写代码并自动运行测试。',
      DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _wsService.removeListener(_onWsStateChange);
    _wsService.dispose();
    _scrollController.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  void _onWsStateChange() {
    setState(() {});
  }

  void _onAgentEvent(AgentEvent ev) {
    setState(() {
      if (ev.type == 'thinking') {
        if (_currentThinking == null) {
          _currentThinking = ThinkingChatItem(ev.message ?? '正在深度思考与规划...');
          _chatItems.add(_currentThinking!);
        } else {
          _currentThinking!.text += '\n${ev.message ?? ''}';
        }
      } else if (ev.type == 'tool_call_start') {
        _finishThinking();
        final cmd = ev.message ?? ev.toolCall?.command ?? '执行命令';
        _currentTool = ToolChatItem(cmd);
        _chatItems.add(_currentTool!);
      } else if (ev.type == 'tool_call_end') {
        if (_currentTool != null) {
          _currentTool!.isRunning = false;
          _currentTool!.isSuccess = true;
          _currentTool!.output = ev.rawOutput ?? '';
          _currentTool = null;
        }
      } else if (ev.type == 'tool_call_request') {
        _finishThinking();
        _chatItems.add(ApprovalChatItem(ev));
      } else if (ev.type == 'agent_message') {
        _finishThinking();
        _chatItems.add(AgentChatItem(_selectedAgent.toUpperCase(), ev.message ?? '', DateTime.now()));
      } else if (ev.status == 'completed' || ev.type == 'session_finished') {
        _finishThinking();
        _isExecuting = false;
        _chatItems.add(AgentChatItem('CLOUDFLOW', '✅ 任务执行完毕！${ev.message ?? ''}', DateTime.now()));
      } else if (ev.type == 'std_output' && ev.message != null && ev.message!.isNotEmpty) {
        if (_currentThinking != null) {
          _currentThinking!.text += '\n${ev.message}';
        } else {
          _chatItems.add(AgentChatItem(_selectedAgent.toUpperCase(), ev.message!, DateTime.now()));
        }
      }
    });

    _scrollToBottom();
  }

  void _finishThinking() {
    if (_currentThinking != null) {
      _currentThinking!.isPulsing = false;
      _currentThinking!.isExpanded = false;
      _currentThinking = null;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _dispatchTask(String prompt) {
    if (prompt.trim().isEmpty) return;

    if (!_wsService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ 请先连接电脑！'),
          action: SnackBarAction(label: '去连接', onPressed: _openScanner),
        ),
      );
      return;
    }

    setState(() {
      _chatItems.add(UserChatItem(prompt, DateTime.now()));
      _promptCtrl.clear();
      _showSlashMenu = false;
      _isExecuting = true;
    });

    _wsService.startSession(_selectedAgent, prompt, '.');
    _scrollToBottom();
  }

  void _decideApproval(ApprovalChatItem item, bool allow) {
    if (allow) {
      _wsService.approveTool(item.event.sessionId);
    } else {
      _wsService.rejectTool(item.event.sessionId);
    }
    setState(() {
      item.isDecided = true;
      item.wasAllowed = allow;
    });
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
              targetWs = 'ws://${pair.localIps.first}:${pair.port}/ws';
            }
            _wsService.connect(targetWs);
          },
        ),
      ),
    );
  }

  void _openDiffDrawer() {
    _wsService.sendAction('get_diff', {});
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _wsService.isConnected;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF090D13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF11151C),
        elevation: 0,
        title: const Text('⚡ CloudWork', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1F242C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedAgent,
                dropdownColor: const Color(0xFF161B22),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                items: const [
                  DropdownMenuItem(value: 'claude', child: Text('Claude')),
                  DropdownMenuItem(value: 'codex', child: Text('Codex')),
                  DropdownMenuItem(value: 'aider', child: Text('Aider')),
                  DropdownMenuItem(value: 'generic', child: Text('Generic')),
                ],
                onChanged: (val) => setState(() => _selectedAgent = val!),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.difference_outlined, size: 20, color: Color(0xFF8B949E)),
            tooltip: '审查改动 (Diff)',
            onPressed: _openDiffDrawer,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: _openScanner,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    const SizedBox(width: 5),
                    Text(
                      isConnected ? '已连电脑' : '未连接',
                      style: TextStyle(color: isConnected ? const Color(0xFF3FB950) : const Color(0xFFF85149), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      endDrawer: _buildDiffDrawer(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(14),
              itemCount: _chatItems.length,
              itemBuilder: (ctx, i) => _buildChatItem(_chatItems[i]),
            ),
          ),
          if (_showSlashMenu) _buildSlashMenu(),
          _buildPromptChips(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildChatItem(ChatItem item) {
    if (item is UserChatItem) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1F6FEB), Color(0xFF1158C7)]),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(color: const Color(0xFF1F6FEB).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(item.text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
              const SizedBox(height: 4),
              Text(
                '${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ],
          ),
        ),
      );
    } else if (item is AgentChatItem) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFA371F7), Color(0xFF58A6FF)]),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Center(child: Text('AI', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 6),
                Text(item.agent, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                border: Border.all(color: const Color(0xFF30363D)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: SelectableText(item.text, style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 13, height: 1.5)),
            ),
          ],
        ),
      );
    } else if (item is ThinkingChatItem) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0x14A371F7),
          border: Border.all(color: const Color(0x40A371F7)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => item.isExpanded = !item.isExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.isPulsing ? '💭 深度思考与规划中...' : '💭 深度规划已就绪', style: const TextStyle(color: Color(0xFFD2A8FF), fontSize: 12, fontWeight: FontWeight.w600)),
                    Icon(item.isExpanded ? Icons.expand_less : Icons.expand_more, size: 16, color: const Color(0xFFD2A8FF)),
                  ],
                ),
              ),
            ),
            if (item.isExpanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0x40000000),
                  border: Border(top: BorderSide(color: Color(0x26A371F7))),
                ),
                child: Text(item.text, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFBC8CFF))),
              ),
          ],
        ),
      );
    } else if (item is ToolChatItem) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF11151C),
          border: Border.all(color: const Color(0xFF30363D)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => item.isExpanded = !item.isExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.terminal, size: 14, color: Color(0xFF79C0FF)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(item.command, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF79C0FF)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.isRunning ? const Color(0x3358A6FF) : const Color(0x333FB950),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(item.isRunning ? '运行中...' : '✓ 完成', style: TextStyle(color: item.isRunning ? const Color(0xFF58A6FF) : const Color(0xFF3FB950), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            if (item.isExpanded && item.output.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1117),
                  border: Border(top: BorderSide(color: Color(0xFF30363D))),
                ),
                child: SelectableText(item.output, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF8B949E))),
              ),
          ],
        ),
      );
    } else if (item is ApprovalChatItem) {
      if (item.isDecided) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: item.wasAllowed ? const Color(0x263FB950) : const Color(0x26F85149),
            border: Border.all(color: item.wasAllowed ? const Color(0x663FB950) : const Color(0x66F85149)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            item.wasAllowed ? '✅ 手机端已批准执行命令' : '❌ 手机端已拒绝操作',
            style: TextStyle(color: item.wasAllowed ? const Color(0xFF3FB950) : const Color(0xFFF85149), fontSize: 11, fontWeight: FontWeight.bold),
          ),
        );
      }
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x1AD29922),
          border: Border.all(color: const Color(0xFFD29922), width: 1.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: const Color(0xFFD29922).withOpacity(0.2), blurRadius: 16),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFD29922), size: 18),
                SizedBox(width: 6),
                Text('⚠️ 权限审批请求', style: TextStyle(color: Color(0xFFD29922), fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text(item.event.message ?? 'Agent 申请执行以下敏感操作，请确认：', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: SelectableText(
                item.event.toolCall?.command ?? item.event.toolCall?.description ?? '未知命令',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF7EE787)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decideApproval(item, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF85149),
                      side: const BorderSide(color: Color(0xFFDA3633)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('❌ 拒绝'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _decideApproval(item, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('✅ 允许执行'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildSlashMenu() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2128),
        border: Border.all(color: const Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
      ),
      child: Column(
        children: [
          _buildSlashItem('/test', '自动运行所有单元测试并修复错误'),
          _buildSlashItem('/review', '审查当前未提交的代码变更'),
          _buildSlashItem('/commit', '为当前修改生成规范的 Git Commit 并提交'),
          _buildSlashItem('/clean', '精简多余代码与优化性能'),
        ],
      ),
    );
  }

  Widget _buildSlashItem(String cmd, String desc) {
    return InkWell(
      onTap: () {
        if (cmd == '/test') _promptCtrl.text = '运行所有单元测试并修复发现的错误';
        if (cmd == '/review') _promptCtrl.text = '详细审查当前代码未提交的改动';
        if (cmd == '/commit') _promptCtrl.text = '为当前修改生成语义化 Git Commit 并提交';
        if (cmd == '/clean') _promptCtrl.text = '精简优化当前模块代码，去除多余冗余';
        setState(() => _showSlashMenu = false);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Text(cmd, style: const TextStyle(color: Color(0xFF58A6FF), fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 10),
            Expanded(child: Text(desc, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptChips() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildChip('🧪 运行测试', '运行测试并自动修复错误'),
          _buildChip('🔍 审查代码', '详细审查当前未提交的代码改动'),
          _buildChip('📝 补充文档', '为当前功能补充清晰的文档与使用示例'),
          _buildChip('🧹 代码精简', '精简未使用的代码与无用依赖'),
          _buildChip('📁 审查 Diff', '', onTap: _openDiffDrawer),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String prompt, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: const Color(0xFF1C2128),
        side: const BorderSide(color: Color(0xFF30363D)),
        label: Text(label, style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 11)),
        onPressed: onTap ?? () => _dispatchTask(prompt),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF11151C),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: TextField(
                controller: _promptCtrl,
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: '输入需求或 / 斜杠指令...',
                  hintStyle: TextStyle(color: Color(0xFF484F58), fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (val) {
                  setState(() {
                    _showSlashMenu = val.startsWith('/');
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            height: 42,
            child: ElevatedButton(
              onPressed: () => _dispatchTask(_promptCtrl.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF58A6FF),
                foregroundColor: const Color(0xFF090D13),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Icon(Icons.send_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0D1117),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF161B22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('📁 工作区改动 (Git Diff)', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF8B949E)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('正在与电脑同步 Git 改动...\n支持红减绿加逐行审查。', style: TextStyle(color: Color(0xFF8B949E), fontFamily: 'monospace', fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
