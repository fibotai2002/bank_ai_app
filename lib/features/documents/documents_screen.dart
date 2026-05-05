import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _api = ApiClient();
  List<dynamic> _docs = [];
  bool _loading = true;
  bool _uploading = false;
  int _telegramId = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _telegramId = prefs.getInt('telegram_id') ?? 0;
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getDocuments();
      setState(() => _docs = res);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _pickAndUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
      final name = result.files.first.name;
      final size = result.files.first.size;

      // Hajm tekshirish (10MB)
      if (size > 10 * 1024 * 1024) {
        if (mounted) {
          _showSnack('❌ Fayl hajmi 10MB dan oshmasligi kerak', AppColors.error);
        }
        return;
      }

      setState(() => _uploading = true);

      await _api.uploadDocument(file, _telegramId);
      await _load();

      if (mounted) {
        _showSnack('✅ $name muvaffaqiyatli yuklandi', AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('❌ Fayl yuklashda xatolik yuz berdi', AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteDoc(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hujjatni o\'chirish',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        content: Text('«$name» hujjatini o\'chirishni tasdiqlaysizmi?',
            style: const TextStyle(fontSize: 14, color: AppColors.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bekor qilish',
                style: TextStyle(color: AppColors.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('O\'chirish',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _api.deleteDocument(id);
        await _load();
        if (mounted) {
          _showSnack('🗑️ Hujjat o\'chirildi', AppColors.textSec);
        }
      } catch (_) {}
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showDocDetail(Map doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DocDetailSheet(
        doc: doc,
        onDelete: () {
          Navigator.pop(context);
          _deleteDoc(doc['id'], doc['original_name'] ?? '');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Hujjatlar'),
            if (_docs.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text('${_docs.length}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent)),
              ),
            ],
          ],
        ),
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
          : Column(
              children: [
                // Upload banner
                _uploadBanner(),
                // List
                Expanded(
                  child: _docs.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          color: AppColors.accent,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) => _docTile(_docs[i]),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _pickAndUpload,
        backgroundColor: AppColors.accent,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.upload_file_rounded, color: Colors.white),
        label: Text(
          _uploading ? 'Yuklanmoqda...' : 'Fayl yuklash',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _uploadBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline_rounded,
                size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Qo\'llab-quvvatlanadigan formatlar',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent)),
                SizedBox(height: 2),
                Text('PDF, DOC, DOCX, TXT, JPG, PNG • Max 10MB',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSec)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _docTile(Map doc) {
    final name = doc['original_name'] ?? 'Noma\'lum';
    final type = doc['file_type'] ?? '';
    final size = doc['file_size'] ?? 0;
    final createdAt = _formatDate(doc['created_at']);

    return GestureDetector(
      onTap: () => _showDocDetail(doc),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // File icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _fileColor(type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_fileIcon(type),
                  size: 22, color: _fileColor(type)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _chip(_fileTypeName(type), _fileColor(type)),
                      const SizedBox(width: 6),
                      Text(
                        _formatSize(size),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint),
                      ),
                      const Spacer(),
                      Text(
                        createdAt,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color)),
      );

  Widget _emptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.folder_open_outlined,
                  size: 32, color: AppColors.textHint),
            ),
            const SizedBox(height: 16),
            const Text('Hujjatlar yo\'q',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSec)),
            const SizedBox(height: 6),
            const Text('Fayl yuklash tugmasini bosing',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textHint)),
          ],
        ),
      );

  IconData _fileIcon(String type) {
    if (type.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (type.contains('word') || type.contains('doc'))
      return Icons.description_rounded;
    if (type.contains('image') || type.contains('jpg') || type.contains('png'))
      return Icons.image_rounded;
    if (type.contains('text')) return Icons.text_snippet_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _fileColor(String type) {
    if (type.contains('pdf')) return AppColors.error;
    if (type.contains('word') || type.contains('doc'))
      return AppColors.accent;
    if (type.contains('image') || type.contains('jpg') || type.contains('png'))
      return AppColors.success;
    if (type.contains('text')) return AppColors.warning;
    return AppColors.textSec;
  }

  String _fileTypeName(String type) {
    if (type.contains('pdf')) return 'PDF';
    if (type.contains('word') || type.contains('docx')) return 'DOCX';
    if (type.contains('msword')) return 'DOC';
    if (type.contains('jpeg') || type.contains('jpg')) return 'JPG';
    if (type.contains('png')) return 'PNG';
    if (type.contains('text')) return 'TXT';
    return 'FILE';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd.MM.yy').format(dt);
    } catch (_) {
      return '';
    }
  }
}

// ── Doc Detail Sheet ──────────────────────────────────────────────────────────
class _DocDetailSheet extends StatelessWidget {
  final Map doc;
  final VoidCallback onDelete;

  const _DocDetailSheet({required this.doc, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = doc['original_name'] ?? 'Noma\'lum';
    final type = doc['file_type'] ?? '';
    final size = doc['file_size'] ?? 0;
    final createdAt = _formatDate(doc['created_at']);

    final fileColor = _fileColor(type);
    final fileIcon = _fileIcon(type);

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
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: fileColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(fileIcon, size: 30, color: fileColor),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _row(Icons.insert_drive_file_outlined, 'Fayl turi',
                    _fileTypeName(type)),
                const Divider(
                    height: 1, indent: 46, color: AppColors.border),
                _row(Icons.data_usage_rounded, 'Hajmi',
                    _formatSize(size)),
                const Divider(
                    height: 1, indent: 46, color: AppColors.border),
                _row(Icons.calendar_today_outlined, 'Yuklangan sana',
                    createdAt),
                if (doc['id'] != null) ...[
                  const Divider(
                      height: 1, indent: 46, color: AppColors.border),
                  _row(Icons.tag_rounded, 'ID', '#${doc['id']}'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppColors.error),
              label: const Text('Hujjatni o\'chirish',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.error)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textHint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      );

  IconData _fileIcon(String type) {
    if (type.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (type.contains('word') || type.contains('doc'))
      return Icons.description_rounded;
    if (type.contains('image')) return Icons.image_rounded;
    if (type.contains('text')) return Icons.text_snippet_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _fileColor(String type) {
    if (type.contains('pdf')) return AppColors.error;
    if (type.contains('word') || type.contains('doc')) return AppColors.accent;
    if (type.contains('image')) return AppColors.success;
    if (type.contains('text')) return AppColors.warning;
    return AppColors.textSec;
  }

  String _fileTypeName(String type) {
    if (type.contains('pdf')) return 'PDF';
    if (type.contains('word') || type.contains('docx')) return 'DOCX';
    if (type.contains('msword')) return 'DOC';
    if (type.contains('jpeg') || type.contains('jpg')) return 'JPG';
    if (type.contains('png')) return 'PNG';
    if (type.contains('text')) return 'TXT';
    return 'FILE';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return raw ?? '';
    }
  }
}
