import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/auth_service.dart';
import '../widgets/app_surface.dart';
import 'access_pending_screen.dart';
import 'criteria_screen.dart';
import 'class_manage_screen.dart';
import 'import_data_screen.dart';
import 'login_screen.dart';
import 'register_user_screen.dart';
import 'ranking_screen.dart';
import 'rating_screen.dart';
import 'student_profile_screen.dart';
import 'students_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const Set<String> _allowedRoles = {
    'super_admin',
    'admin',
    'wali',
    'siswa',
  };
  int _currentIndex = 0;
  bool _signingOut = false;
  bool _roleLoading = true;
  String? _role;
  String? _classId;
  String? _studentId;
  String? _profileName;

  final GlobalKey<StudentsScreenState> _studentsKey =
      GlobalKey<StudentsScreenState>();
  final GlobalKey<CriteriaScreenState> _criteriaKey =
      GlobalKey<CriteriaScreenState>();
  final GlobalKey<ClassManageScreenState> _classKey =
      GlobalKey<ClassManageScreenState>();
  final GlobalKey<RatingScreenState> _ratingKey =
      GlobalKey<RatingScreenState>();
  final GlobalKey<RankingScreenState> _rankingKey =
      GlobalKey<RankingScreenState>();
  late TabController _tabController;

  AuthService get _auth => AuthService(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _tabController = _buildTabController(length: 4);
    _loadRole();
  }

  TabController _buildTabController({required int length}) {
    return TabController(
      length: length,
      vsync: this,
      initialIndex: _currentIndex.clamp(0, length - 1),
    )..addListener(() {
        if (!_tabController.indexIsChanging) {
          _onNavTap(_tabController.index);
        }
      });
  }

  Future<void> _loadRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _roleLoading = false);
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('role, class_id, student_id, full_name')
          .eq('user_id', user.id)
          .maybeSingle();
      if (!mounted) return;
      final normalizedRole = _normalizeRole(data?['role']);
      setState(() {
        _role = normalizedRole;
        _classId = data?['class_id'] as String?;
        _studentId = data?['student_id'] as String?;
        _profileName = data?['full_name'] as String?;
        _roleLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _roleLoading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_roleLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const LoginScreen();
    }
    if (!_hasValidRole()) {
      return AccessPendingScreen(
        role: _role,
        signingOut: _signingOut,
        onSignOut: _signOut,
      );
    }

    final tabs = _tabsForRole();
    if (_tabController.length != tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _tabController.dispose();
        _tabController = _buildTabController(length: tabs.length);
        setState(() => _currentIndex = _tabController.index);
      });
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    const barSurface = Colors.black;
    final iconColor = Colors.white.withOpacity(0.95);
    final unselectedIcon = Colors.white70;
    const indicatorColor = Colors.transparent;
    final barRadius = BorderRadius.circular(28);
    final screenWidth = MediaQuery.of(context).size.width;
    final tabCount = tabs.length;
    final desiredBarWidth = (tabCount * 52.0) + 24.0;
    final barWidth = desiredBarWidth.clamp(180.0, screenWidth - 32);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: null,
      body: Stack(
        children: [
          BottomBar(
            fit: StackFit.expand,
            width: barWidth,
            offset: 18,
            barColor: Colors.transparent,
            borderRadius: barRadius,
            barDecoration: BoxDecoration(
              color: barSurface,
              borderRadius: barRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.06),
                  Colors.white.withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            hideOnScroll: true,
            scrollOpposite: false,
            body: (context, controller) {
              return AppBackground(
                safeBottom: _currentIndex != 0,
                padding: _currentIndex == 0
                    ? EdgeInsets.zero
                    : const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(),
                        children:
                            tabs.map((tab) => tab.builder(controller)).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: SafeArea(
              top: false,
              child: Material(
                color: Colors.transparent,
                borderRadius: barRadius,
                child: TabBar(
                  controller: _tabController,
                  onTap: _onNavTap,
                  isScrollable: false,
                  labelPadding: EdgeInsets.zero,
                  indicatorPadding: EdgeInsets.zero,
                  indicatorColor: indicatorColor,
                  indicator: const UnderlineTabIndicator(
                    borderSide: BorderSide(color: Colors.transparent, width: 0),
                    insets: EdgeInsets.zero,
                  ),
                  splashFactory: NoSplash.splashFactory,
                  overlayColor:
                      const MaterialStatePropertyAll(Colors.transparent),
                  dividerColor: Colors.transparent,
                  labelColor: iconColor,
                  unselectedLabelColor: unselectedIcon,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: tabs.map((tab) => tab.tab).toList(),
                ),
              ),
            ),
          ),
          if (_signingOut)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          Positioned(
            left: 16,
            top: MediaQuery.of(context).padding.top + 12,
            child: _RoleContextChip(
              role: _role ?? '-',
              classId: _classId,
            ),
          ),
        ],
      ),
    );
  }

  bool _canManageClasses() => _role == 'super_admin' || _role == 'admin';
  bool _isWali() => _role == 'wali';
  bool _hasValidRole() => _role != null && _allowedRoles.contains(_role);

  String? _normalizeRole(dynamic rawRole) {
    if (rawRole is! String) return null;
    final role = rawRole.trim().toLowerCase();
    if (role == 'superadmin') return 'super_admin';
    return role;
  }

  List<_HomeTab> _tabsForRole() {
    if (_role == 'siswa') {
      return [
          _HomeTab(
            tab: const Tab(icon: Icon(Icons.person, size: 20)),
            builder: (_) => StudentProfileScreen(
              profileName: _profileName?.trim().isNotEmpty == true
                  ? _profileName!.trim()
                  : _displayName(),
              classId: _classId,
              studentId: _studentId,
              onSignOut: _signOut,
            ),
          ),
        _HomeTab(
          tab: const Tab(icon: Icon(Icons.emoji_events, size: 20)),
          builder: (_) => RankingScreen(
            key: _rankingKey,
            classId: _classId,
          ),
        ),
      ];
    }
    final tabs = <_HomeTab>[
      _HomeTab(
        tab: const Tab(icon: Icon(Icons.home, size: 20)),
        builder: (controller) => StudentsScreen(
          key: _studentsKey,
          scrollController: controller,
          classId: _isWali() ? _classId : null,
          canAddStudent: !_isWali(),
        ),
      ),
    ];
    if (_canManageClasses()) {
      tabs.add(
        _HomeTab(
          tab: const Tab(icon: Icon(Icons.list_alt, size: 20)),
          builder: (_) => CriteriaScreen(key: _criteriaKey),
        ),
      );
    }
    if (_canManageClasses()) {
      tabs.add(
        _HomeTab(
          tab: const Tab(icon: Icon(Icons.grid_view_rounded, size: 20)),
          builder: (_) => ClassManageScreen(key: _classKey),
        ),
      );
      tabs.add(
        _HomeTab(
          tab: const Tab(icon: Icon(Icons.person_add_alt_1, size: 20)),
          builder: (_) => const RegisterUserScreen(),
        ),
      );
      tabs.add(
        _HomeTab(
          tab: const Tab(icon: Icon(Icons.file_upload_outlined, size: 20)),
          builder: (_) => const ImportDataScreen(),
        ),
      );
    }
    tabs.add(
      _HomeTab(
        tab: const Tab(icon: Icon(Icons.assignment, size: 20)),
        builder: (_) => RatingScreen(
          key: _ratingKey,
          classId: _isWali() ? _classId : null,
        ),
      ),
    );
    tabs.add(
      _HomeTab(
        tab: const Tab(icon: Icon(Icons.emoji_events, size: 20)),
        builder: (_) => RankingScreen(
          key: _rankingKey,
          classId: _isWali() ? _classId : null,
        ),
      ),
    );
    return tabs;
  }

  String _displayName() {
    if (_profileName != null && _profileName!.trim().isNotEmpty) {
      return _profileName!.trim();
    }
    final user = Supabase.instance.client.auth.currentUser;
    final metaName = user?.userMetadata?['name'];
    if (metaName is String && metaName.trim().isNotEmpty) return metaName;
    final email = user?.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Siswa';
  }

  void _onNavTap(int value) {
    setState(() => _currentIndex = value);
    if (_tabController.index != value) {
      _tabController.animateTo(value);
    }
    if (_role == 'siswa') {
      if (value == 1) {
        _rankingKey.currentState?.reload();
      }
      return;
    }
    if (_canManageClasses()) {
      switch (value) {
        case 0:
          _studentsKey.currentState?.refreshIfEmpty();
          break;
        case 1:
          _criteriaKey.currentState?.refreshIfEmpty();
          break;
        case 2:
          _classKey.currentState?.refreshIfEmpty();
          break;
        case 3:
          break;
        case 4:
          break;
        case 5:
          _ratingKey.currentState?.reload();
          break;
        case 6:
          _rankingKey.currentState?.reload();
          break;
      }
      return;
    }
    if (_isWali()) {
      switch (value) {
        case 0:
          _studentsKey.currentState?.refreshIfEmpty();
          break;
        case 1:
          _ratingKey.currentState?.reload();
          break;
        case 2:
          _rankingKey.currentState?.reload();
          break;
      }
      return;
    }
    switch (value) {
      case 0:
        _studentsKey.currentState?.refreshIfEmpty();
        break;
      case 1:
        _ratingKey.currentState?.reload();
        break;
      case 2:
        _rankingKey.currentState?.reload();
        break;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _RoleContextChip extends StatelessWidget {
  final String role;
  final String? classId;

  const _RoleContextChip({
    required this.role,
    required this.classId,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = role.trim().toLowerCase();
    final prettyRole = switch (normalized) {
      'super_admin' => 'Super Admin',
      'admin' => 'Admin',
      'wali' => 'Wali',
      'siswa' => 'Siswa',
      _ => role,
    };
    final classText = classId?.trim();
    final text = (classText != null && classText.isNotEmpty)
        ? '$prettyRole • $classText'
        : prettyRole;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HomeTab {
  final Tab tab;
  final Widget Function(ScrollController? controller) builder;

  const _HomeTab({required this.tab, required this.builder});
}
