import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/criteria.dart';
import '../../data/services/criteria_service.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/app_surface.dart';

class CriteriaScreen extends StatefulWidget {
  const CriteriaScreen({super.key});

  @override
  State<CriteriaScreen> createState() => CriteriaScreenState();
}

class CriteriaScreenState extends State<CriteriaScreen> {
  late final CriteriaService _service;
  late Future<List<Criteria>> _future;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = CriteriaService(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _future = _service.fetchCriteria();
    });
    try {
      await _future;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    await _load();
  }

  Future<void> reload() => _load();
  Future<void> refreshIfEmpty() async {
    if (_isLoading) return;
    final data = await _future;
    if (data.isEmpty) {
      await _load();
    }
  }

  Future<void> _showAddDialog() async {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController(text: 'core');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      barrierColor: Colors.black54,
      builder: (context) {
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: StatefulBuilder(builder: (context, modalSetState) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 18,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Tambah Kriteria',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: idCtrl,
                      decoration: InputDecoration(
                        labelText: 'Kode (contoh: K1)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.white38, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.white, width: 1.2),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Kode wajib diisi' : null,
                      style: const TextStyle(color: Colors.white),
                    ),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.white38, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.white, width: 1.2),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Nama wajib diisi' : null,
                      style: const TextStyle(color: Colors.white),
                    ),
                    TextFormField(
                      controller: amountCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nilai Target (angka)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.white38, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.white, width: 1.2),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.isEmpty
                          ? 'Nilai target wajib diisi'
                          : null,
                      style: const TextStyle(color: Colors.white),
                    ),
                    DropdownButtonFormField<String>(
                      value: descCtrl.text,
                      items: const [
                        DropdownMenuItem(
                            value: 'core',
                            child: Text('Core',
                                style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                            value: 'secondary',
                            child: Text('Secondary',
                                style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (v) => descCtrl.text = v ?? 'core',
                      decoration: InputDecoration(
                        labelText: 'Jenis',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.white38, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.white, width: 1.2),
                        ),
                      ),
                      dropdownColor: Colors.black,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 46,
                      width: 180,
                      child: isSaving
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.18)),
                                ),
                                alignment: Alignment.center,
                                child: const LinearProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                  backgroundColor: Colors.white24,
                                ),
                              ),
                            )
                          : FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.14),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () async {
                                final valid =
                                    formKey.currentState?.validate() ?? false;
                                if (!valid) return;
                                modalSetState(() => isSaving = true);
                                try {
                                  await _service.upsertCriteria(
                                    Criteria(
                                      id: idCtrl.text.trim(),
                                      name: nameCtrl.text.trim(),
                                      amount: int.parse(amountCtrl.text),
                                      desc: descCtrl.text,
                                    ),
                                  );
                                  if (context.mounted)
                                    Navigator.pop(context, true);
                                } finally {
                                  if (mounted) {
                                    modalSetState(() => isSaving = false);
                                  }
                                }
                              },
                              child: const Text('Simpan'),
                            ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );

    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Criteria>>(
        future: _future,
        builder: (context, snapshot) {
          final isLoading = _isLoading ||
              snapshot.connectionState == ConnectionState.waiting ||
              snapshot.connectionState == ConnectionState.active;
          if (isLoading) return const _CriteriaSkeleton();
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final criteria = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kriteria',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Core & secondary\nuntuk perhitungan nilai.',
                          style: TextStyle(
                            color: Color(0xFFB8B8C0),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.12),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah Kriteria'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (criteria.isEmpty)
                AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Belum ada kriteria.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tambahkan kriteria untuk mulai penilaian.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _showAddDialog,
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text(
                              'Tambah kriteria',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...criteria.map(
                  (c) => _CriteriaCard(criteria: c),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CriteriaCard extends StatelessWidget {
  final Criteria criteria;

  const _CriteriaCard({required this.criteria});

  String _labelForDesc(String value) {
    if (value.trim().toLowerCase() == 'secondary') return 'Secondary';
    return 'Core';
  }

  @override
  Widget build(BuildContext context) {
    final descLabel = _labelForDesc(criteria.desc);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              alignment: Alignment.center,
              child: Text(
                criteria.id,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    criteria.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Target ${criteria.amount}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: Text(
                descLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CriteriaSkeleton extends StatelessWidget {
  const _CriteriaSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 120),
      children: [
        const ShimmerBlock(
          height: 86,
          radius: 18,
          margin: EdgeInsets.only(bottom: 12),
        ),
        ...List.generate(
          5,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppShimmer(
              child: Container(
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      height: 16,
                      width: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0x35F4F4FF),
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 10,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
