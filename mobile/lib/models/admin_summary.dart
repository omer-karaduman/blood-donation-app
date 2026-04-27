// mobile/lib/models/admin_summary.dart

class AdminSummary {
  final int totalDonors;
  final int activeRequests;
  final int totalInstitutions;
  final int totalStaff;

  AdminSummary({
    required this.totalDonors,
    required this.activeRequests,
    required this.totalInstitutions,
    required this.totalStaff,
  });

  factory AdminSummary.fromJson(Map<String, dynamic> json) {
    return AdminSummary(
      totalDonors: json['total_donors'] ?? 0,
      activeRequests: json['active_requests'] ?? 0,
      totalInstitutions: json['total_institutions'] ?? 0,
      totalStaff: json['total_staff'] ?? 0,
    );
  }
}