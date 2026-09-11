import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/student.dart';
import '../../data/services/student_service.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/app_surface.dart';
import 'student_detail_screen.dart';

class StudentsDiscoverScreen extends StatefulWidget {
  final VoidCallback onAdd;
  final String? classId;
  final bool canAddStudent;

  const StudentsDiscoverScreen({
    super.key,
    required this.onAdd,
    this.classId,
    this.canAddStudent = true,
  });

  @override
  State<StudentsDiscoverScreen> createState() => _StudentsDiscoverScreenState();
}

class _StudentsDiscoverScreenState extends State<StudentsDiscoverScreen> {
  late final StudentService _service;
  final List<Student> _students = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  static const int _pageSize = 50;
  String _query = '';

  List<Student> _filterByMode(List<Student> source, String mode) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return source;
    switch (mode) {
      case 'class':
        return source
            .where((s) => s.className.toLowerCase().contains(query))
            .toList();
      case 'contact':
        return source
            .where((s) => s.phone.toLowerCase().contains(query))
            .toList();
      case 'address':
        return source
            .where((s) => s.address.toLowerCase().contains(query))
            .toList();
      default:
        return source
            .where((s) => s.name.toLowerCase().contains(query))
            .toList();
    }
  }

  @override
  void initState() {
    super.initState();
    _service = StudentService(Supabase.instance.client);
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _students.clear();
      _page = 0;
      _hasMore = true;
    });
    try {
      final data = await _service.fetchStudentsPage(
        classId: widget.classId,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _students.addAll(data);
        _hasMore = data.length == _pageSize;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final data = await _service.fetchStudentsPage(
        classId: widget.classId,
        limit: _pageSize,
        offset: nextPage * _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _students.addAll(data);
        _hasMore = data.length == _pageSize;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTop = _filterByMode(_students, 'top');
    final filteredClass = _filterByMode(_students, 'class');
    final filteredContact = _filterByMode(_students, 'contact');
    final filteredAddress = _filterByMode(_students, 'address');
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        safeTop: true,
        safeBottom: true,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Daftar Siswa',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 16),
            _SearchBar(
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.94),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 22,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      const SizedBox(height: 4),
                      _CapsuleTabBar(),
                      const SizedBox(height: 10),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _StudentsList(
                              students: filteredTop,
                              loading: _loading,
                              loadingMore: _loadingMore,
                              hasMore: _hasMore,
                              onLoadMore: _loadMore,
                            ),
                            _StudentsList(
                              students: filteredClass,
                              loading: _loading,
                              loadingMore: _loadingMore,
                              hasMore: _hasMore,
                              onLoadMore: _loadMore,
                            ),
                            _StudentsList(
                              students: filteredContact,
                              loading: _loading,
                              loadingMore: _loadingMore,
                              hasMore: _hasMore,
                              onLoadMore: _loadMore,
                            ),
                            _StudentsList(
                              students: filteredAddress,
                              loading: _loading,
                              loadingMore: _loadingMore,
                              hasMore: _hasMore,
                              onLoadMore: _loadMore,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.canAddStudent
          ? FloatingActionButton(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              onPressed: widget.onAdd,
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: widget.canAddStudent
          ? FloatingActionButtonLocation.centerFloat
          : null,
    );
  }
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Cari siswa...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapsuleTabBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const color = Colors.black;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(22),
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        labelColor: color,
        unselectedLabelColor: Colors.grey[600],
        indicator: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        tabs: const [
          Tab(text: 'Top'),
          Tab(text: 'Kelas'),
          Tab(text: 'Kontak'),
          Tab(text: 'Alamat'),
        ],
      ),
    );
  }
}

class _StudentsList extends StatelessWidget {
  final List<Student> students;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final Future<void> Function() onLoadMore;

  const _StudentsList({
    required this.students,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (students.isEmpty) {
      return const Center(
        child: Text('Belum ada siswa', style: TextStyle(color: Colors.black87)),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!hasMore || loadingMore) return false;
        final metrics = notification.metrics;
        if (metrics.pixels >= metrics.maxScrollExtent - 200) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 140),
        itemCount: students.length + 1 + (loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 8, 12),
              child: Row(
                children: [
                  Text('Siswa',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800, color: Colors.black)),
                  const Spacer(),
                  Text('${students.length} total',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600])),
                ],
              ),
            );
          }
          final studentIndex = index - 1;
          if (studentIndex >= students.length) {
            return const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final student = students[studentIndex];
          return _DiscoverStudentTile(student: student);
        },
      ),
    );
  }
}

class _DiscoverStudentTile extends StatelessWidget {
  final Student student;

  const _DiscoverStudentTile({required this.student});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StudentDetailScreen(student: student),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
              border:
                  Border.all(color: Colors.black.withOpacity(0.05), width: 1.2),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFEAEAEA),
                  child: Text(student.name.isNotEmpty ? student.name[0] : '?',
                      style: const TextStyle(
                          color: Colors.black, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Colors.black,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        _subtitleText(student),
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black54),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitleText(Student s) {
    final kelas = s.className?.isNotEmpty == true ? s.className! : 'Kelas -';
    final phone = s.phone.isNotEmpty ? s.phone : 'No phone';
    return '$kelas • $phone';
  }
}
