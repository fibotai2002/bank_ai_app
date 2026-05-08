import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

class AddEmployeeSheet extends StatefulWidget {
  final ApiClient api;
  final VoidCallback onCreated;

  const AddEmployeeSheet({
    super.key,
    required this.api,
    required this.onCreated,
  });

  @override
  State<AddEmployeeSheet> createState() => _AddEmployeeSheetState();
}

class _AddEmployeeSheetState extends State<AddEmployeeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _posCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String _role = 'employee';
  int? _deptId;
  List<dynamic> _depts = [];
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDepts();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    _posCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDepts() async {
    setState(() => _loading = true);
    try {
      final res = await widget.api.getDepartments();
      setState(() => _depts = res);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _saving = true);
    try {
      await widget.api.createUser({
        'full_name': _nameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'password': _passCtrl.text.trim(),
        'role': _role,
        'department_id': _deptId,
        'position': _posCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      });
      
      widget.onCreated();
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Xodim muvaffaqiyatli qo\'shildi: ${_nameCtrl.text}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Xatolik yuz berdi. Username band bo\'lishi mumkin.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : AppColors.bg;
    final textColor = isDark ? AppColors.darkText : AppColors.textPrimary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Yangi xodim qo\'shish',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              
              // To'liq ism
              _label('To\'liq ism-sharif *', isDark),
              TextFormField(
                controller: _nameCtrl,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: _inputDec('Masalan: Aliyev Vali', Icons.person_outline, isDark),
                validator: (v) => v!.isEmpty ? 'Ismni kiriting' : null,
              ),
              const SizedBox(height: 16),

              // Username va Parol (Row)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Username *', isDark),
                        TextFormField(
                          controller: _usernameCtrl,
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: _inputDec('vali123', Icons.alternate_email, isDark),
                          validator: (v) => v!.isEmpty ? 'Username zarur' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Parol *', isDark),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: true,
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: _inputDec('••••••', Icons.lock_outline, isDark),
                          validator: (v) => v!.length < 6 ? 'Kamida 6 ta' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bo'lim va Lavozim (Row)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Bo\'lim *', isDark),
                        _loading 
                          ? const LinearProgressIndicator()
                          : DropdownButtonFormField<int>(
                              value: _deptId,
                              dropdownColor: bgColor,
                              style: TextStyle(color: textColor, fontSize: 14),
                              decoration: _inputDec('Tanlang', Icons.business_outlined, isDark),
                              items: _depts.map((d) => DropdownMenuItem<int>(
                                value: d['id'],
                                child: Text(d['name'], overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (v) => setState(() => _deptId = v),
                              validator: (v) => v == null ? 'Tanlang' : null,
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Lavozim', isDark),
                        TextFormField(
                          controller: _posCtrl,
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: _inputDec('Bosh mutaxassis', Icons.work_outline, isDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Role
              _label('Tizimdagi roli', isDark),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'employee', label: Text('Xodim'), icon: Icon(Icons.person, size: 16)),
                  ButtonSegment(value: 'manager', label: Text('Manager'), icon: Icon(Icons.manage_accounts, size: 16)),
                  ButtonSegment(value: 'admin', label: Text('Admin'), icon: Icon(Icons.security, size: 16)),
                ],
                selected: {_role},
                onSelectionChanged: (v) => setState(() => _role = v.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.accent,
                  selectedForegroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(height: 16),

              // Telefon va Email (Row)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Telefon', isDark),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: _inputDec('+998...', Icons.phone_outlined, isDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Email', isDark),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: _inputDec('mail@bank.uz', Icons.email_outlined, isDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Saqlash tugmasi
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Saqlash', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkTextSec : AppColors.textSec,
      ),
    ),
  );

  InputDecoration _inputDec(String hint, IconData icon, bool isDark) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final fillColor = isDark ? AppColors.darkSurface2 : AppColors.surface;
    
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: isDark ? AppColors.darkTextSec : AppColors.textHint),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      errorStyle: const TextStyle(fontSize: 10),
    );
  }
}
