import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/criteria.dart';
import '../../data/models/student.dart';
import '../../data/models/class_info.dart';
import '../../data/models/rating.dart';
import '../../data/services/class_service.dart';
import '../../data/services/criteria_service.dart';
import '../../data/services/rating_service.dart';
import '../../data/services/student_service.dart';
import '../widgets/app_surface.dart';
import 'student_detail_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  final String profileName;
  final String? classId;
  final String? studentId;
  final VoidCallback onSignOut;

  const StudentProfileScreen({
    super.key,
    required this.profileName,
    required this.classId,
    required this.studentId,
    required this.onSignOut,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  late final StudentService _service;
  late final ClassService _classService;
  late final CriteriaService _criteriaService;
  late final RatingService _ratingService;
  bool _loading = true;
  Student? _student;
  ClassInfo? _classInfo;
  double? _totalScore;
  int? _worldRank;
  int? _classRank;
  String? _error;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _service = StudentService(client);
    _classService = ClassService(client);
    _criteriaService = CriteriaService(client);
    _ratingService = RatingService(client, StudentService(client));
    _load();
  }

  Future<void> _loadClassInfo(Student? student) async {
    if (student == null) return;
    final directId = student.classId?.trim() ?? '';
    final fallbackId = student.className.trim();
    final classId = directId.isNotEmpty ? directId : fallbackId;
    if (classId.isEmpty) return;
    final info = await _classService.fetchClassInfo(classId);
    if (!mounted) return;
    setState(() => _classInfo = info);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _classInfo = null;
      _totalScore = null;
      _worldRank = null;
      _classRank = null;
    });
    try {
      final studentId = widget.studentId?.trim();
      if (studentId != null && studentId.isNotEmpty) {
        final byId = await _service.fetchStudentById(studentId);
        if (!mounted) return;
        setState(() => _student = byId);
        await _loadClassInfo(byId);
        await _loadInsights(byId);
        return;
      }
      final students = await _service.fetchStudents();
      final classId = widget.classId?.trim().toLowerCase();
      final name = widget.profileName.trim().toLowerCase();
      final match = students.where((s) {
        final sameClass = classId == null || classId.isEmpty
            ? true
            : s.className.trim().toLowerCase() == classId;
        final sameName = s.name.trim().toLowerCase() == name;
        return sameClass && sameName;
      }).toList();
      if (!mounted) return;
      final student = match.isNotEmpty ? match.first : null;
      setState(() => _student = student);
      await _loadClassInfo(student);
      await _loadInsights(student);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadInsights(Student? student) async {
    if (student == null) return;
    try {
      final criteria = await _criteriaService.fetchCriteria();
      final ratings = await _ratingService.fetchRatingsWithStudents();
      final entries = _calculateEntries(criteria: criteria, ratings: ratings);
      final worldIdx = entries.indexWhere((e) => e.student.id == student.id);
      final classEntries = entries
          .where(
            (e) =>
                e.student.className.trim().toLowerCase() ==
                student.className.trim().toLowerCase(),
          )
          .toList();
      final classIdx =
          classEntries.indexWhere((e) => e.student.id == student.id);
      if (!mounted) return;
      setState(() {
        _totalScore = worldIdx == -1 ? null : entries[worldIdx].score;
        _worldRank = classIdx == -1 ? null : classIdx + 1;
        _classRank = classEntries.length;
      });
    } catch (_) {
      // Insights are optional; keep profile view functional even if analytics fails.
    }
  }

  List<_StudentScoreEntry> _calculateEntries({
    required List<Criteria> criteria,
    required List<Rating> ratings,
  }) {
    if (criteria.isEmpty || ratings.isEmpty) return const [];

    final weights = criteria.map((c) => c.amount.toDouble()).toList();
    final weightSum = weights.fold<double>(0, (a, b) => a + b);
    final normalizedWeights = weightSum == 0
        ? List<double>.filled(weights.length, 1 / weights.length)
        : weights.map((w) => w / weightSum).toList();

    final maxValues = List<double>.filled(criteria.length, 0);
    final minValues = List<double>.filled(criteria.length, double.infinity);
    for (final rating in ratings) {
      for (var i = 0; i < criteria.length; i++) {
        final value = _valueByIndex(rating, i).toDouble();
        if (value > maxValues[i]) maxValues[i] = value;
        if (value < minValues[i]) minValues[i] = value;
      }
    }

    final entries = <_StudentScoreEntry>[];
    for (final rating in ratings) {
      double total = 0;
      for (var i = 0; i < criteria.length; i++) {
        final value = _valueByIndex(rating, i).toDouble();
        final isCost = criteria[i].desc.trim().toLowerCase() == 'cost';
        final normalized = isCost
            ? (minValues[i] == double.infinity || value == 0
                ? 0
                : minValues[i] / value)
            : (maxValues[i] == 0 ? 0 : value / maxValues[i]);
        total += normalized * normalizedWeights[i];
      }
      entries.add(
        _StudentScoreEntry(
          student: rating.student,
          score: double.parse(total.toStringAsFixed(3)),
        ),
      );
    }
    entries.sort((a, b) => b.score.compareTo(a.score));
    return entries;
  }

  int _valueByIndex(Rating rating, int index) {
    switch (index) {
      case 0:
        return rating.value.k1;
      case 1:
        return rating.value.k2;
      case 2:
        return rating.value.k3;
      case 3:
        return rating.value.k4;
      case 4:
        return rating.value.k5;
      default:
        return 0;
    }
  }

  void _openDetail() {
    final student = _student;
    if (student == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentDetailScreen(student: student),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      safeTop: true,
      safeBottom: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _student == null
                  ? _EmptyProfile(name: widget.profileName)
                  : _ProfileCard(
                      student: _student!,
                      classInfo: _classInfo,
                      totalScore: _totalScore,
                      worldRank: _worldRank,
                      classRank: _classRank,
                      onSeeDetail: _openDetail,
                      onSignOut: widget.onSignOut,
                    ),
    );
  }
}

class _EmptyProfile extends StatelessWidget {
  final String name;

  const _EmptyProfile({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Profil siswa belum ditemukan.\nHubungi admin untuk sinkronisasi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8E8E93)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Student student;
  final ClassInfo? classInfo;
  final double? totalScore;
  final int? worldRank;
  final int? classRank;
  final VoidCallback onSeeDetail;
  final VoidCallback onSignOut;

  const _ProfileCard({
    required this.student,
    required this.classInfo,
    required this.totalScore,
    required this.worldRank,
    required this.classRank,
    required this.onSeeDetail,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 12),
                  )
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFE5E5EA),
                    child: Text(
                      student.name.isNotEmpty ? student.name[0] : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          student.className.isNotEmpty
                              ? student.className
                              : '-',
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 13,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _SummaryCard(
            totalScore: totalScore,
            worldRank: worldRank,
            classRank: classRank,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onSeeDetail,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text(
                'Lihat Detail Lengkap',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _InfoTile(
            label: 'ID Siswa',
            value: student.id,
          ),
          const SizedBox(height: 10),
          _InfoTile(
            label: 'Wali Kelas',
            value: (classInfo?.waliName?.trim().isNotEmpty == true)
                ? classInfo!.waliName!.trim()
                : '-',
          ),
          const SizedBox(height: 10),
          _InfoTile(
            label: 'Alamat',
            value: student.address.isNotEmpty ? student.address : '-',
          ),
          const SizedBox(height: 10),
          _InfoTile(
            label: 'Telepon',
            value: student.phone.isNotEmpty ? student.phone : '-',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text(
                'Keluar Akun',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.black.withOpacity(0.22)),
                backgroundColor: Colors.white.withOpacity(0.9),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double? totalScore;
  final int? worldRank;
  final int? classRank;

  const _SummaryCard({
    required this.totalScore,
    required this.worldRank,
    required this.classRank,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          _StatItem(
              label: 'Total', value: totalScore?.toStringAsFixed(3) ?? '-'),
          _StatDivider(),
          _StatItem(
            label: 'Peringkat Kelas',
            value: worldRank != null ? '#$worldRank' : '-',
          ),
          _StatDivider(),
          _StatItem(
            label: 'Jumlah Siswa Kelas',
            value: classRank != null ? '$classRank' : '-',
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  static const double _valueRightInset = 12;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: _valueRightInset),
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF1C1C1E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentScoreEntry {
  final Student student;
  final double score;

  const _StudentScoreEntry({
    required this.student,
    required this.score,
  });
}
