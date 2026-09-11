import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/ranking.dart';
import '../../data/services/criteria_service.dart';
import '../../data/services/student_service.dart';
import '../../data/services/rating_service.dart';
import '../../logic/profile_matching.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/empty_state_card.dart';

class RankingScreen extends StatefulWidget {
  final String? classId;

  const RankingScreen({super.key, this.classId});

  @override
  State<RankingScreen> createState() => RankingScreenState();
}

class RankingScreenState extends State<RankingScreen> {
  bool _loading = true;
  String? _error;
  List<Ranking> _rankings = [];

  late final CriteriaService _criteriaService;
  late final RatingService _ratingService;

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
      final ratings = await _ratingService.fetchRatingsWithStudents(
        classId: widget.classId,
      );
      final calculator = ProfileMatchingCalculator();
      final rankingList = calculator.calculate(
        criteria: criteria,
        ratings: ratings,
      );
      setState(() {
        _rankings = rankingList;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> reload() => _load();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _RankingSkeleton();
    if (_error != null) {
      return Center(
        child:
            Text('Error: $_error', style: const TextStyle(color: Colors.white)),
      );
    }
    if (_rankings.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.emoji_events_outlined,
        title: 'Belum ada data ranking.',
        subtitle:
            'Isi nilai siswa terlebih dahulu untuk menghasilkan ranking kelas.',
      );
    }
    final top3 = _rankings.take(3).toList();
    final rest = _rankings.skip(3).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _RankingHero(
            top3: top3,
          ),
          _RankingList(
            rest: rest,
            startIndex: 4,
            classId: widget.classId,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
        ],
      ),
    );
  }
}

class _RankingSkeleton extends StatelessWidget {
  const _RankingSkeleton();

  @override
  Widget build(BuildContext context) {
    final bottomSpacer = MediaQuery.of(context).padding.bottom + 60;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      children: [
        const ShimmerBlock(
            height: 180, radius: 24, margin: EdgeInsets.only(bottom: 14)),
        const ShimmerBlock(
            height: 260, radius: 24, margin: EdgeInsets.only(bottom: 14)),
        ...List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppShimmer(
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            width: 160,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 10,
                          width: 48,
                          decoration: BoxDecoration(
                            color: const Color(0x30FFFFFF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 10,
                          width: 48,
                          decoration: BoxDecoration(
                            color: const Color(0x24FFFFFF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: bottomSpacer),
      ],
    );
  }
}

class _RankingHero extends StatelessWidget {
  final List<Ranking> top3;

  const _RankingHero({
    required this.top3,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final podium = _PodiumData.from(top3);
    final heroHeight = (size.height * 0.54).clamp(430.0, 500.0).toDouble();
    final podiumTop = size.height < 760 ? 64.0 : 72.0;
    return SizedBox(
      height: heroHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0E0E14), Color(0xFF191922)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 4),
                  _HeaderToggle(),
                ],
              ),
            ),
          ),
          Positioned.fill(
            top: podiumTop - 8,
            child: CustomPaint(
              painter: _ArcPainter(),
            ),
          ),
          Positioned.fill(
            top: podiumTop,
            child: Align(
              alignment: Alignment.topCenter,
              child: _Podium(podium: podium),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Leaderboard',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _PodiumData {
  final _RankTile? rank1;
  final _RankTile? rank2;
  final _RankTile? rank3;

  _PodiumData({this.rank1, this.rank2, this.rank3});

  factory _PodiumData.from(List<Ranking> ranks) {
    _RankTile? tileFor(int index) {
      if (index >= ranks.length) return null;
      final r = ranks[index];
      return _RankTile(
        name: r.studentName,
        score: r.totalScore,
        position: index + 1,
      );
    }

    return _PodiumData(
      rank1: tileFor(0),
      rank2: tileFor(1),
      rank3: tileFor(2),
    );
  }
}

class _RankTile {
  final String name;
  final double score;
  final int position;

  _RankTile({required this.name, required this.score, required this.position});
}

class _Podium extends StatelessWidget {
  final _PodiumData podium;

  const _Podium({required this.podium});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final horizontalGap = width < 360 ? 8.0 : 12.0;
        final availableWidth = width - (horizontalGap * 2);
        final columnWidth = (availableWidth / 3).clamp(82.0, 128.0);
        final slots = <Widget>[
          if (podium.rank2 != null)
            _PodiumColumn(data: podium.rank2, tier: 2, width: columnWidth),
          if (podium.rank1 != null)
            _PodiumColumn(data: podium.rank1, tier: 1, width: columnWidth),
          if (podium.rank3 != null)
            _PodiumColumn(data: podium.rank3, tier: 3, width: columnWidth),
        ];

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < slots.length; i++) ...[
                  if (i > 0) SizedBox(width: horizontalGap),
                  slots[i],
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final _RankTile? data;
  final int tier;
  final double width;

  const _PodiumColumn({
    required this.data,
    required this.tier,
    required this.width,
  });

  double get height {
    switch (tier) {
      case 1:
        return 190;
      case 2:
        return 150;
      case 3:
      default:
        return 130;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox.shrink();
    final name = data!.name;
    final score = data!.score;
    final position = data!.position;
    final isWinner = tier == 1;
    final platformWidth = (width * 0.76).clamp(72.0, 90.0);
    return SizedBox(
      width: width,
      child: Column(
        children: [
          _AvatarBadge(position: position),
          const SizedBox(height: 8),
          Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: Column(
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: isWinner ? 17 : 15)),
                const SizedBox(height: 4),
                Text('${score.toStringAsFixed(3)} poin',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isWinner ? Colors.white : Colors.white70,
                      fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: platformWidth,
            height: height,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFEFF2), Color(0xFFD8D8DE)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$position',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  final int position;

  const _AvatarBadge({required this.position});

  @override
  Widget build(BuildContext context) {
    final isWinner = position == 1;
    return Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.white.withOpacity(0.18),
          child: const Icon(Icons.person, color: Colors.white),
        ),
        if (isWinner)
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.emoji_events, size: 16, color: Colors.black),
            ),
          ),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final centers = [
      Offset(size.width * 0.5, size.height * 0.55),
      Offset(size.width * 0.5, size.height * 0.72),
    ];
    final radii = [size.width * 0.6, size.width * 0.8];

    for (var i = 0; i < centers.length; i++) {
      canvas.drawCircle(centers[i], radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RankingList extends StatelessWidget {
  final List<Ranking> rest;
  final int startIndex;
  final String? classId;

  const _RankingList({
    required this.rest,
    required this.startIndex,
    required this.classId,
  });

  @override
  Widget build(BuildContext context) {
    final classLabel =
        (classId?.trim().isNotEmpty ?? false) ? classId!.trim() : 'Anda';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: rest.isEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daftar Peringkat Kelas',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                    ),
                    child: Text(
                      'Belum ada siswa lain di kelas $classLabel.',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              itemBuilder: (context, index) {
                final rank = rest[index];
                final rankNumber = startIndex + index;
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.black.withOpacity(0.08),
                      child: Text('$rankNumber',
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.black.withOpacity(0.08),
                      child: const Icon(Icons.person, color: Colors.black87),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rank.studentName,
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${rank.totalScore.toStringAsFixed(3)} poin',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'K1 ${rank.k1.toStringAsFixed(1)}',
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: rest.length,
            ),
    );
  }
}
