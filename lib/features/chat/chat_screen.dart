import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final Map<String, dynamic>? taskData;
  final DateTime time;
  ChatMessage({
    required this.text,
    required this.isUser,
    this.taskData,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _api = ApiClient();
  final _messages = <ChatMessage>[];
  bool _loading = false;
  int _telegramId = 0;

  // Quick suggestions
  static const _suggestions = [
    '📋 Vazifalarni ko\'rsating',
    '📊 Hisobot tayyorlash',
    '👥 Xodimlar ro\'yxati',
    '📄 Hujjat yuklash',
  ];

  @override
  void initState() {
    super.initState();
    _loadId();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _telegramId = prefs.getInt('telegram_id') ?? 0);
  }

  Future<void> _send([String? text]) async {
    final msg = (text ?? _ctrl.text).trim();
    if (msg.isEmpty || _loading) return;
    _ctrl.clear();
    setState(() {
      _messages.add(ChatMessage(text: msg, isUser: true));
      _loading = true;
    });
    _scrollDown();
    try {
      final res = await _api.chat(msg, _telegramId);
      setState(() {
        _messages.add(ChatMessage(
          text: res['answer'] ?? '',
          isUser: false,
          taskData: res['task_title'] != null ? res : null,
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
            text: '❌ Server bilan bog\'lanishda xatolik. Qayta urinib ko\'ring.',
            isUser: false));
      });
    } finally {
      setState(() => _loading = false);
      _scrollDown();
    }
  }

  Future<void> _uploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = File(result.files.first.path!);
      final name = result.files.first.name;

      setState(() {
        _messages.add(ChatMessage(
            text: '📎 $name yuklanyapti...', isUser: true));
        _loading = true;
      });
      _scrollDown();

      await _api.uploadDocument(file, _telegramId);

      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(
            text: '📎 $name muvaffaqiyatli yuklandi. Hujjatni tahlil qilishni so\'rasangiz yozing.',
            isUser: true));
        _loading = false;
      });
      _scrollDown();
    } catch (e) {
      setState(() {
        _loading = false;
        _messages.add(ChatMessage(
            text: '❌ Fayl yuklashda xatolik yuz berdi.', isUser: false));
      });
    }
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _confirmTask(Map<String, dynamic> task) async {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Vazifa tasdiqlandi: ${task['task_title']}'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Chatni tozalash',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        content: const Text('Barcha xabarlar o\'chiriladi.',
            style: TextStyle(fontSize: 14, color: AppColors.textSec)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Bekor qilish',
                  style: TextStyle(color: AppColors.textSec))),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _messages.clear());
              },
              child: const Text('Tozalash',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_outlined,
                  size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Markaziy Bank AI',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                Text('Onlayn',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: _clearChat,
              tooltip: 'Chatni tozalash',
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _emptyState()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length) return _typingIndicator();
                      return _buildMessage(_messages[i]);
                    },
                  ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _emptyState() => Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.smart_toy_outlined,
                        size: 32, color: AppColors.accent),
                  ),
                  const SizedBox(height: 16),
                  const Text('Markaziy Bank AI',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  const Text('Savol yoki topshiriq yozing',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSec)),
                ],
              ),
            ),
          ),
          // Quick suggestions
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _send(_suggestions[i]
                    .replaceAll(RegExp(r'^[^\s]+ '), '')),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(_suggestions[i],
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSec)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );

  Widget _buildMessage(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: msg.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!msg.isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8, bottom: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.smart_toy_outlined,
                      size: 14, color: AppColors.accent),
                ),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: msg.isUser
                        ? AppColors.accent
                        : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft:
                          Radius.circular(msg.isUser ? 16 : 4),
                      bottomRight:
                          Radius.circular(msg.isUser ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: msg.isUser
                          ? Colors.white
                          : AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (msg.taskData != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: _taskCard(msg.taskData!),
            ),
          ],
          Padding(
            padding: EdgeInsets.only(
                top: 4,
                left: msg.isUser ? 0 : 36,
                right: msg.isUser ? 4 : 0),
            child: Text(
              _formatTime(msg.time),
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> task) {
    final priority = task['priority'] ?? 'o\'rta';
    final priorityColor = priority == 'yuqori'
        ? AppColors.error
        : priority == 'past'
            ? AppColors.success
            : AppColors.warning;

    return Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('📌 ',
                        style: TextStyle(fontSize: 13)),
                    const Text('Vazifa aniqlandi',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSec)),
                    const Spacer(),
                    if (task['task_id'] != null)
                      Text('#${task['task_id']}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(task['task_title'] ?? '',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if ((task['responsible_department'] ?? '').isNotEmpty)
                      _badge(
                          '🏢 ${task['responsible_department']}',
                          AppColors.surface,
                          AppColors.textSec),
                    _badge(priority,
                        priorityColor.withOpacity(0.1), priorityColor),
                  ],
                ),
                if ((task['source_document'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('📄 ${task['source_document']}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _confirmTask(task),
                  child: const Text('✅ Tasdiqlash',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.success)),
                ),
              ),
              Container(
                  width: 1, height: 40, color: AppColors.border),
              Expanded(
                child: TextButton(
                  onPressed: () {},
                  child: const Text('👥 Boshqa xodim',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accent)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg, Color textColor) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(100)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textColor)),
      );

  Widget _typingIndicator() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_outlined,
                  size: 14, color: AppColors.accent),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(0),
                  const SizedBox(width: 4),
                  _dot(200),
                  const SizedBox(width: 4),
                  _dot(400),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (_, val, __) => Opacity(
        opacity: val,
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
              color: AppColors.textHint, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _inputBar() => Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Fayl yuklash tugmasi
            GestureDetector(
              onTap: _loading ? null : _uploadFile,
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.attach_file_rounded,
                    size: 18, color: AppColors.textSec),
              ),
            ),
            // Matn kiritish
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Savol yoki topshiriq yozing...',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(
                        color: AppColors.accent, width: 1.5),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Yuborish tugmasi
            GestureDetector(
              onTap: _loading ? null : _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _loading
                      ? AppColors.border
                      : AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      );

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
