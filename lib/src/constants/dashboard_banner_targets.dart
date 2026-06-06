/// In-app banner tap targets — `id` must match mobile `DashboardBannerTargets`.
class DashboardBannerTargetOption {
  const DashboardBannerTargetOption({
    required this.id,
    required this.label,
    required this.group,
  });

  final String id;
  final String label;
  final String group;
}

abstract final class DashboardBannerTargetOptions {
  static const tabs = [
    DashboardBannerTargetOption(id: 'home', label: 'Home', group: 'Main tabs'),
    DashboardBannerTargetOption(
      id: 'content_library',
      label: 'Content Library',
      group: 'Main tabs',
    ),
    DashboardBannerTargetOption(
      id: 'medical_colleges',
      label: 'Medical Colleges',
      group: 'Main tabs',
    ),
    DashboardBannerTargetOption(
      id: 'courses',
      label: 'Courses',
      group: 'Main tabs',
    ),
  ];

  static const screens = [
    DashboardBannerTargetOption(
      id: 'expected_score',
      label: 'Expected NEET Score',
      group: 'App screens',
    ),
    DashboardBannerTargetOption(
      id: 'messages',
      label: 'Messages',
      group: 'App screens',
    ),
    DashboardBannerTargetOption(
      id: 'updates',
      label: 'Updates',
      group: 'App screens',
    ),
    DashboardBannerTargetOption(
      id: 'timeline',
      label: 'Timeline',
      group: 'App screens',
    ),
    DashboardBannerTargetOption(
      id: 'webinars',
      label: 'Webinars',
      group: 'App screens',
    ),
    DashboardBannerTargetOption(
      id: 'profile',
      label: 'Profile',
      group: 'App screens',
    ),
    DashboardBannerTargetOption(
      id: 'nri_eligibility',
      label: 'NRI Eligibility',
      group: 'App screens',
    ),
    DashboardBannerTargetOption(
      id: 'eligibility_wizard',
      label: 'Eligibility check',
      group: 'App screens',
    ),
    DashboardBannerTargetOption(
      id: 'days_left',
      label: 'Days left',
      group: 'App screens',
    ),
    DashboardBannerTargetOption(
      id: 'parents_guide',
      label: 'NEET parents guide',
      group: 'App screens',
    ),
    DashboardBannerTargetOption(
      id: 'buy_subscription',
      label: 'Buy subscription',
      group: 'App screens',
    ),
  ];

  static List<DashboardBannerTargetOption> get all => [...tabs, ...screens];

  static String? labelFor(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final t in all) {
      if (t.id == id) return t.label;
    }
    return null;
  }
}

enum BannerLinkKind { none, external, app, landing }
