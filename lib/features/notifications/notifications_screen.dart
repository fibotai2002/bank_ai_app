import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiClient();
  List<dynamic> _notifs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getMyNotifications();
      setState(() => _notifs = res);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _markRead(int id) async {
    try {
      await _api.markNotificationRead(id);
      _load();
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await _api.markAllMyNotificationsRead();
      _load();
    } catch (_) {}
  }

  int get _unreadCount => _notifs.where((n) => n['is_read'] == false).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.bg;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Row(
          children: [
            const Text('Bildirishnomalar'),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text('$_unreadCount',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Barchasini o\'qi',
                  style: TextStyle(fontSize: 12, color: AppColors.accent)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2))
          : _notifs.isEmpty
              ? _empty(isDark)
              : RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _notifTile(_notifs[i], isDark),
                  ),
                ),
    );
  }

  Widget _notifTile(Map n, bool isDark) {
    final isRead = n['is_read'] == true;
    final type = n['type'] ?? 'info';

    final typeIcon = {
      'task': Icons.assignment_outlined,
      'success': Icons.check_circle_outline,
      'warning': Icons.warning_amber_outlined,
      'info': Icons.info_outline_rounded,
    }[type] ??
        Icons.notifications_outlined;

    final typeColor = {
      'task': AppColors.accent,
      'success': AppColors.success,
      'warning': AppColors.warning,
      'info': const Color(0xFF0891B2),
    }[type] ??
        AppColors.accent;

    // Unread background color
    final unreadBg = isDark
        ? AppColors.darkAccent.withOpacity(0.08)
        : AppColors.accentLight.withOpacity(0.4);
    final readBg = isDark ? AppColors.darkSurface : AppColors.bg;
    final unreadBorder = isDark
        ? AppColors.darkAccent.withOpacity(0.25)
        : AppColors.accent.withOpacity(0.3);
    final readBorder = isDark ? AppColors.darkBorder : AppColors.border;

    return GestureDetector(
      onTap: isRead ? null : () => _markRead(n['id']),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? readBg : unreadBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? readBorder : unreadBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeIcon, size: 18, color: typeColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n['title'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.w700,
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n['body'] ?? '',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSec
                            : AppColors.textSec,
                        height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(n['created_at'] ?? ''),
                    style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.darkTextSec
                            : AppColors.textHint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Hozir';
      if (diff.inHours < 1) return '${diff.inMinutes} daqiqa oldin';
      if (diff.inDays < 1) return '${diff.inHours} soat oldin';
      if (diff.inDays < 7) return '${diff.inDays} kun oldin';
      return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return '';
    }
  }

  Widget _empty(bool isDark) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 56,
                color: isDark ? AppColors.darkTextSec : AppColors.textHint),
            const SizedBox(height: 12),
            Text('Bildirishnomalar yo\'q',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color:
                        isDark ? AppColors.darkTextSec : AppColors.textSec)),
          ],
        ),
      );
}
