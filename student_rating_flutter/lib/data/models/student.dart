class Student {
  Student({
    required this.id,
    required this.name,
    required this.className,
    required this.classId,
    required this.address,
    required this.phone,
  });

  final String id;
  final String name;
  final String className;
  final String? classId;
  final String address;
  final String phone;

  factory Student.fromMap(Map<String, dynamic> map) => Student(
        id: map['student_id'] as String,
        name: map['student_name'] as String,
        className: map['student_class'] as String? ?? '',
        classId: map['class_id'] as String?,
        address: map['student_address'] as String? ?? '',
        phone: map['student_phone'] as String? ?? '',
      );

  Map<String, dynamic> toMap() {
    final resolvedClassId = classId?.trim().isNotEmpty == true
        ? classId
        : (className.trim().isNotEmpty ? className : null);
    return {
      'student_id': id,
      'student_name': name,
      'student_class': className,
      'class_id': resolvedClassId,
      'student_address': address,
      'student_phone': phone,
    };
  }
}
