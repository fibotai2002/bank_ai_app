import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
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
  final _recorder = AudioRecorder();
  bool _loading = false;
  bool _isRecording = false;
  int _telegramId = 0;
  int _userId = 0;

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
    setState(() {
      _telegramId = prefs.getInt('telegram_id') ?? 0;
      _userId = prefs.getInt('user_id') ?? 0;
    });
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
      final chatId = _userId > 0 ? _userId : _telegramId;
      final res = await _api.chat(msg, chatId);
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
            text:
                '❌ Server bilan bog\'lanishda xatolik. Qayta urinib ko\'ring.',
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
        _messages
            .add(ChatMessage(text: '📎 $name yuklanyapti...', isUser: true));
        _loading = true;
      });
      _scrollDown();

      await _api.uploadDocument(file, _telegramId);

      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(
            text:
                '📎 $name muvaffaqiyatli yuklandi. Hujjatni tahlil qilishni so\'rasangiz yozing.',
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

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        _sendVoice(File(path));
      }
    } else {
      if (await Permission.microphone.request().isGranted) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
        HapticFeedback.mediumImpact();
      }
    }
  }

  Future<void> _sendVoice(File file) async {
    setState(() {
      _messages.add(ChatMessage(text: '🎤 Ovozli xabar yuborildi', isUser: true));
      _loading = true;
    });
    _scrollDown();

    try {
      final chatId = _userId > 0 ? _userId : _telegramId;
      // Real holda audio tahlili backend orqali bo'ladi
      final res = await _api.chat('Ovozli xabarni tahlil qil', chatId);
      setState(() {
        _messages.add(ChatMessage(
          text: res['answer'] ?? 'Ovozli xabar tahlil qilindi.',
          isUser: false,
          taskData: res['task_title'] != null ? res : null,
        ));
      });
    } catch (_) {
      setState(() {
        _messages.add(ChatMessage(text: '❌ Ovozni tahlil qilishda xato', isUser: false));
      });
    } finally {
      setState(() => _loading = false);
      _scrollDown();
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
    // Agar task_id mavjud bo'lsa, statusni in_progress ga o'tkazish
    if (task['task_id'] != null) {
      try {
        await _api.updateTaskStatus(task['task_id'], 'in_progress');
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Vazifa tasdiqlandi: ${task['task_title']}'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _editTask(Map<String, dynamic> task) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleCtrl = TextEditingController(text: task['task_title'] ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final bgColor = isDark ? AppColors.darkSurface : AppColors.bg;
        final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
        final textColor = isDark ? AppColors.darkText : AppColors.textPrimary;
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Vazifani tahrirlash',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(
                      hintText: 'Vazifa nomi'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    Navigator.pop(context);
                    if (task['task_id'] != null) {
                      try {
                        await _api.updateTask(task['task_id'],
                            {'title': titleCtrl.text.trim()});
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('✅ Vazifa yangilandi'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ));
                        }
                      } catch (_) {}
                    }
                  },
                  child: const Text('Saqlash'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _clearChat() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.bg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Chatni tozalash',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkText
                    : AppColors.textPrimary)),
        content: Text('Barcha xabarlar o\'chiriladi.',
            style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextSec
                    : AppColors.textSec)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Bekor qilish',
                  style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextSec
                          : AppColors.textSec))),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.bg;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final iconColor = isDark ? AppColors.darkTextSec : AppColors.textHint;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.smart_toy_outlined,
                  size: 18,
                  color: isDark ? AppColors.darkAccent : AppColors.accent),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Markaziy Bank AI',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.textPrimary)),
                const Text('Onlayn',
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
              icon: Icon(Icons.delete_outline_rounded,
                  size: 20, color: iconColor),
              onPressed: _clearChat,
              tooltip: 'Chatni tozalash',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _emptyState(isDark)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length) return _typingIndicator(isDark);
                      return _buildMessage(_messages[i], isDark);
                    },
                  ),
          ),
          _inputBar(isDark),
        ],
      ),
    );
  }

  Widget _emptyState(bool isDark) => Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.smart_toy_outlined,
                        size: 34,
                        color: isDark
                            ? AppColors.darkAccent
                            : AppColors.accent),
                  ),
                  const SizedBox(height: 16),
                  Text('Markaziy Bank AI',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Text('Savol yoki topshiriq yozing',
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSec
                              : AppColors.textSec)),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _send(
                    _suggestions[i].replaceAll(RegExp(r'^[^\s]+ '), '')),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface2
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.border),
                  ),
                  child: Text(_suggestions[i],
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkTextSec
                              : AppColors.textSec)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );

  Widget _buildMessage(ChatMessage msg, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 10, bottom: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_awesome,
                      size: 16,
                      color: isDark ? AppColors.darkAccent : AppColors.accent),
                ),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: msg.text));
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('📋 Nusxa olindi'),
                        backgroundColor: AppColors.textSec,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  child: Container(
                    constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.width * 0.78),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? AppColors.accent
                          : (isDark
                              ? AppColors.darkSurface2
                              : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft:
                            Radius.circular(msg.isUser ? 20 : 4),
                        bottomRight:
                            Radius.circular(msg.isUser ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withOpacity(isDark ? 0.2 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: msg.isUser
                          ? null
                          : Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.border),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 15,
                        color: msg.isUser
                            ? Colors.white
                            : (isDark
                                ? AppColors.darkText
                                : AppColors.textPrimary),
                        height: 1.5,
                        fontWeight: msg.isUser
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
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
              child: _taskCard(msg.taskData!, isDark),
            ),
          ],
          Padding(
            padding: EdgeInsets.only(
                top: 4,
                left: msg.isUser ? 0 : 36,
                right: msg.isUser ? 4 : 0),
            child: Text(
              _formatTime(msg.time),
              style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.darkTextSec
                      : AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> task, bool isDark) {
    final priority = task['priority'] ?? 'o\'rta';
    final priorityColor = priority == 'yuqori'
        ? AppColors.error
        : priority == 'past'
            ? AppColors.success
            : AppColors.warning;

    return Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: priorityColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: priorityColor.withOpacity(isDark ? 0.08 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: priorityColor.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.assignment_turned_in_rounded,
                    size: 14, color: priorityColor),
                const SizedBox(width: 8),
                Text('AI tomonidan aniqlangan vazifa',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.textPrimary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task['task_title'] ?? '',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.textPrimary)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if ((task['responsible_department'] ?? '')
                        .isNotEmpty)
                      _badge(
                          '🏢 ${task['responsible_department']}',
                          isDark
                              ? AppColors.darkSurface2
                              : AppColors.surfaceVar,
                          isDark
                              ? AppColors.darkText
                              : AppColors.textPrimary),
                    const SizedBox(width: 8),
                    _badge(priority.toUpperCase(),
                        priorityColor.withOpacity(0.15), priorityColor),
                  ],
                ),
                if ((task['deadline'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 12,
                          color: isDark
                              ? AppColors.darkTextSec
                              : AppColors.textHint),
                      const SizedBox(width: 6),
                      Text('Muddat: ${task['deadline']}',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSec
                                  : AppColors.textHint,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : AppColors.border),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _confirmTask(task),
                    style: TextButton.styleFrom(
                      backgroundColor:
                          AppColors.success.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Tasdiqlash',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => _editTask(task),
                    style: TextButton.styleFrom(
                      backgroundColor:
                          AppColors.accent.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('O\'zgartirish',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkAccent
                                : AppColors.accent)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg, Color textColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(100)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textColor)),
      );

  Widget _typingIndicator(bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.smart_toy_outlined,
                  size: 14,
                  color:
                      isDark ? AppColors.darkAccent : AppColors.accent),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(isDark),
                  const SizedBox(width: 4),
                  _dot(isDark),
                  const SizedBox(width: 4),
                  _dot(isDark),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _dot(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (_, val, __) => Opacity(
        opacity: val,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
              color: isDark ? AppColors.darkTextSec : AppColors.textHint,
              shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _inputBar(bool isDark) {
    final bgColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.bg,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded,
                color: isDark ? AppColors.darkTextSec : AppColors.textHint),
            onPressed: _uploadFile,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      maxLines: null,
                      style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Savol yozing...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  if (_ctrl.text.isEmpty)
                    GestureDetector(
                      onLongPress: _toggleRecording,
                      onLongPressEnd: (_) => _toggleRecording(),
                      child: IconButton(
                        icon: Icon(
                          _isRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
                          color: _isRecording ? AppColors.error : AppColors.accent,
                        ),
                        onPressed: _toggleRecording,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _loading
              ? const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Container(
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded,
                        size: 20, color: Colors.white),
                    onPressed: () => _send(),
                  ),
                ),
        ],
      ),
    );
  }
}
                  color: isDark ? AppColors.darkBorder : AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: _loading ? null : _uploadFile,
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface2 : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.border),
                ),
                child: Icon(Icons.attach_file_rounded,
                    size: 18,
                    color: isDark
                        ? AppColors.darkTextSec
                        : AppColors.textSec),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: TextStyle(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Savol yoki topshiriq yozing...',
                  hintStyle: TextStyle(
                      color: isDark
                          ? AppColors.darkTextSec
                          : AppColors.textHint),
                  filled: true,
                  fillColor:
                      isDark ? AppColors.darkSurface2 : AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius:
                        const BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        const BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        const BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkAccent
                            : AppColors.accent,
                        width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _loading ? null : _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _loading
                      ? (isDark ? AppColors.darkBorder : AppColors.border)
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
