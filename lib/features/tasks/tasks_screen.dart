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
    _tabs = TabController(length: 4, vsync: this);
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
          content: Text('✅ Holat yangilandi: $status'),
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Vazifalar'),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('${_tasks.length}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent)),
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
          tabs: [
            Tab(text: 'Barchasi (${_tasks.length})'),
            Tab(text: 'Kutmoqda (${_filtered("pending").length})'),
            Tab(text: 'Jarayonda (${_filtered("in_progress").length})'),
            Tab(text: 'Bajarildi (${_filtered("completed").length})'),
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
                _taskList(null),
                _taskList('pending'),
                _taskList('in_progress'),
                _taskList('completed'),
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

  Widget _taskList(String? status) {
    final list = _filtered(status);
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.checklist_rounded,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              status == null
                  ? 'Vazifalar yo\'q'
                  : '${_statusLabel(status)} vazifalar yo\'q',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSec),
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
        itemBuilder: (_, i) => _taskTile(list[i]),
      ),
    );
  }

  Widget _taskTile(Map t) {
    final status = t['status'] ?? 'pending';
    final priority = t['priority'] ?? 'o\'rta';
    final statusColor = _statusColor(status);
    final priorityColor = _priorityColor(priority);

    return GestureDetector(
      onTap: () => _showDetail(Map<String, dynamic>.from(t)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                _badge(_statusLabel(status), statusColor),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if ((t['department'] ?? '').isNotEmpty) ...[
                  const Icon(Icons.business_outlined,
                      size: 12, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(t['department'],
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSec)),
                  const SizedBox(width: 12),
                ],
                _badge(priority, priorityColor),
              ],
            ),
            if ((t['assignee_name'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 12, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(t['assignee_name'],
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSec)),
                ],
              ),
            ],
            if ((t['deadline'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 12, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(t['deadline'],
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color)),
      );

  String _statusLabel(String s) {
    switch (s) {
      case 'pending': return 'Kutmoqda';
      case 'in_progress': return 'Jarayonda';
      case 'completed': return 'Bajarildi';
      default: return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending': return AppColors.warning;
      case 'in_progress': return AppColors.accent;
      case 'completed': return AppColors.success;
      default: return AppColors.textHint;
    }
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'yuqori': return AppColors.error;
      case 'o\'rta': return AppColors.warning;
      case 'past': return AppColors.success;
      default: return AppColors.textHint;
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
    final status = task['status'] ?? 'pending';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(task['title'] ?? '',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if ((task['description'] ?? '').isNotEmpty) ...[
              Text(task['description'],
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSec,
                      height: 1.5)),
              const SizedBox(height: 12),
            ],
            _row(Icons.business_outlined, 'Bo\'lim',
                task['department'] ?? '—'),
            _row(Icons.person_outline, 'Mas\'ul',
                task['assignee_name'] ?? '—'),
            _row(Icons.person_add_outlined, 'Yaratdi',
                task['creator_name'] ?? '—'),
            _row(Icons.calendar_today_outlined, 'Muddat',
                task['deadline'] ?? '—'),
            _row(Icons.description_outlined, 'Hujjat',
                task['source_document'] ?? '—'),
            const SizedBox(height: 16),
            const Text('Holatni o\'zgartirish:',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSec)),
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

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textHint),
            const SizedBox(width: 10),
            Text('$label: ',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSec)),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
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
            border: Border.all(
                color: isActive ? color : color.withOpacity(0.3)),
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Yangi vazifa',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(hintText: 'Vazifa nomi *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Tavsif (ixtiyoriy)'),
            ),
            const SizedBox(height: 10),
            // Bo'lim
            DropdownButtonFormField<int>(
              value: _deptId,
              hint: const Text('Bo\'lim tanlang'),
              decoration: const InputDecoration(isDense: true),
              items: _depts
                  .map((d) => DropdownMenuItem<int>(
                        value: d['id'],
                        child: Text(d['name'],
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _deptId = v;
                  _deptName = _depts
                      .firstWhere((d) => d['id'] == v)['name'];
                });
              },
            ),
            const SizedBox(height: 10),
            // Mas'ul xodim
            DropdownButtonFormField<int>(
              value: _assigneeId,
              hint: const Text('Mas\'ul xodim'),
              decoration: const InputDecoration(isDense: true),
              items: _users
                  .map((u) => DropdownMenuItem<int>(
                        value: u['id'],
                        child: Text(u['full_name'] ?? '',
                            style: const TextStyle(fontSize: 13)),
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
                    decoration: const InputDecoration(
                        labelText: 'Muhimlik', isDense: true),
                    items: const [
                      DropdownMenuItem(
                          value: 'yuqori', child: Text('Yuqori')),
                      DropdownMenuItem(
                          value: 'o\'rta', child: Text('O\'rta')),
                      DropdownMenuItem(
                          value: 'past', child: Text('Past')),
                    ],
                    onChanged: (v) => setState(() => _priority = v!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(
                        labelText: 'Holat', isDense: true),
                    items: const [
                      DropdownMenuItem(
                          value: 'pending', child: Text('Kutmoqda')),
                      DropdownMenuItem(
                          value: 'in_progress',
                          child: Text('Jarayonda')),
                    ],
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _deadlineCtrl,
              decoration: const InputDecoration(
                hintText: 'Muddat (YYYY-MM-DD)',
                prefixIcon: Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.textHint),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _docCtrl,
              decoration: const InputDecoration(
                hintText: 'Manba hujjat (ixtiyoriy)',
                prefixIcon: Icon(Icons.description_outlined,
                    size: 16, color: AppColors.textHint),
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
