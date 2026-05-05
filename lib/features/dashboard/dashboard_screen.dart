import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToTasks;
  final VoidCallback? onNavigateToChat;

  const DashboardScreen({
    super.key,
    this.onNavigateToTasks,
    this.onNavigateToChat,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _stats;
  List<dynamic> _recentTasks = [];
  List<dynamic> _deptStats = [];
  bool _loading = true;
  String _role = 'employee';
  String _fullName = '';
  String _deptName = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString('role') ?? 'employee';
      _fullName = prefs.getString('full_name') ?? 'Foydalanuvchi';
      _deptName = prefs.getString('department_name') ?? '';
    });
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getStats(),
        _api.getTasks(),
        if (_role == 'admin') _api.getDepartmentStats(),
      ]);
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        final tasks = results[1] as List;
        _recentTasks = tasks.take(5).toList();
        if (_role == 'admin' && results.length > 2) {
          _deptStats = results[2] as List;
        }
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Xayrli tong';
    if (h < 17) return 'Xayrli kun';
    return 'Xayrli kech';
  }

  String get _roleLabel {
    switch (_role) {
      case 'admin': return '👑 Admin';
      case 'manager': return '🏢 Manager';
      default: return '👤 Xodim';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bosh sahifa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _load,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2))
          : RefreshIndicator(
              color: AppColors.accent,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _greetingCard(),
                    const SizedBox(height: 16),
                    if (_stats != null) _statsGrid(),
                    const SizedBox(height: 16),
                    _quickActions(),
                    const SizedBox(height: 16),
                    if (_recentTasks.isNotEmpty) _recentTasksSection(),
                    if (_role == 'admin' && _deptStats.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _deptStatsSection(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _greetingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting,',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 2),
                Text(
                  _fullName,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                if (_deptName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _deptName,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white60),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              _roleLabel,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid() {
    final s = _stats!;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _statCard('Jami vazifa', '${s['total_tasks'] ?? 0}',
            Icons.assignment_outlined, AppColors.accent),
        _statCard('Kutilmoqda', '${s['pending'] ?? 0}',
            Icons.hourglass_empty_rounded, AppColors.warning),
        _statCard('Jarayonda', '${s['in_progress'] ?? 0}',
            Icons.autorenew_rounded, AppColors.accent),
        _statCard('Bajarildi', '${s['completed'] ?? 0}',
            Icons.check_circle_outline, AppColors.success),
        if (_role == 'admin') ...[
          _statCard('Xodimlar', '${s['total_employees'] ?? 0}',
              Icons.people_outline_rounded, const Color(0xFF7C3AED)),
          _statCard('Bo\'limlar', '${s['total_departments'] ?? 0}',
              Icons.business_outlined, const Color(0xFF0891B2)),
        ],
      ],
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSec),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tezkor amallar',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _actionBtn(
                Icons.checklist_rounded,
                'Vazifalar',
                AppColors.accent,
                widget.onNavigateToTasks,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionBtn(
                Icons.smart_toy_rounded,
                'AI Chat',
                const Color(0xFF7C3AED),
                widget.onNavigateToChat,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionBtn(
      IconData icon, String label, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _recentTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('So\'nggi vazifalar',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            GestureDetector(
              onTap: widget.onNavigateToTasks,
              child: const Text('Barchasi →',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._recentTasks.map((t) => _miniTaskTile(t)),
      ],
    );
  }

  Widget _miniTaskTile(Map t) {
    final status = t['status'] ?? 'pending';
    final statusColor = status == 'completed'
        ? AppColors.success
        : status == 'in_progress'
            ? AppColors.accent
            : AppColors.warning;
    final statusLabel = status == 'completed'
        ? 'Bajarildi'
        : status == 'in_progress'
            ? 'Jarayonda'
            : 'Kutmoqda';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if ((t['assignee_name'] ?? '').isNotEmpty)
                  Text(t['assignee_name'],
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSec)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor)),
          ),
        ],
      ),
    );
  }

  Widget _deptStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bo\'limlar statistikasi',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        ..._deptStats.take(5).map((d) => _deptTile(d)),
      ],
    );
  }

  Widget _deptTile(Map d) {
    final total = (d['total'] ?? 1) as int;
    final completed = (d['completed'] ?? 0) as int;
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(d['department'] ?? '',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('$completed/$total',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSec)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              color: AppColors.success,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
