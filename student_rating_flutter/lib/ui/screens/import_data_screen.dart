import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/class_info.dart';
import '../../data/models/student.dart';
import '../../data/services/class_service.dart';
import '../../data/services/student_service.dart';

enum _ImportKind { classes, students }

class ImportDataScreen extends StatefulWidget {
  const ImportDataScreen({super.key});

  @override
  State<ImportDataScreen> createState() => ImportDataScreenState();
}

class ImportDataScreenState extends State<ImportDataScreen> {
  _ImportKind _kind = _ImportKind.students;
  String? _fileName;
  bool _parsing = false;
  bool _importing = false;
  String? _error;
  String? _result;

  List<Map<String, String>> _rows = [];
  List<String> _validationErrors = [];

  late final ClassService _classService;
  late final StudentService _studentService;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _classService = ClassService(client);
    _studentService = StudentService(client);
  }

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _result = null;
      _validationErrors = [];
    });
    final file = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    if (file == null || file.files.isEmpty) return;
    final picked = file.files.first;
    final bytes = picked.bytes;
    if (bytes == null) {
      setState(() => _error = 'Gagal membaca file.');
      return;
    }

    setState(() => _parsing = true);
    try {
      final ext = (picked.extension ?? '').trim().toLowerCase();
      final raw = ext == 'xlsx' ? _parseXlsx(bytes) : _parseCsv(bytes);
      if (raw.isEmpty) {
        setState(() => _error = 'File kosong.');
        return;
      }
      final headers = raw.first
          .map((e) => e.toString().trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();
      if (headers.isEmpty) {
        setState(() => _error = 'Header file tidak valid.');
        return;
      }

      final rows = <Map<String, String>>[];
      for (var i = 1; i < raw.length; i++) {
        final cols = raw[i];
        if (cols.isEmpty) continue;
        final map = <String, String>{};
        for (var c = 0; c < headers.length; c++) {
          final value = c < cols.length ? cols[c] : '';
          map[headers[c]] = value.toString().trim();
        }
        final hasAnyValue = map.values.any((v) => v.isNotEmpty);
        if (hasAnyValue) rows.add(map);
      }

      setState(() {
        _fileName = picked.name;
        _rows = rows;
      });
      await _validateRows();
    } catch (e) {
      setState(() => _error = 'Gagal parsing file: $e');
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  List<List<dynamic>> _parseCsv(Uint8List bytes) {
    final csvText = utf8.decode(bytes, allowMalformed: true);
    return const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(csvText);
  }

  List<List<dynamic>> _parseXlsx(Uint8List bytes) {
    final excel = xls.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];
    final table = excel.tables.values.first;
    final rows = <List<dynamic>>[];
    for (final row in table.rows) {
      rows.add(
        row.map((cell) => cell?.value?.toString() ?? '').toList(),
      );
    }
    return rows;
  }

  Future<void> _validateRows() async {
    final errors = <String>[];
    if (_rows.isEmpty) {
      errors.add('Tidak ada data baris untuk diimport.');
      setState(() => _validationErrors = errors);
      return;
    }

    if (_kind == _ImportKind.classes) {
      final seen = <String>{};
      for (var i = 0; i < _rows.length; i++) {
        final r = _rows[i];
        final classId = _v(r, ['class_id', 'kelas_id', 'id_kelas']);
        if (classId.isEmpty) {
          errors.add('Baris ${i + 2}: class_id wajib diisi.');
          continue;
        }
        if (!seen.add(classId.toLowerCase())) {
          errors.add('Baris ${i + 2}: class_id duplikat ($classId).');
        }
      }
    } else {
      final classOptions = await _classService.fetchClassOptions();
      final classIds = classOptions.map((c) => c.id.trim().toLowerCase()).toSet();
      final seenStudent = <String>{};
      for (var i = 0; i < _rows.length; i++) {
        final r = _rows[i];
        final sid = _v(r, ['student_id', 'id_siswa']);
        final name = _v(r, ['student_name', 'nama_siswa']);
        final classId = _v(r, ['class_id', 'kelas_id']);
        if (sid.isEmpty) errors.add('Baris ${i + 2}: student_id wajib diisi.');
        if (name.isEmpty) errors.add('Baris ${i + 2}: student_name wajib diisi.');
        if (classId.isEmpty) {
          errors.add('Baris ${i + 2}: class_id wajib diisi.');
        } else if (!classIds.contains(classId.toLowerCase())) {
          errors.add('Baris ${i + 2}: class_id $classId tidak ditemukan.');
        }
        if (sid.isNotEmpty && !seenStudent.add(sid.toLowerCase())) {
          errors.add('Baris ${i + 2}: student_id duplikat ($sid).');
        }
      }
    }

    setState(() => _validationErrors = errors);
  }

  Future<void> _runImport() async {
    setState(() {
      _error = null;
      _result = null;
    });
    await _validateRows();
    if (_validationErrors.isNotEmpty) {
      setState(() => _error = 'Perbaiki error validasi sebelum import.');
      return;
    }

    setState(() => _importing = true);
    try {
      if (_kind == _ImportKind.classes) {
        final classes = _rows
            .map(
              (r) => ClassInfo(
                id: _v(r, ['class_id', 'kelas_id', 'id_kelas']),
                name: _v(r, ['class_name', 'nama_kelas']),
              ),
            )
            .toList();
        await _classService.upsertClassesBulk(classes);
        setState(() => _result = 'Import kelas berhasil: ${classes.length} baris.');
      } else {
        final students = _rows
            .map(
              (r) {
                final classId = _v(r, ['class_id', 'kelas_id']);
                return Student(
                  id: _v(r, ['student_id', 'id_siswa']),
                  name: _v(r, ['student_name', 'nama_siswa']),
                  className: classId,
                  classId: classId,
                  address: _v(r, ['student_address', 'alamat']),
                  phone: _v(r, ['student_phone', 'telepon']),
                );
              },
            )
            .toList();
        await _studentService.upsertStudentsBulk(students);
        setState(() => _result = 'Import siswa berhasil: ${students.length} baris.');
      }
    } catch (e) {
      setState(() => _error = 'Gagal import: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _reset() {
    setState(() {
      _fileName = null;
      _rows = [];
      _error = null;
      _result = null;
      _validationErrors = [];
    });
  }

  String _v(Map<String, String> row, List<String> aliases) {
    for (final a in aliases) {
      final val = row[a.toLowerCase()]?.trim();
      if (val != null && val.isNotEmpty) return val;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _parsing || _importing;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Import Data',
                  style: TextStyle(
                    color: Color(0xFF1C1C1E),
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Upload file CSV/XLSX untuk import massal data kelas atau siswa.',
                  style: TextStyle(
                    color: Color(0xFF636366),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<_ImportKind>(
                  segments: const [
                    ButtonSegment(
                      value: _ImportKind.classes,
                      label: Text('Kelas'),
                      icon: Icon(Icons.grid_view_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: _ImportKind.students,
                      label: Text('Siswa'),
                      icon: Icon(Icons.people_alt_rounded, size: 18),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: disabled
                      ? null
                      : (s) async {
                          setState(() => _kind = s.first);
                          if (_rows.isNotEmpty) {
                            await _validateRows();
                          }
                        },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.black;
                      }
                      return Colors.white;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return Colors.black87;
                    }),
                    side: WidgetStateProperty.all(
                      BorderSide(color: Colors.black.withValues(alpha: 0.10)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  child: Text(
                    'Format file didukung: .csv / .xlsx',
                    style: const TextStyle(
                      color: Color(0xFF3A3A3C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  child: Text(
                    _kind == _ImportKind.classes
                        ? 'Template header: class_id, class_name'
                        : 'Template header: student_id, student_name, class_id, student_address, student_phone',
                    style: const TextStyle(
                      color: Color(0xFF3A3A3C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: disabled ? null : _pickFile,
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text('Pilih File'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: disabled ? null : _reset,
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
                if (_fileName != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'File: $_fileName',
                    style: const TextStyle(
                      color: Color(0xFF1C1C1E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_validationErrors.isNotEmpty)
            _MessageCard(
              title: 'Validasi Gagal',
              body: _validationErrors.take(8).join('\n'),
              isError: true,
            ),
          if (_error != null)
            _MessageCard(
              title: 'Error',
              body: _error!,
              isError: true,
            ),
          if (_result != null)
            _MessageCard(
              title: 'Sukses',
              body: _result!,
              isError: false,
            ),
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview (${_rows.length} baris)',
                    style: const TextStyle(
                      color: Color(0xFF1C1C1E),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._rows.take(5).map(
                        (r) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            r.entries
                                .take(4)
                                .map((e) => '${e.key}: ${e.value}')
                                .join(' • '),
                            style: const TextStyle(
                              color: Color(0xFF3A3A3C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  if (_rows.length > 5)
                    Text(
                      '+${_rows.length - 5} baris lainnya',
                      style: const TextStyle(
                        color: Color(0xFF636366),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: disabled || _rows.isEmpty ? null : _runImport,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _importing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_rounded, size: 18),
              label: Text(_importing ? 'Mengimpor...' : 'Import Sekarang'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String title;
  final String body;
  final bool isError;

  const _MessageCard({
    required this.title,
    required this.body,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0x1AF44336)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isError ? const Color(0xFF9A2A2A) : const Color(0xFF1C1C1E),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              color: isError ? const Color(0xFF9A2A2A) : const Color(0xFF3A3A3C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
