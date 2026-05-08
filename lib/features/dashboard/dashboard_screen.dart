import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
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
  List<dynamic> _weeklyStats = [];
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
        _api.getWeeklyStats(),
        if (_role == 'admin') _api.getDepartmentStats(),
      ]);
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        final tasks = results[1] as List;
        _recentTasks = tasks.take(5).toList();
        _weeklyStats = results[2] as List;
        if (_role == 'admin' && results.length > 3) {
          _deptStats = results[3] as List;
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
      case 'admin':
        return '👑 Admin';
      case 'manager':
        return '🏢 Manager';
      default:
        return '👤 Xodim';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.bg;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: const Text('Bosh sahifa'),
        actions: [
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
          : RefreshIndicator(
              color: AppColors.accent,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _greetingCard(isDark),
                    const SizedBox(height: 20),
                    _aiInsightsPanel(isDark),
                    const SizedBox(height: 20),
                    if (_stats != null) _statsGrid(isDark),
                    const SizedBox(height: 20),
                    if (_stats != null) _chartsSection(isDark),
                    const SizedBox(height: 20),
                    _quickActions(isDark),
                    const SizedBox(height: 20),
                    if (_recentTasks.isNotEmpty) _recentTasksSection(isDark),
                    if (_role == 'admin' && _deptStats.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _deptStatsSection(isDark),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _greetingCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: AppColors.accent.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
        gradient: isDark
            ? LinearGradient(
                colors: [AppColors.darkSurface, AppColors.darkSurface2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [AppColors.accent, Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: isDark
            ? Border.all(color: AppColors.darkBorder)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_greeting,',
                      style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.darkTextSec
                              : Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fullName,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkText : Colors.white,
                          letterSpacing: -0.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBorder
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  _roleLabel,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : Colors.white),
                ),
              ),
            ],
          ),
          if (_deptName.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_rounded,
                      color: isDark
                          ? AppColors.darkTextSec
                          : Colors.white.withOpacity(0.8),
                      size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _deptName,
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkText : Colors.white,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statsGrid(bool isDark) {
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
            Icons.assignment_outlined, AppColors.accent, isDark),
        _statCard('Kutilmoqda', '${s['pending'] ?? 0}',
            Icons.hourglass_empty_rounded, AppColors.warning, isDark),
        _statCard('Jarayonda', '${s['in_progress'] ?? 0}',
            Icons.autorenew_rounded, AppColors.accent, isDark),
        _statCard('Bajarildi', '${s['completed'] ?? 0}',
            Icons.check_circle_outline, AppColors.success, isDark),
        if (_role == 'admin') ...[
          _statCard('Xodimlar', '${s['total_employees'] ?? 0}',
              Icons.people_outline_rounded, const Color(0xFF7C3AED), isDark),
          _statCard('Bo\'limlar', '${s['total_departments'] ?? 0}',
              Icons.business_outlined, const Color(0xFF0891B2), isDark),
        ],
      ],
    );
  }

  Widget _aiInsightsPanel(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? AppColors.darkBorder
                : AppColors.accent.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome,
                    color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI Insights',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _role == 'admin'
                ? (_stats != null && _stats!.isNotEmpty
                    ? 'Jami ${_stats!['total_tasks'] ?? 0} ta vazifadan ${_stats!['completed'] ?? 0} tasi bajarildi. Kutilayotgan: ${_stats!['pending'] ?? 0} ta.'
                    : 'AI tahlili yuklanmoqda...')
                : (_stats != null && _stats!.isNotEmpty
                    ? 'Sizda ${_stats!['pending'] ?? 0} ta kutilayotgan vazifa bor. AI yordamida samarali rejalashtiring.'
                    : 'AI tahlili yuklanmoqda...'),
            style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkText : AppColors.textPrimary,
                height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              Icon(Icons.trending_up,
                  size: 14, color: color.withOpacity(0.5)),
            ],
          ),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkText : AppColors.textPrimary,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextSec : AppColors.textHint),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _quickActions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tezkor amallar',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _actionBtn(
                Icons.checklist_rounded,
                'Vazifalar',
                AppColors.accent,
                widget.onNavigateToTasks,
                isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionBtn(
                Icons.smart_toy_rounded,
                'AI Chat',
                const Color(0xFF7C3AED),
                widget.onNavigateToChat,
                isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color,
      VoidCallback? onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 26, color: color),
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

  Widget _recentTasksSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('So\'nggi vazifalar',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? AppColors.darkText : AppColors.textPrimary)),
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
        ..._recentTasks.map((t) => _miniTaskTile(t, isDark)),
      ],
    );
  }

  Widget _miniTaskTile(Map t, bool isDark) {
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
        color: isDark ? AppColors.darkSurface : AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border),
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
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if ((t['assignee_name'] ?? '').isNotEmpty)
                  Text(t['assignee_name'],
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSec
                              : AppColors.textSec)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
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

  Widget _deptStatsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bo\'limlar statistikasi',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.textPrimary)),
        const SizedBox(height: 10),
        ..._deptStats.take(5).map((d) => _deptTile(d, isDark)),
      ],
    );
  }

  Widget _deptTile(Map d, bool isDark) {
    final total = (d['total'] ?? 1) as int;
    final completed = (d['completed'] ?? 0) as int;
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(d['department'] ?? '',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('$completed/$total',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSec
                          : AppColors.textSec)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor:
                  isDark ? AppColors.darkBorder : AppColors.border,
              color: AppColors.success,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  Widget _chartsSection(bool isDark) {
    final s = _stats!;
    final total = (s['total_tasks'] ?? 0) as int;
    if (total == 0) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Grafik tahlillar',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.textPrimary)),
        const SizedBox(height: 12),
        Row(
          children: [
            // Pie Chart - Task Distribution
            Expanded(
              flex: 3,
              child: Container(
                height: 180,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text('Vazifalar taqsimoti', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 25,
                          sections: [
                            PieChartSectionData(
                              value: (s['completed'] ?? 0).toDouble(),
                              color: AppColors.success,
                              radius: 12,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: (s['in_progress'] ?? 0).toDouble(),
                              color: AppColors.accent,
                              radius: 12,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: (s['pending'] ?? 0).toDouble(),
                              color: AppColors.warning,
                              radius: 12,
                              showTitle: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _dot(AppColors.success, 'B'),
                        const SizedBox(width: 8),
                        _dot(AppColors.accent, 'J'),
                        const SizedBox(width: 8),
                        _dot(AppColors.warning, 'K'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Bar Chart - Weekly Activity
            Expanded(
              flex: 4,
              child: Container(
                height: 180,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text('Haftalik faollik', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 20),
                    Expanded(
                      child: BarChart(
                        BarChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, meta) {
                                  if (val < 0 || val >= _weeklyStats.length) return const Text('');
                                  return Text(_weeklyStats[val.toInt()]['day_name'] ?? '', style: const TextStyle(fontSize: 8));
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(_weeklyStats.length, (i) {
                            final d = _weeklyStats[i];
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: (d['created'] ?? 0).toDouble(),
                                  color: AppColors.accent.withOpacity(0.4),
                                  width: 4,
                                ),
                                BarChartRodData(
                                  toY: (d['completed'] ?? 0).toDouble(),
                                  color: AppColors.success,
                                  width: 4,
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dot(Color color, String label) => Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 9)),
        ],
      );
}
