import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _api = ApiClient();
  List<dynamic> _users = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getUsers();
      setState(() {
        _users = res;
        _applyFilter();
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _applyFilter() {
    if (_search.isEmpty) {
      _filtered = List.from(_users);
    } else {
      final q = _search.toLowerCase();
      _filtered = _users.where((u) {
        final name = (u['full_name'] ?? '').toLowerCase();
        final dept = (u['department_name'] ?? '').toLowerCase();
        final pos = (u['position'] ?? '').toLowerCase();
        return name.contains(q) || dept.contains(q) || pos.contains(q);
      }).toList();
    }
  }

  // Bo'limlar bo'yicha guruhlash
  Map<String, List<dynamic>> get _grouped {
    final map = <String, List<dynamic>>{};
    for (final u in _filtered) {
      final dept = u['department_name'] ?? 'Boshqa';
      map.putIfAbsent(dept, () => []).add(u);
    }
    return map;
  }

  void _showDetail(Map user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailSheet(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Xodimlar'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('${_users.length}',
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
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(57),
          child: Column(
            children: [
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() {
                    _search = v;
                    _applyFilter();
                  }),
                  decoration: const InputDecoration(
                    hintText: 'Ism, bo\'lim yoki lavozim...',
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 18, color: AppColors.textHint),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2))
          : _filtered.isEmpty
              ? _empty()
              : RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSec,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '(${entry.value.length})',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textHint),
                                ),
                              ],
                            ),
                          ),
                          ...entry.value.map((u) => _userTile(u)),
                          const SizedBox(height: 12),
                        ],
                      );
                    }).toList(),
                  ),
                ),
    );
  }

  Widget _userTile(Map u) {
    final name = u['full_name'] ?? 'Noma\'lum';
    final pos = u['position'] ?? '';
    final role = u['role'] ?? 'employee';
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    final roleColor = role == 'admin'
        ? AppColors.error
        : role == 'manager'
            ? AppColors.accent
            : AppColors.success;

    final roleLabel = role == 'admin'
        ? 'Admin'
        : role == 'manager'
            ? 'Manager'
            : 'Xodim';

    return GestureDetector(
      onTap: () => _showDetail(Map<String, dynamic>.from(u)),
      child: Container(
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  if (pos.isNotEmpty)
                    Text(pos,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSec)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(roleLabel,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: roleColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.people_outline_rounded,
                size: 48, color: AppColors.textHint),
            SizedBox(height: 12),
            Text('Xodimlar topilmadi',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSec)),
          ],
        ),
      );
}

// ── User Detail Sheet ─────────────────────────────────────────────────────────
class _UserDetailSheet extends StatelessWidget {
  final Map user;
  const _UserDetailSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user['full_name'] ?? 'Noma\'lum';
    final role = user['role'] ?? 'employee';
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    final roleColor = role == 'admin'
        ? AppColors.error
        : role == 'manager'
            ? AppColors.accent
            : AppColors.success;
    final roleLabel = role == 'admin'
        ? '👑 Admin'
        : role == 'manager'
            ? '🏢 Manager'
            : '👤 Xodim';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
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
          const SizedBox(height: 20),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(initials.isEmpty ? '?' : initials,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent)),
          ),
          const SizedBox(height: 12),
          Text(name,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: roleColor.withOpacity(0.3)),
            ),
            child: Text(roleLabel,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: roleColor)),
          ),
          const SizedBox(height: 20),
          _infoRow(Icons.business_outlined, 'Bo\'lim',
              user['department_name'] ?? '—'),
          _infoRow(Icons.work_outline, 'Lavozim', user['position'] ?? '—'),
          _infoRow(Icons.person_outline, 'Username', user['username'] ?? '—'),
          if ((user['phone'] ?? '').isNotEmpty)
            _infoRow(Icons.phone_outlined, 'Telefon', user['phone']),
          if ((user['email'] ?? '').isNotEmpty)
            _infoRow(Icons.email_outlined, 'Email', user['email']),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textHint),
            const SizedBox(width: 12),
            Text('$label: ',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSec)),
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
}
