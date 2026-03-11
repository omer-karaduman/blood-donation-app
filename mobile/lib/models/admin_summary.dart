// mobile/lib/models/admin_summary.dart

class AdminSummary {
  final int totalDonors;
  final int activeRequests;

  AdminSummary({required this.totalDonors, required this.activeRequests});

  // Backend'den (main.py) gelen JSON verisini modele dönüştürür
  factory AdminSummary.fromJson(Map<String, dynamic> json) {
    return AdminSummary(
      totalDonors: json['total_donors'] ?? 0,
      activeRequests: json['active_requests'] ?? 0,
    );
  }
}