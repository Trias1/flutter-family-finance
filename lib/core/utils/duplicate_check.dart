import 'package:flutter/material.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';

/// A record already saved, reduced to what matters for spotting doubles.
typedef RecentEntry = ({
  String userId,
  double amount,
  String category,
  DateTime createdAt,
});

/// How far back a matching entry counts as "probably the same purchase".
const duplicateWindow = Duration(hours: 3);

/// When someone (often another family member) saved the same category and
/// amount within [duplicateWindow], asks before saving a second copy. The
/// user decides: buying the same thing twice is legitimate. Returns true to
/// save.
Future<bool> confirmIfDuplicate({
  required BuildContext context,
  required Iterable<RecentEntry> recent,
  required double amount,
  required String category,
  required String myUid,
  required Map<String, String> memberNames,
  required bool isId,
}) async {
  final now = DateTime.now();
  final matches =
      recent
          .where(
            (e) =>
                e.category == category &&
                (e.amount - amount).abs() < 0.005 &&
                now.difference(e.createdAt) <= duplicateWindow &&
                !e.createdAt.isAfter(now.add(const Duration(minutes: 1))),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  if (matches.isEmpty) return true;

  final match = matches.first;
  final who = match.userId == myUid
      ? (isId ? 'kamu sendiri' : 'you')
      : (memberNames[match.userId] ??
            (isId ? 'anggota lain' : 'another member'));
  final minutes = now.difference(match.createdAt).inMinutes;
  final ago = minutes < 1
      ? (isId ? 'barusan' : 'just now')
      : minutes < 60
      ? (isId ? '$minutes menit lalu' : '$minutes min ago')
      : (isId ? '${minutes ~/ 60} jam lalu' : '${minutes ~/ 60} h ago');

  final proceed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isId ? 'Sudah dicatat?' : 'Already recorded?'),
      content: Text(
        isId
            ? 'Mirip dengan catatan $who: $category ${CurrencyFormatter.format(amount)}, $ago. Kalau ini pembelian yang sama, tidak perlu dicatat lagi.'
            : 'This looks like an entry by $who: $category ${CurrencyFormatter.format(amount)}, $ago. If it is the same purchase, there is no need to add it again.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(isId ? 'Batal' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(isId ? 'Tetap simpan' : 'Save anyway'),
        ),
      ],
    ),
  );
  return proceed ?? false;
}
