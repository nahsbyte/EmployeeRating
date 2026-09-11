import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/class_info.dart';
import '../../data/models/user_option.dart';
import '../../data/services/class_service.dart';
import '../widgets/empty_state_card.dart';

class ClassManageScreen extends StatefulWidget {
  const ClassManageScreen({super.key});

  @override
  State<ClassManageScreen> createState() => ClassManageScreenState();
}

class ClassManageScreenState extends State<ClassManageScreen> {
  late final ClassService _service;
  bool _loading = true;
  String? _error;
  List<ClassInfo> _classes = [];
  List<UserOption> _waliOptions = [];

  @override
  void initState() {
    super.initState();
    _service = ClassService(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final classes = await _service.fetchClasses();
      if (!mounted) return;
      setState(() => _classes = classes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> refreshIfEmpty() async {
    if (_loading) return;
    if (_classes.isEmpty) await _load();
  }

  Future<void> _loadWaliOptions({bool forceRefresh = false}) async {
    if (!forceRefresh && _waliOptions.isNotEmpty) return;
    final data = await _service.fetchWaliOptions();
    if (!mounted) return;
    setState(() => _waliOptions = data);
  }

  Future<void> _openEditor({ClassInfo? existing}) async {
    await _loadWaliOptions(forceRefresh: true);
    final classIdCtrl = TextEditingController(text: existing?.id ?? '');
    final classNameCtrl = TextEditingController(text: existing?.name ?? '');
    String? selectedWaliId = existing?.waliUserId;
    if (selectedWaliId != null &&
        !_waliOptions.any((wali) => wali.id == selectedWaliId)) {
      selectedWaliId = null;
    }
    bool saving = false;
    bool loadingWali = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final safeBottom = MediaQuery.of(context).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(
            bottom: bottomInset + safeBottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F7),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final waliOptions = _waliOptions.toList();
                final waliIds = waliOptions.map((w) => w.id).toSet();
                final resolvedWaliId =
                    waliIds.contains(selectedWaliId) ? selectedWaliId : null;
                Future<void> reloadWaliOptions() async {
                  if (loadingWali) return;
                  setModalState(() => loadingWali = true);
                  try {
                    await _loadWaliOptions(forceRefresh: true);
                  } finally {
                    if (context.mounted) {
                      setModalState(() => loadingWali = false);
                    }
                  }
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      existing == null ? 'Tambah Kelas' : 'Edit Kelas',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Data wali kelas',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3A3A3C),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh wali',
                          onPressed: loadingWali ? null : reloadWaliOptions,
                          icon: loadingWali
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    TextField(
                      controller: classIdCtrl,
                      enabled: existing == null,
                      decoration: const InputDecoration(
                        labelText: 'Class ID (contoh: 10C)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: classNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama kelas (opsional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: resolvedWaliId,
                      decoration: const InputDecoration(
                        labelText: 'Wali kelas',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('-'),
                        ),
                        ...waliOptions.map(
                          (wali) => DropdownMenuItem(
                            value: wali.id,
                            child: Text(wali.name),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setModalState(() => selectedWaliId = value),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                final classId = classIdCtrl.text.trim();
                                if (classId.isEmpty) {
                                  setModalState(
                                    () => error = 'Class ID wajib diisi.',
                                  );
                                  return;
                                }
                                setModalState(() {
                                  saving = true;
                                  error = null;
                                });
                                try {
                                  final safeWaliId =
                                      waliIds.contains(selectedWaliId)
                                          ? selectedWaliId
                                          : null;
                                  await _service.upsertClass(
                                    classId: classId,
                                    className: classNameCtrl.text.trim().isEmpty
                                        ? null
                                        : classNameCtrl.text.trim(),
                                    waliUserId: safeWaliId,
                                  );
                                  if (context.mounted) Navigator.pop(context);
                                  await _load();
                                } catch (e) {
                                  setModalState(() => error = e.toString());
                                } finally {
                                  if (context.mounted) {
                                    setModalState(() => saving = false);
                                  }
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Simpan',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(ClassInfo info) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus kelas?'),
          content: Text('Kelas ${info.id} akan dihapus.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _service.deleteClass(info.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'Kelas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Kelola kelas dan tetapkan wali kelas untuk proses siswa/wali.',
          style: TextStyle(
            color: Color(0xFFB8B8C0),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        _InfoBanner(onAdd: _openEditor),
        const SizedBox(height: 12),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(
            child: Center(
              child: Text(
                'Error: $_error',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          )
        else if (_classes.isEmpty)
          Expanded(
            child: EmptyStateCard(
              icon: Icons.class_outlined,
              title: 'Belum ada data kelas.',
              subtitle: 'Buat kelas terlebih dahulu lalu tetapkan wali kelas.',
              actionLabel: 'Tambah kelas',
              onAction: _openEditor,
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _classes.length,
              itemBuilder: (context, index) {
                final info = _classes[index];
                return _ClassCard(
                  info: info,
                  onTap: () => _openEditor(existing: info),
                  onDelete: () => _confirmDelete(info),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ClassCard extends StatelessWidget {
  final ClassInfo info;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ClassCard({
    required this.info,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              info.id,
              style: const TextStyle(
                color: Color(0xFF1C1C1E),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name?.trim().isNotEmpty == true
                      ? info.name!.trim()
                      : 'Kelas ${info.id}',
                  style: const TextStyle(
                    color: Color(0xFF1C1C1E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info.waliName?.trim().isNotEmpty == true
                      ? 'Wali kelas • ${info.waliName!.trim()}'
                      : 'Wali belum ditentukan',
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Color(0xFF8E8E93)),
            onSelected: (value) {
              if (value == 'edit') onTap();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Hapus')),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final VoidCallback onAdd;

  const _InfoBanner({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Tambahkan kelas untuk daftar siswa dan penugasan wali.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onAdd,
            child: const Text('Tambah',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
