import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/agent_event.dart';
import '../models/device_pair.dart';
import '../services/websocket_client.dart';
import 'scanner_screen.dart';

// 单步工具数据
class ToolStepData {
  final String command;
  String output;
  bool isRunning;
  bool isSuccess;
  bool isExpanded;
  ToolStepData(this.command, {this.output = '', this.isRunning = true, this.isSuccess = false, this.isExpanded = false});
}

// 消息项基类
abstract class ChatItem {}

class UserChatItem extends ChatItem {
  final String text;
  final DateTime time;
  UserChatItem(this.text, this.time);
}

// Antigravity 2.0 单轮统一回复容器
class AgentTurnItem extends ChatItem {
  final String agent;
  String? thinkingText;
  bool isThinkingPulsing;
  bool isThinkingExpanded;
  final List<ToolStepData> tools = [];
  AgentEvent? pendingApproval;
  bool isApprovalDecided;
  bool wasApprovalAllowed;
  bool isToolsExpanded;
  String answerText;
  String? statsText;
  bool isCompleted;
  final DateTime time;

  AgentTurnItem(
    this.agent,
    this.time, {
    this.thinkingText,
    this.isThinkingPulsing = false,
    this.isThinkingExpanded = false,
    this.isToolsExpanded = false,
    this.pendingApproval,
    this.isApprovalDecided = false,
    this.wasApprovalAllowed = false,
    this.answerText = '',
    this.statsText,
    this.isCompleted = false,
  });
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
  bool _isExecuting = false;
  AgentTurnItem? _currentTurn;

  @override
  void initState() {
    super.initState();
    _wsService.addListener(_onWsStateChange);
    _wsService.eventStream.listen(_onAgentEvent);

    // 欢迎卡片
    _chatItems.add(AgentTurnItem(
      'CLOUDFLOW',
      DateTime.now(),
      answerText: '👋 你好！我是你的 CloudWork 远程协同中心。你可以随时在下方输入编程需求或 / 快捷指令，我将调度你电脑本地的 Claude Code / Codex 为你编写代码并自动运行测试。',
      isCompleted: true,
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
      if (_currentTurn == null) {
        _currentTurn = AgentTurnItem(_selectedAgent.toUpperCase(), DateTime.now());
        _chatItems.add(_currentTurn!);
      }

      final turn = _currentTurn!;

      if (ev.type == 'thinking') {
        turn.thinkingText = (turn.thinkingText ?? '') + (ev.message ?? '');
        turn.isThinkingPulsing = true;
      } else if (ev.type == 'tool_call_start') {
        turn.isThinkingPulsing = false;
        turn.isThinkingExpanded = false;
        final cmd = ev.message ?? ev.toolCall?.command ?? '执行命令';
        turn.tools.add(ToolStepData(cmd));
      } else if (ev.type == 'tool_call_end') {
        if (turn.tools.isNotEmpty) {
          final last = turn.tools.last;
          last.isRunning = false;
          last.isSuccess = true;
          last.output = ev.rawOutput ?? '';
        }
      } else if (ev.type == 'tool_call_request') {
        turn.pendingApproval = ev;
      } else if (ev.type == 'agent_message') {
        turn.isThinkingPulsing = false;
        turn.isThinkingExpanded = false;
        turn.answerText += (ev.message ?? '');
      } else if (ev.status == 'completed' || ev.type == 'session_finished') {
        turn.isThinkingPulsing = false;
        turn.isThinkingExpanded = false;
        turn.isCompleted = true;
        turn.statsText = (ev.message ?? '').replaceAll('✅', '').trim();
        _isExecuting = false;
        _currentTurn = null;
      } else if (ev.type == 'std_output' && ev.message != null) {
        final msg = ev.message!.trim();
        // 过滤 CLI 启动与框架底层噪音
        if (msg.startsWith('Reading additional input') ||
            msg.contains('codex_models_manager') ||
            msg.contains('failed to refresh available models') ||
            (msg.startsWith('{') && msg.contains('gpt-'))) {
          return;
        }
        if (turn.answerText.isEmpty) {
          turn.answerText += msg;
        }
      }
    });

    _scrollToBottom();
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
      _currentTurn = AgentTurnItem(_selectedAgent.toUpperCase(), DateTime.now());
      _chatItems.add(_currentTurn!);
    });

    _wsService.startSession(_selectedAgent, prompt, '.');
    _scrollToBottom();
  }

  void _decideApproval(AgentTurnItem turn, bool allow) {
    if (turn.pendingApproval == null) return;
    if (allow) {
      _wsService.approveTool(turn.pendingApproval!.sessionId);
    } else {
      _wsService.rejectTool(turn.pendingApproval!.sessionId);
    }
    setState(() {
      turn.isApprovalDecided = true;
      turn.wasApprovalAllowed = allow;
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
    } else if (item is AgentTurnItem) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF14181F),
          border: Border.all(color: const Color(0xFF2D333B)),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFA371F7), Color(0xFF58A6FF)]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(child: Text('AI', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 6),
                    Text(item.agent, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.isCompleted ? const Color(0x263FB950) : const Color(0x2658A6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.isCompleted ? '完成' : '运行中',
                    style: TextStyle(color: item.isCompleted ? const Color(0xFF3FB950) : const Color(0xFF58A6FF), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 1. 思考过程
            if (item.thinkingText != null && item.thinkingText!.isNotEmpty) ...[
              InkWell(
                onTap: () => setState(() => item.isThinkingExpanded = !item.isThinkingExpanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x14A371F7),
                    border: Border.all(color: const Color(0x33A371F7)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.isCompleted ? '💭 深度规划已就绪' : '💭 深度思考与规划中...', style: const TextStyle(color: Color(0xFFD2A8FF), fontSize: 11)),
                      Icon(item.isThinkingExpanded ? Icons.expand_less : Icons.expand_more, size: 14, color: const Color(0xFFD2A8FF)),
                    ],
                  ),
                ),
              ),
              if (item.isThinkingExpanded)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x40000000),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(item.thinkingText!, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFFBC8CFF))),
                ),
              const SizedBox(height: 6),
            ],

            // 2. 工具调用步骤清单 (Antigravity 2.0 聚合折叠)
            if (item.tools.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF161920),
                  border: Border.all(color: const Color(0xFF242933)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() => item.isToolsExpanded = !item.isToolsExpanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.isCompleted
                                  ? '⚙️ 已完成 ${item.tools.length} 个执行步骤'
                                  : '⚙️ 正在执行步骤 (${item.tools.length}): ${item.tools.last.command}',
                              style: const TextStyle(color: Color(0xFF79C0FF), fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                            Text(item.isToolsExpanded ? '[收起]' : '[明细 >]', style: const TextStyle(color: Color(0xFF79C0FF), fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                    if (item.isToolsExpanded)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0E1014),
                          border: Border(top: BorderSide(color: Color(0xFF242933))),
                        ),
                        child: Column(
                          children: [
                            for (var t in item.tools)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(t.command, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF79C0FF)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    Text(t.isRunning ? '运行中...' : '✓ 完成', style: TextStyle(color: t.isRunning ? const Color(0xFF58A6FF) : const Color(0xFF3FB950), fontSize: 9)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // 3. 权限审批
            if (item.pendingApproval != null) ...[
              if (item.isApprovalDecided)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.wasApprovalAllowed ? const Color(0x263FB950) : const Color(0x26F85149),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.wasApprovalAllowed ? '✅ 手机端已授权执行' : '❌ 手机端已拒绝操作',
                    style: TextStyle(color: item.wasApprovalAllowed ? const Color(0xFF3FB950) : const Color(0xFFF85149), fontSize: 11),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x1AD29922),
                    border: Border.all(color: const Color(0xFFD29922)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️ 权限审批请求', style: TextStyle(color: Color(0xFFD29922), fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(item.pendingApproval!.toolCall?.command ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF7EE787))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _decideApproval(item, false),
                              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF85149), side: const BorderSide(color: Color(0xFFDA3633))),
                              child: const Text('❌ 拒绝', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _decideApproval(item, true),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636), foregroundColor: Colors.white),
                              child: const Text('✅ 允许', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
            ],

            // 4. 正式回答正文
            if (item.answerText.isNotEmpty)
              SelectableText(item.answerText, style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 13, height: 1.5)),

            // 5. 底部浅灰微型状态与复制
            if (item.isCompleted) ...[
              const Divider(color: Color(0x332D333B), height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.statsText != null && item.statsText!.isNotEmpty ? item.statsText! : '任务执行完成',
                    style: const TextStyle(color: Color(0xFF6E7681), fontSize: 10),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: item.answerText));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制回答到剪贴板'), duration: Duration(seconds: 1)));
                    },
                    child: const Text('📋 复制', style: TextStyle(color: Color(0xFF8B949E), fontSize: 10)),
                  ),
                ],
              ),
            ],
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
      height: 36,
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
        side: const BorderSide(color: const Color(0xFF30363D)),
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
            width: 40,
            height: 40,
            child: ElevatedButton(
              onPressed: () => _dispatchTask(_promptCtrl.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF58A6FF),
                foregroundColor: const Color(0xFF090D13),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Icon(Icons.send_rounded, size: 18),
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
