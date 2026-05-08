import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:dio/dio.dart' as dio_pkg;
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
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'
        ],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
      final name = result.files.first.name;
      final size = result.files.first.size;

      if (size > 10 * 1024 * 1024) {
        if (mounted) {
          _showSnack(
              '❌ Fayl hajmi 10MB dan oshmasligi kerak', AppColors.error);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.bg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hujjatni o\'chirish',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? AppColors.darkText : AppColors.textPrimary)),
        content: Text('«$name» hujjatini o\'chirishni tasdiqlaysizmi?',
            style: TextStyle(
                fontSize: 14,
                color:
                    isDark ? AppColors.darkTextSec : AppColors.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Bekor qilish',
                style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSec
                        : AppColors.textSec)),
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
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _openFile(String filename, String originalName) async {
    final url = _api.getFileUrl(filename);
    if (url.isEmpty) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$originalName';
      final file = File(savePath);

      if (await file.exists()) {
        await OpenFile.open(savePath);
        return;
      }

      // Download
      _showSnack('📥 Fayl yuklanmoqda...', AppColors.accent);
      final dio = dio_pkg.Dio();
      await dio.download(url, savePath);

      await OpenFile.open(savePath);
    } catch (e) {
      if (mounted) {
        _showSnack('❌ Faylni ochib bo\'lmadi', AppColors.error);
      }
    }
  }

  void _showDocDetail(Map doc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DocDetailSheet(
        doc: doc,
        isDark: isDark,
        onOpen: () => _openFile(doc['filename'] ?? '', doc['original_name'] ?? 'file'),
        onDelete: () {
          Navigator.pop(context);
          _deleteDoc(doc['id'], doc['original_name'] ?? '');
        },
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
            const Text('Hujjatlar'),
            if (_docs.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accentLight,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text('${_docs.length}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accentText)),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2))
          : Column(
              children: [
                _uploadBanner(isDark),
                Expanded(
                  child: _docs.isEmpty
                      ? _emptyState(isDark)
                      : RefreshIndicator(
                          color: AppColors.accent,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) =>
                                _docTile(_docs[i], isDark),
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

  Widget _uploadBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkAccent.withOpacity(0.1)
            : AppColors.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark
                ? AppColors.darkAccent.withOpacity(0.2)
                : AppColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(isDark ? 0.2 : 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.info_outline_rounded,
                size: 18,
                color: isDark ? AppColors.darkAccent : AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Qo\'llab-quvvatlanadigan formatlar',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkAccent
                            : AppColors.accent)),
                const SizedBox(height: 2),
                Text('PDF, DOC, DOCX, TXT, JPG, PNG • Max 10MB',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSec
                            : AppColors.textSec)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _docTile(Map doc, bool isDark) {
    final name = doc['original_name'] ?? 'Noma\'lum';
    final type = doc['file_type'] ?? '';
    final size = doc['file_size'] ?? 0;
    final createdAt = _formatDate(doc['created_at']);
    final tileColor = isDark ? AppColors.darkSurface : AppColors.bg;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return GestureDetector(
      onTap: () => _showDocDetail(doc),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _fileColor(type).withOpacity(isDark ? 0.2 : 0.1),
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
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _chip(_fileTypeName(type), _fileColor(type), isDark),
                      const SizedBox(width: 6),
                      Text(
                        _formatSize(size),
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSec
                                : AppColors.textHint),
                      ),
                      const Spacer(),
                      Text(
                        createdAt,
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSec
                                : AppColors.textHint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: isDark
                    ? AppColors.darkTextSec
                    : AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color, bool isDark) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color)),
      );

  Widget _emptyState(bool isDark) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.folder_open_outlined,
                  size: 32,
                  color: isDark
                      ? AppColors.darkTextSec
                      : AppColors.textHint),
            ),
            const SizedBox(height: 16),
            Text('Hujjatlar yo\'q',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSec
                        : AppColors.textSec)),
            const SizedBox(height: 6),
            Text('Fayl yuklash tugmasini bosing',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSec
                        : AppColors.textHint)),
          ],
        ),
      );

  IconData _fileIcon(String type) {
    if (type.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (type.contains('word') || type.contains('doc'))
      return Icons.description_rounded;
    if (type.contains('image') ||
        type.contains('jpg') ||
        type.contains('png')) return Icons.image_rounded;
    if (type.contains('text')) return Icons.text_snippet_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _fileColor(String type) {
    if (type.contains('pdf')) return AppColors.error;
    if (type.contains('word') || type.contains('doc'))
      return AppColors.accent;
    if (type.contains('image') ||
        type.contains('jpg') ||
        type.contains('png')) return AppColors.success;
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
    if (bytes < 1024 * 1024)
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
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
  final VoidCallback onOpen;
  final bool isDark;

  const _DocDetailSheet({
    required this.doc,
    required this.onDelete,
    required this.onOpen,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final name = doc['original_name'] ?? 'Noma\'lum';
    final type = doc['file_type'] ?? '';
    final size = doc['file_size'] ?? 0;
    final createdAt = _formatDate(doc['created_at']);
    final fileColor = _fileColor(type);
    final fileIcon = _fileIcon(type);
    final bgColor = isDark ? AppColors.darkSurface : AppColors.bg;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final surfaceColor =
        isDark ? AppColors.darkSurface2 : AppColors.surface;
    final textColor =
        isDark ? AppColors.darkText : AppColors.textPrimary;
    final hintColor =
        isDark ? AppColors.darkTextSec : AppColors.textHint;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
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
                color: borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: fileColor.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(fileIcon, size: 30, color: fileColor),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _row(Icons.insert_drive_file_outlined, 'Fayl turi',
                    _fileTypeName(type), hintColor, textColor),
                Divider(height: 1, indent: 46, color: borderColor),
                _row(Icons.data_usage_rounded, 'Hajmi',
                    _formatSize(size), hintColor, textColor),
                Divider(height: 1, indent: 46, color: borderColor),
                _row(Icons.calendar_today_outlined, 'Yuklangan sana',
                    createdAt, hintColor, textColor),
                if (doc['id'] != null) ...[
                  Divider(height: 1, indent: 46, color: borderColor),
                  _row(Icons.tag_rounded, 'ID', '#${doc['id']}',
                      hintColor, textColor),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: borderColor),
          const SizedBox(height: 8),
          // "Ochish" tugmasi — Tez orada!
          // "Ochish" tugmasi
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.white),
              label: const Text('Hujjatni ochish'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 4),
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

  Widget _row(IconData icon, String label, String value, Color hintColor,
      Color textColor) =>
      Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: hintColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          TextStyle(fontSize: 11, color: hintColor)),
                  const SizedBox(height: 2),
                  Text(value,
                      style:
                          TextStyle(fontSize: 14, color: textColor)),
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
    if (type.contains('word') || type.contains('doc'))
      return AppColors.accent;
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
    if (bytes < 1024 * 1024)
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return raw;
    }
  }
}
