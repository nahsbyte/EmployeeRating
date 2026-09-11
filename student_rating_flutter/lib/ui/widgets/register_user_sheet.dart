import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/student.dart';
import '../../data/services/student_service.dart';

class RegisterUserSheet extends StatefulWidget {
  const RegisterUserSheet({super.key});

  @override
  State<RegisterUserSheet> createState() => _RegisterUserSheetState();
}

class _RegisterUserSheetState extends State<RegisterUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController(text: '123456');
  final _fullNameCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  String _role = 'siswa';
  bool _loading = false;
  String? _error;
  String? _result;
  bool _loadingStudents = false;
  List<Student> _students = [];
  String? _selectedStudentId;
  List<String> _roles = const ['siswa', 'wali', 'admin'];

  @override
  void initState() {
    super.initState();
    _loadRoleOptions();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _fullNameCtrl.dispose();
    _classCtrl.dispose();
    super.dispose();
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
        if (!_roles.contains(_role)) {
          _role = 'siswa';
        }
      });
    } catch (_) {
      // Keep default roles when profile read fails.
    }
  }

  Future<void> _loadStudentsForClass(String classId) async {
    if (_role != 'siswa') return;
    final trimmed = classId.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _students = [];
        _selectedStudentId = null;
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
        _selectedStudentId =
            students.length == 1 ? students.first.id : null;
      });
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
    if (_role == 'siswa' && (_selectedStudentId == null)) {
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
      'class_id': _classCtrl.text.trim().isEmpty ? null : _classCtrl.text.trim(),
      'full_name': _fullNameCtrl.text.trim().isEmpty
          ? _emailCtrl.text.trim()
          : _fullNameCtrl.text.trim(),
      'student_id': _selectedStudentId,
    };

    try {
      final resp = await client.functions.invoke(
        'register_user',
        body: body,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );
      setState(() {
        _result = resp.data?['user_id']?.toString() ?? 'Berhasil';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Registrasi User',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Email wajib diisi' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
              validator: (v) =>
                  v == null || v.length < 6 ? 'Min 6 karakter' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _fullNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama lengkap (opsional)',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Role'),
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
                    _loadStudentsForClass(_classCtrl.text);
                  }
                });
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _classCtrl,
              decoration: const InputDecoration(
                labelText: 'Class ID (untuk wali/siswa)',
              ),
              onChanged: (value) => _loadStudentsForClass(value),
              validator: (v) {
                if ((_role == 'siswa' || _role == 'wali') &&
                    (v == null || v.trim().isEmpty)) {
                  return 'Class ID wajib untuk siswa/wali';
                }
                return null;
              },
            ),
            if (_role == 'siswa') ...[
              const SizedBox(height: 10),
              if (_loadingStudents)
                const LinearProgressIndicator(minHeight: 2),
              DropdownButtonFormField<String>(
                value: _selectedStudentId,
                decoration: const InputDecoration(labelText: 'Pilih siswa'),
                items: _students
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.name} (${s.className})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedStudentId = v),
              ),
              if (!_loadingStudents && _students.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Tidak ada siswa di kelas ini.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            if (_result != null)
              Text(
                'Berhasil: $_result',
                style: const TextStyle(color: Colors.green),
              ),
            const SizedBox(height: 10),
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
                        'Daftarkan',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
