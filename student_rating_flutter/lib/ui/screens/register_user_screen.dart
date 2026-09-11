import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/class_info.dart';
import '../../data/models/student.dart';
import '../../data/services/class_service.dart';
import '../../data/services/student_service.dart';

class RegisterUserScreen extends StatefulWidget {
  const RegisterUserScreen({super.key});

  @override
  State<RegisterUserScreen> createState() => RegisterUserScreenState();
}

class RegisterUserScreenState extends State<RegisterUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentSectionKey = GlobalKey();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController(text: '123456');
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _identityCtrl = TextEditingController();
  final _classFocusNode = FocusNode();
  final _studentFocusNode = FocusNode();

  String _role = 'siswa';
  String _gender = 'L';
  bool _isActive = true;
  bool _loading = false;
  bool _loadingClasses = false;
  bool _loadingStudents = false;
  String? _error;
  String? _result;
  List<ClassInfo> _classes = [];
  String? _selectedClassId;
  List<Student> _students = [];
  String? _selectedStudentId;
  List<String> _roles = const ['siswa', 'wali', 'admin'];

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _loadRoleOptions();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _identityCtrl.dispose();
    _classFocusNode.dispose();
    _studentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    setState(() => _loadingClasses = true);
    try {
      final service = ClassService(Supabase.instance.client);
      final classes = await service.fetchClassOptions();
      if (!mounted) return;
      setState(() => _classes = classes);
    } finally {
      if (mounted) setState(() => _loadingClasses = false);
    }
  }

  Future<void> _loadRoleOptions() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();
      final callerRole = (data?['role'] as String?)?.trim().toLowerCase();
      final roles = callerRole == 'super_admin'
          ? const ['siswa', 'wali', 'admin', 'super_admin']
          : const ['siswa', 'wali', 'admin'];
      if (!mounted) return;
      setState(() {
        _roles = roles;
        if (!_roles.contains(_role)) _role = 'siswa';
      });
    } catch (_) {
      // Keep default role options on profile read failure.
    }
  }

  Future<void> _loadStudentsForClass(
    String? classId, {
    bool focusStudentAfterLoad = false,
  }) async {
    if (_role != 'siswa') return;
    final trimmed = classId?.trim() ?? '';
    if (trimmed.isEmpty) {
      setState(() {
        _students = [];
        _selectedStudentId = null;
        _fullNameCtrl.clear();
      });
      return;
    }
    setState(() {
      _loadingStudents = true;
      _students = [];
      _selectedStudentId = null;
    });
    try {
      final service = StudentService(Supabase.instance.client);
      final students = await service.fetchStudents(classId: trimmed);
      if (!mounted) return;
      setState(() {
        _students = students;
        _selectedStudentId = students.length == 1 ? students.first.id : null;
        if (_selectedStudentId != null) {
          final selected = students.firstWhere(
            (s) => s.id == _selectedStudentId,
            orElse: () => students.first,
          );
          _fullNameCtrl.text = selected.name;
        } else {
          _fullNameCtrl.clear();
        }
      });
      if (focusStudentAfterLoad && students.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final sectionContext = _studentSectionKey.currentContext;
          if (sectionContext != null) {
            Scrollable.ensureVisible(
              sectionContext,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: 0.2,
            );
          }
          _studentFocusNode.requestFocus();
        });
      }
    } finally {
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    if (_role == 'siswa' && _selectedStudentId == null) {
      setState(() {
        _error = 'Pilih siswa dari daftar kelas.';
        _loading = false;
      });
      return;
    }
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) {
      setState(() {
        _error = 'Tidak ada sesi login (token kosong).';
        _loading = false;
      });
      return;
    }

    final body = {
      'email': _emailCtrl.text.trim(),
      'password': _passwordCtrl.text,
      'role': _role,
      'class_id': _selectedClassId,
      'full_name': _fullNameCtrl.text.trim().isEmpty
          ? _emailCtrl.text.trim()
          : _fullNameCtrl.text.trim(),
      'student_id': _selectedStudentId,
      'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      'identity_number':
          _identityCtrl.text.trim().isEmpty ? null : _identityCtrl.text.trim(),
      'gender': _gender,
      'is_active': _isActive,
    };

    try {
      final resp = await client.functions.invoke(
        'register_user',
        body: body,
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      if (!mounted) return;
      setState(() {
        _result = resp.data?['user_id']?.toString() ?? 'Berhasil';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputFill = Colors.white.withValues(alpha: 0.96);
    final inputBorder = BorderSide(color: Colors.black.withValues(alpha: 0.10));
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Registrasi User',
                    style: TextStyle(
                      color: Color(0xFF1C1C1E),
                      fontWeight: FontWeight.w800,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Buat akun siswa, wali, admin, atau super admin.',
                    style: TextStyle(
                      color: Color(0xFF636366),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _decoration('Email', inputFill, inputBorder),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Email wajib diisi' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration:
                        _decoration('Password (min. 6 karakter)', inputFill, inputBorder),
                    validator: (v) =>
                        v == null || v.length < 6 ? 'Min 6 karakter' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _fullNameCtrl,
                    readOnly: _role == 'siswa',
                    decoration: _decoration(
                      _role == 'siswa'
                          ? 'Nama lengkap (otomatis dari siswa)'
                          : 'Nama lengkap (opsional)',
                      inputFill,
                      inputBorder,
                    ),
                    validator: (v) {
                      if (_role == 'wali' && (v == null || v.trim().isEmpty)) {
                        return 'Nama lengkap wali wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _role,
                    decoration: _decoration('Role', inputFill, inputBorder),
                    items: _roles
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _role = v ?? 'siswa';
                        if (_role != 'siswa') {
                          _students = [];
                          _selectedStudentId = null;
                        } else {
                          _loadStudentsForClass(
                            _selectedClassId,
                            focusStudentAfterLoad: true,
                          );
                        }
                      });
                      if (_role == 'siswa') {
                        _classFocusNode.requestFocus();
                      }
                    },
                  ),
                  if (_role == 'wali') ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _decoration('Telepon wali', inputFill, inputBorder),
                      validator: (v) {
                        if (_role == 'wali' && (v == null || v.trim().isEmpty)) {
                          return 'Telepon wali wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _identityCtrl,
                      decoration: _decoration(
                        'NIP/NIK wali (opsional)',
                        inputFill,
                        inputBorder,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: _decoration('Gender', inputFill, inputBorder),
                      items: const [
                        DropdownMenuItem(value: 'L', child: Text('Laki-laki')),
                        DropdownMenuItem(value: 'P', child: Text('Perempuan')),
                      ],
                      onChanged: (v) => setState(() => _gender = v ?? 'L'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _addressCtrl,
                      maxLines: 2,
                      decoration: _decoration(
                        'Alamat wali (opsional)',
                        inputFill,
                        inputBorder,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isActive,
                      activeTrackColor: Colors.black,
                      activeColor: Colors.white,
                      title: const Text(
                        'Akun aktif',
                        style: TextStyle(
                          color: Color(0xFF1C1C1E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Nonaktifkan jika akun belum boleh login.',
                        style: TextStyle(color: Color(0xFF636366)),
                      ),
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    isExpanded: true,
                    focusNode: _classFocusNode,
                    decoration: _decoration(
                      _loadingClasses
                          ? 'Memuat daftar kelas...'
                          : 'Kelas (untuk siswa/wali)',
                      inputFill,
                      inputBorder,
                    ),
                    items: _classes
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.name?.trim().isNotEmpty == true
                                  ? '${c.id} - ${c.name!.trim()}'
                                  : c.id,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _loadingClasses
                        ? null
                        : (value) {
                            setState(() {
                              _selectedClassId = value;
                              _selectedStudentId = null;
                              _students = [];
                              if (_role == 'siswa') _fullNameCtrl.clear();
                            });
                            _loadStudentsForClass(
                              value,
                              focusStudentAfterLoad: true,
                            );
                          },
                    validator: (v) {
                      if ((_role == 'siswa' || _role == 'wali') &&
                          (v == null || v.trim().isEmpty)) {
                        return 'Kelas wajib untuk siswa/wali';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            if (_role == 'siswa') ...[
              const SizedBox(height: 12),
              Container(
                key: _studentSectionKey,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data Siswa',
                      style: TextStyle(
                        color: Color(0xFF1C1C1E),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_loadingStudents) const LinearProgressIndicator(minHeight: 2),
                    DropdownButtonFormField<String>(
                      value: _selectedStudentId,
                      focusNode: _studentFocusNode,
                      decoration: _decoration('Pilih siswa', inputFill, inputBorder),
                      items: _students
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text('${s.name} (${s.className})'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedStudentId = v;
                          if (v == null) {
                            _fullNameCtrl.clear();
                            return;
                          }
                          final selected = _students.firstWhere(
                            (s) => s.id == v,
                            orElse: () => _students.first,
                          );
                          _fullNameCtrl.text = selected.name;
                        });
                      },
                    ),
                    if (!_loadingStudents && _students.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Tidak ada siswa di kelas ini.',
                          style: TextStyle(
                            color: Color(0xFF636366),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_error != null)
              _BannerMessage(
                text: _error!,
                isError: true,
              ),
            if (_result != null)
              _BannerMessage(
                text: 'Berhasil: $_result',
                isError: false,
              ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Daftarkan User',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(
    String label,
    Color fillColor,
    BorderSide borderSide,
  ) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: borderSide,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: borderSide,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black, width: 1.1),
      ),
    );
  }
}

class _BannerMessage extends StatelessWidget {
  final String text;
  final bool isError;

  const _BannerMessage({
    required this.text,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isError
        ? const Color(0x1AF44336)
        : Colors.black.withValues(alpha: 0.06);
    final color = isError ? const Color(0xFF9A2A2A) : const Color(0xFF1C1C1E);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
