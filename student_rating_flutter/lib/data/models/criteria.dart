class Criteria {
  Criteria({
    required this.id,
    required this.name,
    required this.amount,
    required this.desc,
  });

  final String id;
  final String name;
  final int amount;
  final String desc; // "core" or "secondary"

  factory Criteria.fromMap(Map<String, dynamic> map) => Criteria(
        id: map['criteria_id'] as String,
        name: map['criteria_name'] as String,
        amount: (map['criteria_amount'] as num).toInt(),
        desc: map['criteria_desc'] as String,
      );

  Map<String, dynamic> toMap() => {
        'criteria_id': id,
        'criteria_name': name,
        'criteria_amount': amount,
        'criteria_desc': desc,
      };
}
