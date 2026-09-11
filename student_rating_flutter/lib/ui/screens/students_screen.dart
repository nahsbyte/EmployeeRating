import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/student.dart';
import '../../data/models/class_info.dart';
import '../../data/services/class_service.dart';
import '../../data/services/student_service.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/app_surface.dart';
import 'student_detail_screen.dart';
import 'students_discover_screen.dart';

const _primaryDark = Color(0xFF0A0A0A);
const _secondaryDark = Color(0xFF121218);

class StudentsScreen extends StatefulWidget {
  final ScrollController? scrollController;
  final String? classId;
  final bool canAddStudent;

  const StudentsScreen({
    super.key,
    this.scrollController,
    this.classId,
    this.canAddStudent = true,
  });

  @override
  State<StudentsScreen> createState() => StudentsScreenState();
}

class StudentsScreenState extends State<StudentsScreen> {
  late final StudentService _service;
  late final ClassService _classService;
  late Future<List<Student>> _future;
  bool _isLoading = true;
  late final String _displayName;

  @override
  void initState() {
    super.initState();
    _service = StudentService(Supabase.instance.client);
    _classService = ClassService(Supabase.instance.client);
    _displayName = _resolveName();
    _loadStudents();
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Selamat Pagi';
    if (hour >= 12 && hour < 17) return 'Selamat Siang';
    if (hour >= 17 && hour < 21) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String _resolveName() {
    final user = Supabase.instance.client.auth.currentUser;
    final metaName = user?.userMetadata?['name'];
    if (metaName is String && metaName.trim().isNotEmpty) return metaName;
    final email = user?.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Sahabat';
  }

  Future<void> reload() => _loadStudents();
  Future<void> refreshIfEmpty() async {
    if (_isLoading) return;
    final data = await _future;
    if (data.isEmpty) {
      await _loadStudents();
    }
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _future = _service.fetchStudents(classId: widget.classId);
    });
    try {
      await _future;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadStudents();
  }

  Future<void> showAddDialog() async {
    final nameCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    List<ClassInfo> classOptions = [];
    String? selectedClassId;

    bool isSaving = false;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      barrierColor: Colors.black54,
      builder: (context) {
        return ScrollConfiguration(
          behavior: _NoScrollbarBehavior(),
          child: StatefulBuilder(
            builder: (context, modalSetState) {
              Future<void> loadClassOptions() async {
                if (classOptions.isNotEmpty) return;
                final data = await _classService.fetchClassOptions();
                if (!mounted) return;
                modalSetState(() => classOptions = data);
              }
              loadClassOptions();
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Text('Tambah Siswa',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                      const SizedBox(height: 16),
                      _GlassField(
                        controller: nameCtrl,
                        label: 'Nama',
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Nama wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedClassId,
                        decoration: const InputDecoration(labelText: 'Kelas'),
                        items: classOptions
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name?.trim().isNotEmpty == true
                                    ? '${c.name} (${c.id})'
                                    : c.id),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          modalSetState(() {
                            selectedClassId = value;
                            final label = classOptions
                                .firstWhere(
                                  (c) => c.id == value,
                                  orElse: () => ClassInfo(id: value ?? ''),
                                )
                                .id;
                            classCtrl.text = label;
                          });
                        },
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Kelas wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      _GlassField(
                        controller: addressCtrl,
                        label: 'Alamat',
                      ),
                      const SizedBox(height: 12),
                      _GlassField(
                        controller: phoneCtrl,
                        label: 'Telepon',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: SizedBox(
                          height: 46,
                          width: 200,
                          child: isSaving
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color:
                                              Colors.white.withOpacity(0.18)),
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
                                    backgroundColor:
                                        Colors.white.withOpacity(0.14),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                  onPressed: () async {
                                    final valid =
                                        formKey.currentState?.validate() ??
                                            false;
                                    if (!valid) {
                                      return;
                                    }
                                    modalSetState(() => isSaving = true);
                                    try {
                                      await _service.createStudent(
                                        name: nameCtrl.text.trim(),
                                        className: classCtrl.text.trim(),
                                        address: addressCtrl.text.trim(),
                                        phone: phoneCtrl.text.trim(),
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
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    if (saved == true) _refresh();
  }

  void _showProfileActions() {
    final user = Supabase.instance.client.auth.currentUser;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (user?.email != null) ...[
                const SizedBox(height: 6),
                Text(
                  user!.email!,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await Supabase.instance.client.auth.signOut();
                  },
                  child: const Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Student>>(
        future: _future,
        builder: (context, snapshot) {
          final isLoading = _isLoading ||
              snapshot.connectionState == ConnectionState.waiting ||
              snapshot.connectionState == ConnectionState.active;
          if (isLoading) return const _StudentsSkeleton();
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final students = snapshot.data ?? [];
          final bottomSpacer = MediaQuery.of(context).padding.bottom + 120;
          return CustomScrollView(
            controller: widget.scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                child: _GreetingHero(
                  name: _displayName,
                  greeting: _greetingText(),
                  onNameTap: _showProfileActions,
                ),
              ),
            ),
              // SliverToBoxAdapter(
              //   child: Padding(
              //     padding:
              //         const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              //     child: _HeaderSection(
              //         totalStudents: students.length, onAdd: showAddDialog),
              //   ),
              // ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _FeatureCard(
                    onAdd: showAddDialog,
                    canAdd: widget.canAddStudent,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 22)),
              SliverFillRemaining(
                hasScrollBody: false,
                child: _LiveStudentsSection(
                  students: students,
                  onSeeAll: () => _openDiscover(context, students),
                  bottomPadding: bottomSpacer,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openDiscover(BuildContext context, List<Student> students) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentsDiscoverScreen(
          onAdd: showAddDialog,
          classId: widget.classId,
          canAddStudent: widget.canAddStudent,
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool light;

  const _GlassField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: TextStyle(
          color: light ? Colors.black87 : Colors.white, fontSize: 15.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: light ? Colors.black54 : Colors.white70),
        filled: true,
        fillColor:
            light ? const Color(0xFFF7F7F8) : Colors.white.withOpacity(0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: light ? Colors.black12 : Colors.white24, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: light ? Colors.black : Colors.white, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
      ),
    );
  }
}

class _GreetingHero extends StatelessWidget {
  final String name;
  final String greeting;
  final VoidCallback? onNameTap;

  const _GreetingHero({
    required this.name,
    required this.greeting,
    this.onNameTap,
  });

  String _avatarForName(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) return 'assets/ic_avatar.png';
    final first = trimmed.split(' ').first;
    // Simple heuristic: only treat names ending with 'a' as female, otherwise default to male.
    final endsWithA = first.endsWith('a');
    return endsWithA ? 'assets/ic_avatar_2.png' : 'assets/ic_avatar.png';
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarForName(name);
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wb_sunny_outlined,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onNameTap,
              child: Text(
                name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
        const Spacer(),
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white.withOpacity(0.18),
          backgroundImage: AssetImage(avatar),
          child: Container(),
        ),
      ],
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final int totalStudents;
  final VoidCallback onAdd;

  const _HeaderSection({required this.totalStudents, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 10, 6, 0),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7F7F8), Color(0xFFEAEAEE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _WavePainter(),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selamat datang',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.black54,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Student Rating',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.black.withOpacity(0.08),
                    child: const Icon(Icons.school, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _StatPill(
                    label: 'Total siswa',
                    value: '$totalStudents',
                    icon: Icons.people_alt_rounded,
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black87, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final String title;
  final Student student;
  final VoidCallback onAdd;

  const _HighlightCard({
    required this.title,
    required this.student,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white70,
                      letterSpacing: 0.1,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                student.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                student.className ?? '-',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Chip(
                    label: Text(
                        student.phone.isEmpty ? 'No phone' : student.phone),
                    avatar: const Icon(Icons.phone, size: 16),
                    backgroundColor: Colors.white.withOpacity(0.08),
                    labelStyle: const TextStyle(color: Colors.white70),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onAdd,
                    child: const Text('Tambah lagi'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Belum ada siswa',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan siswa pertama untuk memulai penilaian.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.12),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onAdd,
            child: const Text('Tambah siswa'),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final VoidCallback onAdd;
  final bool canAdd;

  const _FeatureCard({required this.onAdd, required this.canAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF7F7F8), Color(0xFFEAEAF0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: CustomPaint(
            painter: _FeatureCirclePainter(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fitur Unggulan',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.black54,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canAdd
                          ? 'Tambah siswa dan lakukan penilaian untuk melihat ranking terbaik.'
                          : 'Pantau data siswa kelasmu dan lanjutkan penilaian untuk melihat ranking.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.black,
                        fontSize: 17,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (canAdd)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                        ),
                        onPressed: onAdd,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.group_add),
                            SizedBox(width: 8),
                            Text('Tambah Siswa'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveStudentsSection extends StatelessWidget {
  final List<Student> students;
  final VoidCallback onSeeAll;
  final double bottomPadding;

  const _LiveStudentsSection({
    required this.students,
    required this.onSeeAll,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final take = students.take(3).toList();
    return Container(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(34),
          topRight: Radius.circular(34),
        ),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
            child: Row(
              children: [
                Text(
                  'Daftar Siswa',
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800, color: Colors.black87),
                ),
                const Spacer(),
                InkWell(
                  onTap: onSeeAll,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: const [
                        Text(
                          'Lihat semua',
                          style: TextStyle(
                            color: _primaryDark,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            color: _primaryDark, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 8, 30, 8),
            child: _TotalStudentsBadge(total: students.length),
          ),
          ...take.map((s) => Padding(
                padding: const EdgeInsets.fromLTRB(30, 8, 30, 8),
                child: _LiveStudentCard(student: s),
              )),
          SizedBox(height: bottomPadding),
        ],
      ),
    );
  }
}

class _LiveStudentCard extends StatelessWidget {
  final Student student;

  const _LiveStudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StudentDetailScreen(student: student),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFDFDFE),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE9EAF1), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 8),
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              _StudentAvatarIcon(name: student.name),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle(student),
                      style: const TextStyle(
                        color: Color(0xFF777A83),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(Student s) {
    final kelas = s.className?.isNotEmpty == true ? s.className! : 'Kelas -';
    final phone = s.phone.isNotEmpty ? s.phone : 'No phone';
    return '$kelas • $phone';
  }
}

class _TotalStudentsBadge extends StatelessWidget {
  final int total;
  const _TotalStudentsBadge({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.people, color: Colors.black87),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Siswa',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Colors.black87),
                  ),
                  Text(
                    '$total siswa',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          const Icon(Icons.chevron_right, color: Colors.black54),
        ],
      ),
    );
  }
}

class _StudentAvatarIcon extends StatelessWidget {
  final String name;

  const _StudentAvatarIcon({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0] : '?';
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF2F2F5), Color(0xFFE4E6EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF1B1530),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _Bar(height: 10),
                SizedBox(width: 5),
                _Bar(height: 14),
                SizedBox(width: 5),
                _Bar(height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double height;
  const _Bar({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF4A4A4A),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _StudentsSkeleton extends StatelessWidget {
  const _StudentsSkeleton();

  @override
  Widget build(BuildContext context) {
    final bottomSpacer = MediaQuery.of(context).padding.bottom + 140;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 25, vertical: 8),
          child: _ShimmerGreeting(),
        ),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ShimmerBlock(height: 230, radius: 28, margin: EdgeInsets.zero),
        ),
        const SizedBox(height: 18),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child:
                ShimmerBlock(height: 18, radius: 6, margin: EdgeInsets.zero)),
        const SizedBox(height: 12),
        ...List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _ShimmerLiveCard(),
          ),
        ),
        SizedBox(height: bottomSpacer),
      ],
    );
  }
}

class _ShimmerGreeting extends StatelessWidget {
  const _ShimmerGreeting();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: 140,
                  decoration: BoxDecoration(
                    color: const Color(0x33E7E7FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 18,
                  width: 200,
                  decoration: BoxDecoration(
                    color: const Color(0x33E7E7FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x35F4F4FF),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerListItem extends StatelessWidget {
  const _ShimmerListItem();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        height: 82,
        decoration: BoxDecoration(
          color: const Color(0x33E7E7FF),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x35F4F4FF),
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
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 140,
                    decoration: BoxDecoration(
                      color: const Color(0x2FF4F4FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x2AF4F4FF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerLiveCard extends StatelessWidget {
  const _ShimmerLiveCard();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: const Color(0x33E7E7FF),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE7E7FF)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0x35F4F4FF),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(width: 14),
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 120,
                    decoration: BoxDecoration(
                      color: const Color(0x2FF4F4FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0x24FFFFFF),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.black.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final subtleStroke = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawCircle(
        Offset(size.width * 0.82, size.height * 0.22), 110, stroke);
    canvas.drawCircle(
        Offset(size.width * 0.86, size.height * 0.18), 72, subtleStroke);
    canvas.drawCircle(
        Offset(size.width * 0.12, size.height * 0.78), 118, stroke);
    canvas.drawCircle(
        Offset(size.width * 0.18, size.height * 0.82), 74, subtleStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // final paint1 = Paint()
    //   ..color = Colors.grey.withValues(alpha: 0.25)
    //   ..style = PaintingStyle.stroke
    //   ..strokeWidth = 2.2;

    // final path1 = Path()
    //   ..moveTo(-20, size.height * 0.65)
    //   ..quadraticBezierTo(
    //     size.width * 0.2,
    //     size.height * 0.45,
    //     size.width * 0.5,
    //     size.height * 0.7,
    //   )
    //   ..quadraticBezierTo(
    //     size.width * 0.8,
    //     size.height * 0.9,
    //     size.width + 20,
    //     size.height * 0.65,
    //   );
    // canvas.drawPath(path1, paint1);

    final paint2 = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path2 = Path()
      ..moveTo(-10, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.35,
        size.width * 0.6,
        size.height * 0.6,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.75,
        size.width + 10,
        size.height * 0.5,
      );
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
