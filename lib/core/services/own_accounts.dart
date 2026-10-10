import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/family/presentation/providers/family_provider.dart';

/// Names that mark a transfer as money moving between your own accounts (or
/// within the family), which is neither income nor spending: the names on
/// the user's bank accounts (set in Settings), their profile name and, in
/// family mode, the members' names.
final ownAccountNamesProvider = FutureProvider<List<String>>((ref) async {
  final user = ref.watch(authNotifierProvider).valueOrNull;
  final members = ref.watch(familyMembersProvider).valueOrNull ?? const [];
  final saved = user == null ? const <String>[] : await OwnAccounts.load(user.id);
  return {
    ...saved,
    if (user != null && user.name.trim().isNotEmpty) user.name.trim(),
    for (final m in members)
      if (m.name.trim().isNotEmpty) m.name.trim(),
  }.toList();
});

class OwnAccounts {
  static String _key(String uid) => 'own_account_names_$uid';

  static Future<List<String>> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key(uid)) ?? const [];
  }

  static Future<void> save(String uid, List<String> names) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key(uid),
      names.map((n) => n.trim()).where((n) => n.isNotEmpty).toList(),
    );
  }

  static String _norm(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Whether [text] mentions one of [names]. Banks often cut names short
  /// ("TRIAS ZAEN MUTAQ"), so the first two words, or the first 12 letters
  /// of a long name, are enough. One-word names must match whole.
  static bool mentions(String text, List<String> names) {
    final t = ' ${_norm(text)} ';
    for (final raw in names) {
      final n = _norm(raw);
      if (n.length < 3) continue;
      final words = n.split(' ');
      if (t.contains(' $n ')) return true;
      if (words.length >= 2 && t.contains(' ${words[0]} ${words[1]}')) return true;
      if (n.length >= 14 && t.contains(' ${n.substring(0, 12)}')) return true;
    }
    return false;
  }

  /// A transfer to/from one of [names]: money moving between own accounts.
  static bool isOwnTransfer(String text, List<String> names) {
    final lower = text.toLowerCase();
    final isTransfer = RegExp(
      r'(transfer|trf|tf |bi ?fast|bifast|kirim|pindah|top ?up|setor|ovo|gopay|dana|shopeepay|va )',
    ).hasMatch(lower);
    return isTransfer && mentions(text, names);
  }
}
