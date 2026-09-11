class RatingValue {
  RatingValue({
    this.k1 = 0,
    this.k2 = 0,
    this.k3 = 0,
    this.k4 = 0,
    this.k5 = 0,
  });

  final int k1;
  final int k2;
  final int k3;
  final int k4;
  final int k5;

  factory RatingValue.fromMap(Map<String, dynamic> map) => RatingValue(
        k1: (map['K1'] as num?)?.toInt() ?? 0,
        k2: (map['K2'] as num?)?.toInt() ?? 0,
        k3: (map['K3'] as num?)?.toInt() ?? 0,
        k4: (map['K4'] as num?)?.toInt() ?? 0,
        k5: (map['K5'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'K1': k1,
        'K2': k2,
        'K3': k3,
        'K4': k4,
        'K5': k5,
      };
}
