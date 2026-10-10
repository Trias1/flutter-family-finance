import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

/// The banner set from the admin panel (app_config/announcement, readable by
/// anyone, no personal data). Also shown on the web dashboard.
final announcementProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  // Sign-out shuts Firestore down on the phone; listen again after sign-in.
  ref.watch(authStateProvider.select((u) => u.valueOrNull?.uid));
  return FirebaseFirestore.instance
      .collection('app_config')
      .doc('announcement')
      .snapshots()
      .map((s) => s.data()?['active'] == true ? s.data() : null)
      .handleError((_) {});
});

class AnnouncementBanner extends ConsumerWidget {
  const AnnouncementBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(announcementProvider).valueOrNull;
    if (data == null) return const SizedBox.shrink();
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final id = (data['messageId'] as String?)?.trim() ?? '';
    final en = (data['messageEn'] as String?)?.trim() ?? '';
    final text = isId ? (id.isNotEmpty ? id : en) : (en.isNotEmpty ? en : id);
    if (text.isEmpty) return const SizedBox.shrink();
    final maintenance = data['tone'] == 'maintenance';
    final color = maintenance ? AppTheme.warningColor : AppTheme.primaryColor;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            maintenance ? Icons.build_rounded : Icons.info_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
