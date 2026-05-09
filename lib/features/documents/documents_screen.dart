import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

class PdfViewerScreen extends StatelessWidget {
  final String path;
  final String name;
  const PdfViewerScreen({super.key, required this.path, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(name, style: const TextStyle(fontSize: 16)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: PDFView(
        filePath: path,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: false,
        pageFling: true,
        pageSnap: true,
        fitPolicy: FitPolicy.BOTH,
      ),
    );
  }
}

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  List<dynamic> _docs = [];
  bool _loading = true;
  bool _uploading = false;
  int _telegramId = 0;
  AnimationController? _pulseCtrl;
  Animation<double>? _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl!, curve: Curves.easeInOut),
    );
    _init();
  }

  @override
  void dispose() {
    _pulseCtrl?.dispose();
    super.dispose();
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

      if (size > 10 * 1024 * 1024) {
        if (mounted) _showSnack('Fayl hajmi 10MB dan oshmasligi kerak', AppColors.error, CupertinoIcons.xmark_circle_fill);
        return;
      }

      setState(() => _uploading = true);
      await _api.uploadDocument(file, _telegramId);
      await _load();
      if (mounted) _showSnack('$name muvaffaqiyatli yuklandi', AppColors.success, CupertinoIcons.checkmark_circle_fill);
    } catch (_) {
      if (mounted) _showSnack('Fayl yuklashda xatolik', AppColors.error, CupertinoIcons.xmark_circle_fill);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showSnack(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _deleteDoc(int id, String name) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Hujjatni o\'chirish'),
        content: Text('«$name» o\'chirilsinmi?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bekor'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _api.deleteDocument(id);
        await _load();
        if (mounted) _showSnack('Hujjat o\'chirildi', AppColors.textSec, CupertinoIcons.trash);
      } catch (_) {}
    }
  }

  Future<void> _openFile(String filename, String originalName) async {
    if (filename.isEmpty) return;
    try {
      final url = _api.getFileUrl(filename);
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$originalName';
      final file = File(savePath);
      
      if (!await file.exists()) {
        _showSnack('Yuklanmoqda...', AppColors.accent, CupertinoIcons.arrow_down_circle_fill);
        final d = dio_pkg.Dio();
        await d.download(url, savePath);
      }
      
      if (originalName.toLowerCase().endsWith('.pdf') && mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PdfViewerScreen(path: savePath, name: originalName)
        ));
      } else {
        await OpenFile.open(savePath);
      }
    } catch (_) {
      if (mounted) _showSnack('Faylni ochib bo\'lmadi', AppColors.error, CupertinoIcons.xmark_circle_fill);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.bg;
    final border = isDark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Row(children: [
          const Text('Hujjatlar'),
          if (_docs.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkAccent.withOpacity(0.15) : AppColors.accentLight,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('${_docs.length}', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkAccent : AppColors.accent,
              )),
            ),
          ],
        ]),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.arrow_clockwise, size: 20),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: border),
        ),
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : Column(children: [
              _uploadZone(isDark),
              Expanded(
                child: _docs.isEmpty
                    ? _emptyState(isDark)
                    : RefreshIndicator(
                        color: AppColors.accent,
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: _docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _docTile(_docs[i], isDark),
                        ),
                      ),
              ),
            ]),
    );
  }

  // ─── Upload Zone ──────────────────────────────────────────────────────────
  Widget _uploadZone(bool isDark) {
    final zoneChild = Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkAccent.withOpacity(0.06) : AppColors.accentLight.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkAccent.withOpacity(0.25) : AppColors.accent.withOpacity(0.3),
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: _uploading
          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              CupertinoActivityIndicator(color: isDark ? AppColors.darkAccent : AppColors.accent),
              const SizedBox(width: 10),
              Text('Yuklanmoqda...', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkAccent : AppColors.accent,
              )),
            ])
          : Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkAccent.withOpacity(0.15) : AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(CupertinoIcons.arrow_up_doc_fill, size: 24, color: isDark ? AppColors.darkAccent : AppColors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Fayl yuklash', style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkAccent : AppColors.accent,
                )),
                const SizedBox(height: 3),
                Text('PDF, DOC, DOCX, TXT, JPG, PNG • Max 10MB',
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSec : AppColors.textSec)),
              ])),
              Icon(CupertinoIcons.chevron_right,
                  size: 16, color: isDark ? AppColors.darkAccent.withOpacity(0.5) : AppColors.accent.withOpacity(0.5)),
            ]),
    );

    return GestureDetector(
      onTap: _uploading ? null : _pickAndUpload,
      child: _pulseAnim != null
          ? AnimatedBuilder(
              animation: _pulseAnim!,
              builder: (_, child) => Transform.scale(scale: _uploading ? _pulseAnim!.value : 1.0, child: child),
              child: zoneChild,
            )
          : zoneChild,
    );
  }

  // ─── Format chips ─────────────────────────────────────────────────────────
  Widget _formatChips(bool isDark) {
    final formats = [
      ('PDF', AppColors.error, CupertinoIcons.doc_fill),
      ('DOCX', AppColors.accent, CupertinoIcons.doc_text_fill),
      ('JPG', AppColors.success, CupertinoIcons.photo_fill),
      ('PNG', const Color(0xFF7C3AED), CupertinoIcons.photo_fill),
      ('TXT', AppColors.warning, CupertinoIcons.textformat),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(children: formats.map((f) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: f.$2.withOpacity(isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: f.$2.withOpacity(0.2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(f.$3, size: 11, color: f.$2),
            const SizedBox(width: 4),
            Text(f.$1, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: f.$2)),
          ]),
        ),
      )).toList()),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────────────
  Widget _emptyState(bool isDark) {
    return Column(children: [
      _formatChips(isDark),
      Expanded(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : AppColors.surfaceVar,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(CupertinoIcons.doc_on_doc,
                  size: 38, color: isDark ? AppColors.darkTextSec : AppColors.textHint),
            ),
            const SizedBox(height: 20),
            Text('Hujjatlar yo\'q', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.textPrimary,
            )),
            const SizedBox(height: 6),
            Text('Yuqoridagi tugmani bosib fayl yuklang',
                style: TextStyle(fontSize: 13,
                    color: isDark ? AppColors.darkTextSec : AppColors.textHint)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _pickAndUpload,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkAccent.withOpacity(0.15) : AppColors.accentLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppColors.darkAccent.withOpacity(0.3) : AppColors.accent.withOpacity(0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(CupertinoIcons.arrow_up_doc,
                      size: 18, color: isDark ? AppColors.darkAccent : AppColors.accent),
                  const SizedBox(width: 8),
                  Text('Birinchi faylni yuklash', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkAccent : AppColors.accent,
                  )),
                ]),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  // ─── Doc Tile ─────────────────────────────────────────────────────────────
  Widget _docTile(Map doc, bool isDark) {
    final name = doc['original_name'] ?? 'Noma\'lum';
    final type = doc['file_type'] ?? '';
    final size = doc['file_size'] ?? 0;
    final date = _formatDate(doc['created_at']);
    final color = _fileColor(type);
    final icon = _fileIcon(type);
    final label = _fileTypeName(type);

    return GestureDetector(
      onTap: () => _showDocDetail(doc),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.textPrimary,
              ), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                ),
                const SizedBox(width: 8),
                Text(_formatSize(size), style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSec : AppColors.textHint)),
                const Spacer(),
                Icon(CupertinoIcons.calendar, size: 11, color: isDark ? AppColors.darkTextSec : AppColors.textHint),
                const SizedBox(width: 3),
                Text(date, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSec : AppColors.textHint)),
              ]),
            ],
          )),
          const SizedBox(width: 8),
          Icon(CupertinoIcons.chevron_right, size: 16, color: isDark ? AppColors.darkTextSec : AppColors.textHint),
        ]),
      ),
    );
  }

  void _showDocDetail(Map doc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DocDetailSheet(
        doc: doc, isDark: isDark,
        onOpen: () => _openFile(doc['filename'] ?? '', doc['original_name'] ?? 'file'),
        onDelete: () { Navigator.pop(context); _deleteDoc(doc['id'], doc['original_name'] ?? ''); },
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  IconData _fileIcon(String t) {
    if (t.contains('pdf')) return CupertinoIcons.doc_fill;
    if (t.contains('word') || t.contains('doc')) return CupertinoIcons.doc_text_fill;
    if (t.contains('image') || t.contains('jpg') || t.contains('png')) return CupertinoIcons.photo_fill;
    if (t.contains('text')) return CupertinoIcons.textformat_alt;
    return CupertinoIcons.doc;
  }

  Color _fileColor(String t) {
    if (t.contains('pdf')) return AppColors.error;
    if (t.contains('word') || t.contains('doc')) return AppColors.accent;
    if (t.contains('image') || t.contains('jpg') || t.contains('png')) return AppColors.success;
    if (t.contains('text')) return AppColors.warning;
    return AppColors.textSec;
  }

  String _fileTypeName(String t) {
    if (t.contains('pdf')) return 'PDF';
    if (t.contains('docx') || (t.contains('word') && !t.contains('msword'))) return 'DOCX';
    if (t.contains('msword') || t.contains('doc')) return 'DOC';
    if (t.contains('jpeg') || t.contains('jpg')) return 'JPG';
    if (t.contains('png')) return 'PNG';
    if (t.contains('text')) return 'TXT';
    return 'FILE';
  }

  String _formatSize(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try { return DateFormat('dd.MM.yy').format(DateTime.parse(raw).toLocal()); } catch (_) { return ''; }
  }
}

// ── Doc Detail Sheet ──────────────────────────────────────────────────────────
class _DocDetailSheet extends StatelessWidget {
  final Map doc;
  final VoidCallback onDelete, onOpen;
  final bool isDark;
  const _DocDetailSheet({required this.doc, required this.onDelete, required this.onOpen, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final name = doc['original_name'] ?? 'Noma\'lum';
    final type = doc['file_type'] ?? '';
    final size = doc['file_size'] ?? 0;
    final date = _fmt(doc['created_at']);
    final color = _color(type);
    final icon = _icon(type);
    final bg = isDark ? AppColors.darkSurface : AppColors.bg;
    final surface = isDark ? AppColors.darkSurface2 : AppColors.surface;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final text = isDark ? AppColors.darkText : AppColors.textPrimary;
    final hint = isDark ? AppColors.darkTextSec : AppColors.textHint;

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        // Icon
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.18 : 0.1), borderRadius: BorderRadius.circular(20)),
          child: Icon(icon, size: 34, color: color),
        ),
        const SizedBox(height: 12),
        Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: text), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(_typeName(type), style: TextStyle(fontSize: 13, color: hint)),
        const SizedBox(height: 20),
        // Info rows
        Container(
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
          child: Column(children: [
            _row(CupertinoIcons.doc_text, 'Fayl turi', _typeName(type), hint, text),
            Divider(height: 1, indent: 48, color: border),
            _row(CupertinoIcons.arrow_down_circle, 'Hajmi', _size(size), hint, text),
            Divider(height: 1, indent: 48, color: border),
            _row(CupertinoIcons.calendar, 'Yuklangan', date, hint, text),
            if (doc['id'] != null) ...[
              Divider(height: 1, indent: 48, color: border),
              _row(CupertinoIcons.number, 'ID', '#${doc['id']}', hint, text),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        // Open button
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(14),
            padding: const EdgeInsets.symmetric(vertical: 14),
            onPressed: onOpen,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Icon(CupertinoIcons.eye_fill, size: 18, color: Colors.white),
              SizedBox(width: 8),
              Text('Hujjatni ochish', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        // Share button
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: isDark ? AppColors.darkSurface2 : AppColors.surfaceVar,
            borderRadius: BorderRadius.circular(14),
            padding: const EdgeInsets.symmetric(vertical: 14),
            onPressed: () {},
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(CupertinoIcons.share, size: 18, color: isDark ? AppColors.darkText : AppColors.textPrimary),
              const SizedBox(width: 8),
              Text('Ulashish', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkText : AppColors.textPrimary)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        // Delete
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 14),
            onPressed: onDelete,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Icon(CupertinoIcons.trash, size: 18, color: AppColors.error),
              SizedBox(width: 8),
              Text('Hujjatni o\'chirish', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.error)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _row(IconData icon, String label, String value, Color hint, Color text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(children: [
      Icon(icon, size: 18, color: hint),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: hint)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, color: text, fontWeight: FontWeight.w500)),
      ])),
    ]),
  );

  IconData _icon(String t) {
    if (t.contains('pdf')) return CupertinoIcons.doc_fill;
    if (t.contains('word') || t.contains('doc')) return CupertinoIcons.doc_text_fill;
    if (t.contains('image') || t.contains('jpg') || t.contains('png')) return CupertinoIcons.photo_fill;
    if (t.contains('text')) return CupertinoIcons.textformat_alt;
    return CupertinoIcons.doc;
  }

  Color _color(String t) {
    if (t.contains('pdf')) return AppColors.error;
    if (t.contains('word') || t.contains('doc')) return AppColors.accent;
    if (t.contains('image') || t.contains('jpg') || t.contains('png')) return AppColors.success;
    if (t.contains('text')) return AppColors.warning;
    return AppColors.textSec;
  }

  String _typeName(String t) {
    if (t.contains('pdf')) return 'PDF';
    if (t.contains('docx') || (t.contains('word') && !t.contains('msword'))) return 'DOCX';
    if (t.contains('msword')) return 'DOC';
    if (t.contains('jpeg') || t.contains('jpg')) return 'JPG';
    if (t.contains('png')) return 'PNG';
    if (t.contains('text')) return 'TXT';
    return 'Fayl';
  }

  String _size(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _fmt(String? raw) {
    if (raw == null) return '';
    try { return DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(raw).toLocal()); } catch (_) { return raw; }
  }
}
