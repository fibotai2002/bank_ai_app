import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  late TabController _tabs;
  List<dynamic> _tasks = [];
  bool _loading = true;
  String _role = 'employee';
  int _userId = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _role = prefs.getString('role') ?? 'employee';
    _userId = prefs.getInt('user_id') ?? 0;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getTasks();
      setState(() => _tasks = res);
    } catch (_) {}
    setState(() => _loading = false);
  }

  List<dynamic> _filtered(String? status) {
    if (status == null) return _tasks;
    return _tasks.where((t) => t['status'] == status).toList();
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      await _api.updateTaskStatus(id, status);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Holat yangilandi: ${_statusLabel(status)}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (_) {}
  }

  Future<void> _deleteTask(int id) async {
    try {
      await _api.deleteTask(id);
      _load();
    } catch (_) {}
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateTaskSheet(
        api: _api,
        onCreated: _load,
      ),
    );
  }

  void _showDetail(Map task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskDetailSheet(
        task: task,
        role: _role,
        onStatusChange: (status) => _updateStatus(task['id'], status),
        onDelete: _role != 'employee'
            ? () => _deleteTask(task['id'])
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.bg;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final accentLight =
        isDark ? AppColors.darkAccent.withOpacity(0.15) : AppColors.accentLight;
    final accentText = isDark ? AppColors.darkAccent : AppColors.accent;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Row(
          children: [
            const Text('Vazifalar'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accentLight,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('${_tasks.length}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accentText)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _load,
          ),
          if (_role != 'employee')
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 22),
              onPressed: _showCreateSheet,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: isDark ? AppColors.darkAccent : AppColors.accent,
          unselectedLabelColor:
              isDark ? AppColors.darkTextSec : AppColors.textHint,
          indicatorColor: isDark ? AppColors.darkAccent : AppColors.accent,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Barchasi (${_tasks.length})'),
            Tab(text: 'Kutmoqda (${_filtered("pending").length})'),
            Tab(text: 'Jarayonda (${_filtered("in_progress").length})'),
            Tab(text: 'Bajarildi (${_filtered("completed").length})'),
            Tab(text: 'Rad etildi (${_filtered("rejected").length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2))
          : TabBarView(
              controller: _tabs,
              children: [
                _taskList(null, isDark),
                _taskList('pending', isDark),
                _taskList('in_progress', isDark),
                _taskList('completed', isDark),
                _taskList('rejected', isDark),
              ],
            ),
      floatingActionButton: _role != 'employee'
          ? FloatingActionButton(
              onPressed: _showCreateSheet,
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _taskList(String? status, bool isDark) {
    final list = _filtered(status);
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checklist_rounded,
                size: 52,
                color: isDark ? AppColors.darkTextSec : AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              status == null
                  ? 'Vazifalar yo\'q'
                  : '${_statusLabel(status)} vazifalar yo\'q',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color:
                      isDark ? AppColors.darkTextSec : AppColors.textSec),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _taskTile(list[i], isDark),
      ),
    );
  }

  Widget _taskTile(Map t, bool isDark) {
    final status = t['status'] ?? 'pending';
    final priority = t['priority'] ?? 'o\'rta';
    final statusColor = _statusColor(status);
    final priorityColor = _priorityColor(priority);
    final isCompleted = status == 'completed';

    // Deadline countdown
    String? deadlineLabel;
    Color deadlineColor = isDark ? AppColors.darkTextSec : AppColors.textHint;
    if ((t['deadline'] ?? '').isNotEmpty) {
      try {
        final deadline = DateTime.parse(t['deadline']);
        final now = DateTime.now();
        final diff = deadline
            .difference(DateTime(now.year, now.month, now.day))
            .inDays;
        if (diff < 0) {
          deadlineLabel = '${diff.abs()} kun o\'tdi';
          deadlineColor = AppColors.error;
        } else if (diff == 0) {
          deadlineLabel = 'Bugun!';
          deadlineColor = AppColors.error;
        } else if (diff == 1) {
          deadlineLabel = 'Ertaga';
          deadlineColor = AppColors.warning;
        } else if (diff <= 3) {
          deadlineLabel = '$diff kun qoldi';
          deadlineColor = AppColors.warning;
        } else {
          deadlineLabel = t['deadline'];
          deadlineColor =
              isDark ? AppColors.darkTextSec : AppColors.textHint;
        }
      } catch (_) {
        deadlineLabel = t['deadline'];
      }
    }

    final tileBg = isCompleted
        ? (isDark
            ? AppColors.success.withOpacity(0.06)
            : AppColors.success.withOpacity(0.04))
        : (isDark ? AppColors.darkSurface : AppColors.bg);
    final tileBorder = isCompleted
        ? AppColors.success.withOpacity(isDark ? 0.25 : 0.2)
        : (isDark ? AppColors.darkBorder : AppColors.border);

    return Dismissible(
      key: Key('task_${t['id']}'),
      direction: isCompleted
          ? DismissDirection.none
          : DismissDirection.startToEnd,
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text('Bajarildi',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _updateStatus(t['id'], 'completed');
        return false;
      },
      child: GestureDetector(
        onTap: () => _showDetail(Map<String, dynamic>.from(t)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tileBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: isCompleted
                        ? AppColors.success
                        : (isDark
                            ? AppColors.darkTextSec
                            : AppColors.textHint),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t['title'] ?? '',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? (isDark
                                  ? AppColors.darkTextSec
                                  : AppColors.textSec)
                              : (isDark
                                  ? AppColors.darkText
                                  : AppColors.textPrimary),
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: isDark
                              ? AppColors.darkTextSec
                              : AppColors.textSec),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _badge(_statusLabel(status), statusColor, isDark),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if ((t['department'] ?? '').isNotEmpty) ...[
                    Icon(Icons.business_outlined,
                        size: 12,
                        color: isDark
                            ? AppColors.darkTextSec
                            : AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(t['department'],
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSec
                                : AppColors.textSec)),
                    const SizedBox(width: 12),
                  ],
                  _badge(priority, priorityColor, isDark),
                ],
              ),
              if ((t['assignee_name'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 12,
                        color: isDark
                            ? AppColors.darkTextSec
                            : AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(t['assignee_name'],
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSec
                                : AppColors.textSec)),
                  ],
                ),
              ],
              if (deadlineLabel != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      deadlineColor == AppColors.error
                          ? Icons.warning_amber_rounded
                          : Icons.calendar_today_outlined,
                      size: 12,
                      color: deadlineColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      deadlineLabel,
                      style: TextStyle(
                          fontSize: 11,
                          color: deadlineColor,
                          fontWeight: deadlineColor == AppColors.error
                              ? FontWeight.w600
                              : FontWeight.w400),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color, bool isDark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      );

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Kutmoqda';
      case 'in_progress':
        return 'Jarayonda';
      case 'completed':
        return 'Bajarildi';
      case 'rejected':
        return 'Rad etildi';
      default:
        return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return AppColors.warning;
      case 'in_progress':
        return AppColors.accent;
      case 'completed':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textHint;
    }
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'yuqori':
        return AppColors.error;
      case 'o\'rta':
        return AppColors.warning;
      case 'past':
        return AppColors.success;
      default:
        return AppColors.textHint;
    }
  }
}

// ── Task Detail Sheet ─────────────────────────────────────────────────────────
class _TaskDetailSheet extends StatelessWidget {
  final Map task;
  final String role;
  final Function(String) onStatusChange;
  final VoidCallback? onDelete;

  const _TaskDetailSheet({
    required this.task,
    required this.role,
    required this.onStatusChange,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : AppColors.bg;
    final textColor = isDark ? AppColors.darkText : AppColors.textPrimary;
    final subColor = isDark ? AppColors.darkTextSec : AppColors.textSec;
    final hintColor = isDark ? AppColors.darkTextSec : AppColors.textHint;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final status = task['status'] ?? 'pending';

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
            Text(task['title'] ?? '',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textColor)),
            const SizedBox(height: 12),
            if ((task['description'] ?? '').isNotEmpty) ...[
              Text(task['description'],
                  style: TextStyle(
                      fontSize: 13, color: subColor, height: 1.5)),
              const SizedBox(height: 12),
            ],
            _row(Icons.business_outlined, 'Bo\'lim',
                task['department'] ?? '—', hintColor, subColor, textColor),
            _row(Icons.person_outline, 'Mas\'ul',
                task['assignee_name'] ?? '—', hintColor, subColor, textColor),
            _row(Icons.person_add_outlined, 'Yaratdi',
                task['creator_name'] ?? '—', hintColor, subColor, textColor),
            _row(Icons.calendar_today_outlined, 'Muddat',
                task['deadline'] ?? '—', hintColor, subColor, textColor),
            _row(Icons.description_outlined, 'Hujjat',
                task['source_document'] ?? '—', hintColor, subColor, textColor),
            const SizedBox(height: 16),
            Text('Holatni o\'zgartirish:',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: subColor)),
            const SizedBox(height: 10),
            Row(
              children: [
                _statusBtn(context, 'pending', 'Kutmoqda',
                    AppColors.warning, status),
                const SizedBox(width: 8),
                _statusBtn(context, 'in_progress', 'Jarayonda',
                    AppColors.accent, status),
                const SizedBox(width: 8),
                _statusBtn(context, 'completed', 'Bajarildi',
                    AppColors.success, status),
              ],
            ),
            if (onDelete != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onDelete!();
                },
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: AppColors.error),
                label: const Text('O\'chirish',
                    style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, Color hintColor,
      Color subColor, Color textColor) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: hintColor),
            const SizedBox(width: 10),
            Text('$label: ',
                style: TextStyle(fontSize: 12, color: subColor)),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor)),
            ),
          ],
        ),
      );

  Widget _statusBtn(BuildContext context, String value, String label,
      Color color, String current) {
    final isActive = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: isActive
            ? null
            : () {
                Navigator.pop(context);
                onStatusChange(value);
              },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: isActive ? color : color.withOpacity(0.3)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Create Task Sheet ─────────────────────────────────────────────────────────
class _CreateTaskSheet extends StatefulWidget {
  final ApiClient api;
  final VoidCallback onCreated;
  const _CreateTaskSheet({required this.api, required this.onCreated});

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _deadlineCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  String _priority = 'o\'rta';
  String _status = 'pending';
  List<dynamic> _users = [];
  List<dynamic> _depts = [];
  int? _assigneeId;
  int? _deptId;
  String? _deptName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _deadlineCtrl.dispose();
    _docCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final users = await widget.api.getUsers();
      final depts = await widget.api.getDepartments();
      setState(() {
        _users = users;
        _depts = depts;
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.api.createTask({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'department': _deptName,
        'department_id': _deptId,
        'priority': _priority,
        'status': _status,
        'deadline': _deadlineCtrl.text.trim(),
        'source_document': _docCtrl.text.trim(),
        if (_assigneeId != null) 'assignee_id': _assigneeId,
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (_) {}
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : AppColors.bg;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkText : AppColors.textPrimary;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
            Text('Yangi vazifa',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textColor)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              style: TextStyle(color: textColor),
              decoration: const InputDecoration(hintText: 'Vazifa nomi *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              style: TextStyle(color: textColor),
              decoration:
                  const InputDecoration(hintText: 'Tavsif (ixtiyoriy)'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: _deptId,
              hint: const Text('Bo\'lim tanlang'),
              dropdownColor: bgColor,
              decoration: const InputDecoration(isDense: true),
              items: _depts
                  .map((d) => DropdownMenuItem<int>(
                        value: d['id'],
                        child: Text(d['name'],
                            style: TextStyle(
                                fontSize: 13, color: textColor)),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _deptId = v;
                  _deptName =
                      _depts.firstWhere((d) => d['id'] == v)['name'];
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: _assigneeId,
              hint: const Text('Mas\'ul xodim'),
              dropdownColor: bgColor,
              decoration: const InputDecoration(isDense: true),
              items: _users
                  .map((u) => DropdownMenuItem<int>(
                        value: u['id'],
                        child: Text(u['full_name'] ?? '',
                            style: TextStyle(
                                fontSize: 13, color: textColor)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _assigneeId = v),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _priority,
                    dropdownColor: bgColor,
                    decoration: const InputDecoration(
                        labelText: 'Muhimlik', isDense: true),
                    items: [
                      DropdownMenuItem(
                          value: 'yuqori',
                          child: Text('Yuqori',
                              style: TextStyle(color: textColor))),
                      DropdownMenuItem(
                          value: 'o\'rta',
                          child: Text('O\'rta',
                              style: TextStyle(color: textColor))),
                      DropdownMenuItem(
                          value: 'past',
                          child: Text('Past',
                              style: TextStyle(color: textColor))),
                    ],
                    onChanged: (v) => setState(() => _priority = v!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    dropdownColor: bgColor,
                    decoration: const InputDecoration(
                        labelText: 'Holat', isDense: true),
                    items: [
                      DropdownMenuItem(
                          value: 'pending',
                          child: Text('Kutmoqda',
                              style: TextStyle(color: textColor))),
                      DropdownMenuItem(
                          value: 'in_progress',
                          child: Text('Jarayonda',
                              style: TextStyle(color: textColor))),
                    ],
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _deadlineCtrl,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Muddat (YYYY-MM-DD)',
                prefixIcon: Icon(Icons.calendar_today_outlined,
                    size: 16,
                    color: isDark
                        ? AppColors.darkTextSec
                        : AppColors.textHint),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _docCtrl,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Manba hujjat (ixtiyoriy)',
                prefixIcon: Icon(Icons.description_outlined,
                    size: 16,
                    color: isDark
                        ? AppColors.darkTextSec
                        : AppColors.textHint),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}
