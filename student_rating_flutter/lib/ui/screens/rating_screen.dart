import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/criteria.dart';
import '../../data/models/rating.dart';
import '../../data/models/rating_value.dart';
import '../../data/services/criteria_service.dart';
import '../../data/services/class_service.dart';
import '../../data/services/student_service.dart';
import '../../data/services/rating_service.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/app_surface.dart';
import '../widgets/empty_state_card.dart';

class RatingScreen extends StatefulWidget {
  final String? classId;

  const RatingScreen({super.key, this.classId});

  @override
  State<RatingScreen> createState() => RatingScreenState();
}

class RatingScreenState extends State<RatingScreen> {
  late final CriteriaService _criteriaService;
  late final RatingService _ratingService;
  late final ClassService _classService;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  static const int _pageSize = 40;
  List<Criteria> _criteria = [];
  List<Rating> _ratings = [];
  String? _error;
  late final ScrollController _scrollController;
  String _searchQuery = '';
  String? _selectedClassId;
  String _selectedCriteriaId = 'all';
  List<String> _classOptions = [];

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _criteriaService = CriteriaService(client);
    _ratingService = RatingService(client, StudentService(client));
    _classService = ClassService(client);
    _selectedClassId = widget.classId;
    _scrollController = ScrollController()
      ..addListener(() {
        if (!_scrollController.hasClients || _loadingMore || !_hasMore) return;
        final threshold = _scrollController.position.maxScrollExtent - 240;
        if (_scrollController.position.pixels >= threshold) {
          _loadMore();
        }
      });
    _loadClassOptions();
    _fetchData();
  }

  Future<void> _loadClassOptions() async {
    final options = await _classService.fetchClassOptions();
    if (!mounted) return;
    setState(() {
      _classOptions = options.map((c) => c.id).toList();
    });
  }

  String? get _effectiveClassId {
    if (widget.classId != null && widget.classId!.trim().isNotEmpty) {
      return widget.classId;
    }
    return _selectedClassId;
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _ratings = [];
      _page = 0;
      _hasMore = true;
    });
    try {
      final criteria = await _criteriaService.fetchCriteria();
      final ratings = await _ratingService.fetchRatingsWithStudents(
        classId: _effectiveClassId,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _criteria = criteria;
        _ratings = ratings;
        _hasMore = ratings.length == _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> reload() => _fetchData();

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final nextRatings = await _ratingService.fetchRatingsWithStudents(
        classId: _effectiveClassId,
        limit: _pageSize,
        offset: nextPage * _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _ratings.addAll(nextRatings);
        _hasMore = nextRatings.length == _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openRatingDialog(Rating rating) async {
    final controllers = <int, TextEditingController>{};
    for (var i = 0; i < _criteria.length; i++) {
      final value = _valueByIndex(rating.value, i);
      controllers[i] = TextEditingController(text: value.toString());
    }
    bool isSaving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      barrierColor: Colors.black54,
      builder: (context) {
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: StatefulBuilder(
            builder: (context, modalSetState) {
              final bottomInset = MediaQuery.of(context).viewInsets.bottom;
              final safeBottom = MediaQuery.of(context).padding.bottom;
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: bottomInset + safeBottom + 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nilai - ${rating.student.name}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_criteria.length, (index) {
                      final c = _criteria[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: TextField(
                          controller: controllers[index],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: '${c.id} - ${c.name}',
                            helperText: 'Target ${c.amount} (${c.desc})',
                            labelStyle: const TextStyle(color: Colors.white70),
                            helperStyle: const TextStyle(color: Colors.white54),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.white38, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.white, width: 1.2),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 46,
                      width: 200,
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
                                modalSetState(() => isSaving = true);
                                try {
                                  final newValue = RatingValue(
                                    k1: int.tryParse(
                                            controllers[0]?.text ?? '') ??
                                        0,
                                    k2: int.tryParse(
                                            controllers[1]?.text ?? '') ??
                                        0,
                                    k3: int.tryParse(
                                            controllers[2]?.text ?? '') ??
                                        0,
                                    k4: int.tryParse(
                                            controllers[3]?.text ?? '') ??
                                        0,
                                    k5: int.tryParse(
                                            controllers[4]?.text ?? '') ??
                                        0,
                                  );
                                  await _ratingService.upsertRating(
                                    ratingId: rating.ratingId,
                                    studentId: rating.student.id,
                                    value: newValue,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context, true);
                                  }
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
              );
            },
          ),
        );
      },
    );

    if (saved == true) {
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _RatingSkeleton();
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_ratings.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.assignment_turned_in_outlined,
        title: 'Belum ada data siswa.',
        subtitle:
            'Tambahkan siswa terlebih dahulu lalu isi nilai per kriteria.',
      );
    }
    final filtered = _searchQuery.trim().isEmpty
        ? _ratings
        : _ratings
            .where((r) => r.student.name
                .toLowerCase()
                .contains(_searchQuery.trim().toLowerCase()))
            .toList();
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
        itemCount: filtered.length + 1 + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _RatingHeader(
              classOptions: _classOptions,
              selectedClassId: _selectedClassId,
              classLocked:
                  widget.classId != null && widget.classId!.trim().isNotEmpty,
              onClassChanged: (value) {
                setState(() => _selectedClassId = value);
                _fetchData();
              },
              criteria: _criteria,
              selectedCriteriaId: _selectedCriteriaId,
              onCriteriaChanged: (value) =>
                  setState(() => _selectedCriteriaId = value),
              onSearchChanged: (value) => setState(() => _searchQuery = value),
            );
          }
          final itemIndex = index - 1;
          if (itemIndex >= filtered.length) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Center(
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final rating = filtered[itemIndex];
          return Dismissible(
            key: ValueKey(rating.student.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              _openRatingDialog(rating);
              return false;
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.edit, color: Colors.white70),
            ),
            child: AppCard(
              margin: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onLongPress: () => _openRatingDialog(rating),
                child: _RatingCard(
                  rating: rating,
                  criteria: _criteria,
                  selectedCriteriaId: _selectedCriteriaId,
                  valueByIndex: _valueByIndex,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  int _valueByIndex(RatingValue value, int index) {
    switch (index) {
      case 0:
        return value.k1;
      case 1:
        return value.k2;
      case 2:
        return value.k3;
      case 3:
        return value.k4;
      case 4:
        return value.k5;
      default:
        return 0;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _RatingHeader extends StatelessWidget {
  final List<String> classOptions;
  final String? selectedClassId;
  final bool classLocked;
  final ValueChanged<String?> onClassChanged;
  final List<Criteria> criteria;
  final String selectedCriteriaId;
  final ValueChanged<String> onCriteriaChanged;
  final ValueChanged<String> onSearchChanged;

  const _RatingHeader({
    required this.classOptions,
    required this.selectedClassId,
    required this.classLocked,
    required this.onClassChanged,
    required this.criteria,
    required this.selectedCriteriaId,
    required this.onCriteriaChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nilai Siswa',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ringkasan skor per kriteria.',
            style: TextStyle(color: Color(0xFFB8B8C0), fontSize: 12),
          ),
          const SizedBox(height: 12),
          _SearchInput(onChanged: onSearchChanged),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: classLocked ? selectedClassId : selectedClassId,
                  dropdownColor: const Color(0xFF1A1A22),
                  decoration: InputDecoration(
                    labelText: 'Filter kelas',
                    labelStyle: const TextStyle(color: Color(0xFFB8B8C0)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: Colors.white, width: 1.2),
                    ),
                  ),
                  iconEnabledColor: Colors.white70,
                  items: [
                    if (!classLocked)
                      const DropdownMenuItem(
                        value: null,
                        child: Text(
                          'Semua kelas',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ...classOptions.map(
                      (id) => DropdownMenuItem(
                        value: id,
                        child: Text(id,
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                  onChanged: classLocked ? null : onClassChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CriteriaFilterChips(
            criteria: criteria,
            selected: selectedCriteriaId,
            onChanged: onCriteriaChanged,
          ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final Rating rating;
  final List<Criteria> criteria;
  final int Function(RatingValue value, int index) valueByIndex;
  final String selectedCriteriaId;

  const _RatingCard({
    required this.rating,
    required this.criteria,
    required this.valueByIndex,
    required this.selectedCriteriaId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rating.student.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: criteria
                      .asMap()
                      .entries
                      .where((entry) =>
                          selectedCriteriaId == 'all' ||
                          entry.value.id == selectedCriteriaId)
                      .map((entry) {
                    final i = entry.key;
                    final c = entry.value;
                    return _ScoreChip(
                      label: c.id,
                      value: valueByIndex(rating.value, i),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchInput({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Cari siswa...',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        prefixIcon: const Icon(Icons.search, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white, width: 1.2),
        ),
      ),
    );
  }
}

class _CriteriaFilterChips extends StatelessWidget {
  final List<Criteria> criteria;
  final String selected;
  final ValueChanged<String> onChanged;

  const _CriteriaFilterChips({
    required this.criteria,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ids = criteria.map((c) => c.id).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'Semua',
            selected: selected == 'all',
            onTap: () => onChanged('all'),
          ),
          ...ids.map(
            (id) => _FilterChip(
              label: id,
              selected: selected == id,
              onTap: () => onChanged(id),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withOpacity(0.22)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? Colors.white.withOpacity(0.4)
                  : Colors.white.withOpacity(0.12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final int value;

  const _ScoreChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RatingSkeleton extends StatelessWidget {
  const _RatingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 120),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppShimmer(
            child: Container(
              height: 92,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
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
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 10,
                          width: 180,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
