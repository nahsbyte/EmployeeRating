import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/criteria.dart';
import '../../data/models/rating.dart';
import '../../data/models/student.dart';
import '../../data/services/student_service.dart';
import '../../data/services/criteria_service.dart';
import '../../data/services/rating_service.dart';

class StudentDetailScreen extends StatefulWidget {
  final Student student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late final CriteriaService _criteriaService;
  late final RatingService _ratingService;

  bool _loading = true;
  String? _error;
  _ScoreEntry? _current;
  int? _worldRank;
  int? _classRank;
  List<Criteria> _criteria = const [];

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _criteriaService = CriteriaService(client);
    _ratingService = RatingService(client, StudentService(client));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final criteria = await _criteriaService.fetchCriteria();
      final ratings = await _ratingService.fetchRatingsWithStudents();
      final scores = _calculateScores(criteria, ratings);

      final idx = scores.indexWhere((e) => e.student.id == widget.student.id);
      final current = idx == -1 ? null : scores[idx];

      final classScores = scores
          .where((e) =>
              (e.student.className).trim().toLowerCase() ==
              (widget.student.className).trim().toLowerCase())
          .toList();
      final classIdx =
          classScores.indexWhere((e) => e.student.id == widget.student.id);

      if (!mounted) return;
      setState(() {
        _criteria = criteria;
        _current = current;
        _worldRank = classIdx == -1 ? null : classIdx + 1;
        _classRank = classScores.length;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<_ScoreEntry> _calculateScores(
      List<Criteria> criteria, List<Rating> ratings) {
    if (criteria.isEmpty || ratings.isEmpty) return [];

    final weights = criteria.map((c) => c.amount.toDouble()).toList();
    final weightSum = weights.fold<double>(0, (a, b) => a + b);
    final normalizedWeights = weightSum == 0
        ? List.filled(weights.length, 1 / weights.length)
        : weights.map((w) => w / weightSum).toList();

    final maxValues = List<double>.filled(criteria.length, 0);
    final minValues = List<double>.filled(criteria.length, double.infinity);
    for (final rating in ratings) {
      for (var i = 0; i < criteria.length; i++) {
        final value = _valueByIndex(rating, i).toDouble();
        maxValues[i] = max(maxValues[i], value);
        minValues[i] = min(minValues[i], value);
      }
    }

    final results = <_ScoreEntry>[];
    for (final rating in ratings) {
      double total = 0.0;
      final normalizedPerCriteria =
          List<double>.filled(max(5, criteria.length), 0.0);

      for (var i = 0; i < criteria.length; i++) {
        final value = _valueByIndex(rating, i).toDouble();
        final isCost = (criteria[i].desc.toLowerCase()) == 'cost';

        final normalized = (isCost
                ? (minValues[i] == double.infinity || value == 0
                    ? 0
                    : minValues[i] / value)
                : (maxValues[i] == 0 ? 0 : value / maxValues[i]))
            .toDouble();

        total += normalized * normalizedWeights[i];
        normalizedPerCriteria[i] = normalized;
      }

      results.add(_ScoreEntry(
        student: rating.student,
        totalScore: double.parse(total.toStringAsFixed(3)),
        normalized: normalizedPerCriteria,
      ));
    }

    results.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    return results;
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

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Siswa',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.black54),
            onPressed: () {},
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _current == null
                  ? _EmptyState(onBack: () => Navigator.pop(context))
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HeroStatsCard(
                            student: widget.student,
                            score: _current!.totalScore,
                            worldRank: _worldRank,
                            classRank: _classRank,
                          ),
                          const SizedBox(height: 16),
                          _TabsCard(
                            criteria: _criteria,
                            normalized: _current!.normalized,
                            student: widget.student,
                            score: _current!.totalScore,
                            worldRank: _worldRank,
                            classRank: _classRank,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
    );
  }
}

class _TabsCard extends StatelessWidget {
  final List<Criteria> criteria;
  final List<double> normalized;
  final Student student;
  final double score;
  final int? worldRank;
  final int? classRank;

  const _TabsCard({
    required this.criteria,
    required this.normalized,
    required this.student,
    required this.score,
    required this.worldRank,
    required this.classRank,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: null,
        child: Column(
          children: [
            TabBar(
              labelColor: Colors.black,
              unselectedLabelColor: Colors.black54.withOpacity(0.7),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: Colors.black, width: 2.2),
                insets: EdgeInsets.symmetric(horizontal: 24),
              ),
              indicatorSize: TabBarIndicatorSize.label,
              overlayColor: WidgetStateProperty.all(
                Colors.transparent,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Statistik'),
                Tab(text: 'Detail'),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 480,
              child: TabBarView(
                children: [
                  _StatsSection(
                    criteria: criteria,
                    normalized: normalized,
                    score: score,
                    worldRank: worldRank,
                    classRank: classRank,
                    totalStudents: classRank ?? 0,
                  ),
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _InfoCard(student: student),
                        const SizedBox(height: 14),
                        _CriteriaBreakdown(
                          criteria: criteria,
                          normalized: normalized,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStatsCard extends StatelessWidget {
  final Student student;
  final double score;
  final int? worldRank;
  final int? classRank;

  const _HeroStatsCard({
    required this.student,
    required this.score,
    required this.worldRank,
    required this.classRank,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFF4F4F6), Color(0xFFDADDE3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 16,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Center(
            child: Text(
              student.name.isNotEmpty ? student.name[0] : '?',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFDFDFE), Color(0xFFF1F2F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 18,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            children: [
              Text(
                student.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                student.className.isNotEmpty
                    ? student.className
                    : 'Kelas belum diisi',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F25),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    _StatTile(
                      label: 'Total',
                      value: score.toStringAsFixed(3),
                      dark: true,
                    ),
                    const _StatDivider(dark: true),
                    _StatTile(
                      label: 'Peringkat Kelas',
                      value: worldRank != null ? '#$worldRank' : '-',
                      dark: true,
                    ),
                    const _StatDivider(dark: true),
                    _StatTile(
                      label: 'Jumlah Siswa Kelas',
                      value: classRank != null ? '$classRank' : '-',
                      dark: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsChips extends StatelessWidget {
  final List<Criteria> criteria;
  final List<double> normalized;

  const _StatsChips({
    required this.criteria,
    required this.normalized,
  });

  @override
  Widget build(BuildContext context) {
    if (criteria.isEmpty) {
      return const Center(
        child:
            Text('Belum ada kriteria', style: TextStyle(color: Colors.black54)),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(criteria.length, (i) {
        final c = criteria[i];
        final value = i < normalized.length ? normalized[i] : 0.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.name,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(value * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final List<Criteria> criteria;
  final List<double> normalized;
  final double score;
  final int? worldRank;
  final int? classRank;
  final int totalStudents;

  const _StatsSection({
    required this.criteria,
    required this.normalized,
    required this.score,
    required this.worldRank,
    required this.classRank,
    required this.totalStudents,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _StatsHeroCard(
            score: score,
            worldRank: worldRank,
            classRank: classRank,
            totalStudents: totalStudents,
          ),
          const SizedBox(height: 14),
          _CriteriaBarCard(
            criteria: criteria,
            normalized: normalized,
          ),
        ],
      ),
    );
  }
}

class _StatsHeroCard extends StatelessWidget {
  final double score;
  final int? worldRank;
  final int? classRank;
  final int totalStudents;

  const _StatsHeroCard({
    required this.score,
    required this.worldRank,
    required this.classRank,
    required this.totalStudents,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (score.clamp(0, 1) * 100).round();
    final rankText = worldRank != null ? '#$worldRank' : '-';
    final studentsText = totalStudents > 0
        ? 'dari $totalStudents siswa'
        : 'belum ada data kelas';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 21),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Statistik',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: Colors.black54,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Semua Waktu',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MiniStatCard(
            title: 'Peringkat Kelas',
            value: rankText,
            subtitle: studentsText,
            dark: true,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: score.clamp(0, 1),
                        strokeWidth: 9,
                        backgroundColor: Colors.black.withOpacity(0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.black,
                        ),
                      ),
                      Center(
                        child: Text(
                          '$percent%',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Skor Total',
                        style: TextStyle(
                          color: Colors.black87.withOpacity(0.84),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        score.toStringAsFixed(3),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Nilai SAW akhir siswa',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        studentsText,
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final bool dark;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1D1D21) : Colors.black.withOpacity(0.04);
    final fg = dark ? Colors.white : Colors.black87;
    final sub = dark ? Colors.white70 : Colors.black54;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(dark ? 0.05 : 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: sub,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: sub,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _CriteriaBarCard extends StatelessWidget {
  final List<Criteria> criteria;
  final List<double> normalized;

  const _CriteriaBarCard({
    required this.criteria,
    required this.normalized,
  });

  @override
  Widget build(BuildContext context) {
    if (criteria.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF111114),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                'Performa per Kriteria',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Spacer(),
              Icon(Icons.bar_chart_rounded, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              for (var i = 0; i < criteria.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7 - (i * 0.1)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      criteria[i].name,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: criteria.length,
              separatorBuilder: (_, __) => const SizedBox(width: 1),
              itemBuilder: (context, i) {
                final v = i < normalized.length ? normalized[i] : 0.0;
                final h = (v.clamp(0.0, 1.0)) * 130 + 24;
                return SizedBox(
                  width: 68,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${(v * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: h,
                        width: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.white.withOpacity(0.82),
                              Colors.white.withOpacity(0.55),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        criteria[i].name,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Student student;

  const _HeroCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFDFDFE), Color(0xFFF1F2F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                student.name.isNotEmpty ? student.name[0] : '?',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            student.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            student.className.isNotEmpty
                ? student.className
                : 'Kelas belum diisi',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final double score;
  final int? worldRank;
  final int? classRank;

  const _StatsCard({
    required this.score,
    required this.worldRank,
    required this.classRank,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F25),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          _StatTile(
            label: 'Total',
            value: score.toStringAsFixed(3),
            dark: true,
          ),
          const _StatDivider(dark: true),
          _StatTile(
            label: 'Peringkat Kelas',
            value: worldRank != null ? '#$worldRank' : '-',
            dark: true,
          ),
          const _StatDivider(dark: true),
          _StatTile(
            label: 'Jumlah Siswa Kelas',
            value: classRank != null ? '$classRank' : '-',
            dark: true,
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final bool dark;

  const _StatTile(
      {required this.label, required this.value, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: dark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: dark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  final bool dark;

  const _StatDivider({this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: dark
          ? Colors.white.withOpacity(0.14)
          : Colors.black.withOpacity(0.08),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Student student;

  const _InfoCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Info Kontak',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.phone_rounded,
            title: 'Telepon',
            value: student.phone.isNotEmpty ? student.phone : 'Belum ada nomor',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.home_rounded,
            title: 'Alamat',
            value: student.address.isNotEmpty
                ? student.address
                : 'Alamat belum diisi',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.black87, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CriteriaBreakdown extends StatelessWidget {
  final List<Criteria> criteria;
  final List<double> normalized;

  const _CriteriaBreakdown({
    required this.criteria,
    required this.normalized,
  });

  @override
  Widget build(BuildContext context) {
    if (criteria.isEmpty) return const SizedBox.shrink();

    final average = normalized.isEmpty
        ? 0.0
        : normalized.fold<double>(0, (a, b) => a + b) / normalized.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rincian Kriteria',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rata-rata kriteria: ${(average * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(criteria.length, (i) {
            final c = criteria[i];
            final value = i < normalized.length ? normalized[i] : 0.0;
            final tone = _toneForValue(value);
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          c.name,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        '${(value * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: tone,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      minHeight: 11,
                      value: value.clamp(0.0, 1.0),
                      backgroundColor: Colors.black.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        tone,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _toneForValue(double value) {
    final v = value.clamp(0.0, 1.0);
    if (v >= 0.85) return Colors.black.withOpacity(0.88);
    if (v >= 0.65) return Colors.black.withOpacity(0.72);
    return Colors.black.withOpacity(0.52);
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Gagal memuat: $message',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: const BorderSide(color: Colors.black87),
            ),
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onBack;

  const _EmptyState({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Data siswa belum tersedia.',
            style: TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onBack,
            child: const Text('Kembali'),
          ),
        ],
      ),
    );
  }
}

class _ScoreEntry {
  final Student student;
  final double totalScore;
  final List<double> normalized;

  const _ScoreEntry({
    required this.student,
    required this.totalScore,
    required this.normalized,
  });
}
