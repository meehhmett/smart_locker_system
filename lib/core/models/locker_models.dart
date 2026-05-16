class MyLockerResult {
  final String key;
  final Map<String, dynamic> data;
  MyLockerResult({required this.key, required this.data});
}

class PenaltyInfo {
  final int amount;
  final int periods;
  final String description;
  PenaltyInfo({
    required this.amount,
    required this.periods,
    required this.description,
  });
}
