import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/image_utils.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/family/presentation/providers/family_provider.dart';

class FamilyPage extends ConsumerStatefulWidget {
  const FamilyPage({super.key});

  @override
  ConsumerState<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends ConsumerState<FamilyPage> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isCreating = true;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? _getUserId() {
    return ref.read(firebaseAuthDataSourceProvider).currentUser?.uid;
  }

  bool get _isId => Localizations.localeOf(context).languageCode == 'id';

  /// Errors come back as raw exception text; only the invalid-code message is
  /// meant for users, everything else gets a friendly fallback.
  String _friendlyError(String error) {
    if (error.contains('Kode undangan tidak valid')) {
      return _isId
          ? 'Kode undangan tidak valid. Cek lagi kodenya.'
          : 'That invite code is not valid. Check it and try again.';
    }
    return AppStrings(Localizations.localeOf(context)).actionFailed;
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    final userId = _getUserId();
    if (userId == null) return;

    final notifier = ref.read(familyNotifierProvider.notifier);
    String? error;

    if (_isCreating) {
      if (_nameController.text.trim().isEmpty) return;
      error = await notifier.createFamily(_nameController.text.trim(), userId);
    } else {
      if (_codeController.text.trim().isEmpty) return;
      error = await notifier.joinFamily(_codeController.text.trim());
    }

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } else {
      // Stay put: the page rebuilds into the family view on its own, and
      // go() would wipe the back stack.
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  /// Owners can switch back to their own family directly. Anyone else needs a
  /// fresh invite code, since membership is only granted through a code.
  Future<void> _rejoinFamily(String familyId) async {
    final userId = _getUserId();
    final family = await ref
        .read(familyRepositoryProvider)
        .getFamily(familyId)
        .catchError((_) => null);
    if (!mounted) return;
    if (family == null || family.createdBy != userId) {
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isId
                ? 'Minta kode undangan ke pemilik keluarga, lalu masukkan di kolom kode.'
                : 'Ask the family owner for an invite code, then enter it in the code field.',
          ),
        ),
      );
      return;
    }
    final err = await ref
        .read(authNotifierProvider.notifier)
        .joinFamily(familyId, familyName: family.name, role: 'admin');
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(err))));
    } else {
      // Stay put: the page rebuilds into the family view on its own, and
      // go() would wipe the back stack.
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyNotifierProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final familyAsync = ref.watch(familyProvider);
    final membersAsync = ref.watch(familyMembersProvider);
    final hasFamily = user?.familyId != null && user!.familyId!.isNotEmpty;
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final s = AppStrings(Localizations.localeOf(context));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasFamily) ...[
            const SizedBox(height: 8),
            Icon(Icons.family_restroom, size: 56, color: AppTheme.savingsColor),
            const SizedBox(height: 12),
            familyAsync.when(
              data: (family) => Column(
                children: [
                  Text(
                    family?.name ?? s.family,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (family != null && family.createdBy == user.id) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: AppTheme.warningColor,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Admin',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.warningColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              loading: () => Center(child: Text(s.loading)),
              error: (_, __) => Text(s.family),
            ),
            const SizedBox(height: 24),
            // Members section
            Text(
              isId ? 'Anggota Keluarga' : 'Family Members',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            membersAsync.when(
              data: (members) => Column(
                children: members
                    .map(
                      (m) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              backgroundImage: getAvatarProvider(m.photoUrl),
                              child: m.photoUrl == null
                                  ? Text(
                                      m.name.isNotEmpty
                                          ? m.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        m.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      familyAsync.when(
                                        data: (family) =>
                                            family?.createdBy == m.id
                                            ? Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.warningColor
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Admin',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        AppTheme.warningColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                        loading: () => const SizedBox.shrink(),
                                        error: (_, __) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    m.email,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (familyAsync.valueOrNull?.createdBy == user.id &&
                                m.id != user.id)
                              PopupMenuButton<String>(
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'transfer',
                                    child: Text(
                                      isId ? 'Jadikan Admin' : 'Make Admin',
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'kick',
                                    child: Text(isId ? 'Keluarkan' : 'Remove'),
                                  ),
                                ],
                                onSelected: (action) async {
                                  if (action == 'transfer') {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(
                                          isId
                                              ? 'Pindahkan Admin'
                                              : 'Transfer Admin',
                                        ),
                                        content: Text(
                                          isId
                                              ? 'Jadikan ${m.name} sebagai admin keluarga?'
                                              : 'Make ${m.name} the family admin?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: Text(s.cancel),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: Text(
                                              isId
                                                  ? 'Ya, Pindahkan'
                                                  : 'Yes, Transfer',
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final family = familyAsync.valueOrNull;
                                      if (family != null) {
                                        final err = await ref
                                            .read(
                                              familyNotifierProvider.notifier,
                                            )
                                            .transferOwnership(family, m.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                err != null
                                                    ? _friendlyError(err)
                                                    : (isId
                                                          ? 'Admin berhasil dipindahkan ke ${m.name}'
                                                          : '${m.name} is now the admin'),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  } else if (action == 'kick') {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(
                                          isId
                                              ? 'Keluarkan Anggota'
                                              : 'Remove Member',
                                        ),
                                        content: Text(
                                          isId
                                              ? 'Keluarkan ${m.name} dari keluarga?'
                                              : 'Remove ${m.name} from the family?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: Text(s.cancel),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: Text(
                                              isId
                                                  ? 'Ya, Keluarkan'
                                                  : 'Yes, Remove',
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final err = await ref
                                          .read(authNotifierProvider.notifier)
                                          .kickMember(
                                            m.id,
                                            fromFamilyId:
                                                familyAsync.valueOrNull?.id,
                                          );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              err != null
                                                  ? _friendlyError(err)
                                                  : (isId
                                                        ? '${m.name} sudah dikeluarkan'
                                                        : '${m.name} has been removed'),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Text(
                isId
                    ? 'Daftar anggota belum bisa dimuat. Coba lagi nanti.'
                    : "Couldn't load family members. Try again later.",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (familyAsync.valueOrNull?.createdBy == user.id) ...[
              _ShareCodeTile(code: familyAsync.valueOrNull?.inviteCode ?? ''),
              const SizedBox(height: 24),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final family = familyAsync.valueOrNull;
                  final isOwner = family?.createdBy == user.id;
                  final others = (membersAsync.valueOrNull ?? [])
                      .where((m) => m.id != user.id)
                      .toList();
                  String? heir = others.isNotEmpty ? others.first.id : null;
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => StatefulBuilder(
                      builder: (ctx, setState) => AlertDialog(
                        title: Text(
                          isId ? 'Keluar dari keluarga?' : 'Leave the family?',
                        ),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Records belong to the family's shared history.
                              Text(
                                isId
                                    ? 'Catatan yang kamu tambahkan tetap ada di keluarga ini. Setelah keluar, kamu kembali memakai data pribadimu. Untuk masuk lagi, perlu kode undangan terbaru.'
                                    : 'Records you added stay with this family. After leaving you go back to your personal data. Rejoining needs the current invite code.',
                              ),
                              if (isOwner && others.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  isId
                                      ? 'Pilih pemilik baru keluarga:'
                                      : 'Choose the new family owner:',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                for (final m in others)
                                  RadioListTile<String>(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    value: m.id,
                                    groupValue: heir,
                                    onChanged: (v) => setState(() => heir = v),
                                    title: Text(m.name),
                                  ),
                              ],
                              if (isOwner && others.isEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  isId
                                      ? 'Kamu satu-satunya anggota. Keluarga dan catatannya tidak bisa dibuka lagi setelah kamu keluar.'
                                      : "You are the only member. Nobody will be able to open this family's records after you leave.",
                                  style: const TextStyle(
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(s.cancel),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.errorColor,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(isId ? 'Keluar' : 'Leave'),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (confirm != true) return;
                  final err = await ref
                      .read(authNotifierProvider.notifier)
                      .leaveFamily(newOwnerId: isOwner ? heir : null);
                  if (context.mounted && err != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_friendlyError(err))),
                    );
                  }
                },
                icon: const Icon(
                  Icons.exit_to_app_rounded,
                  color: AppTheme.errorColor,
                ),
                label: Text(
                  isId ? 'Keluar dari Keluarga' : 'Leave Family',
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.errorColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const Divider(height: 48),
          ],
          // Create / Join form
          if (!hasFamily) ...[
            const SizedBox(height: 16),
            Icon(
              _isCreating ? Icons.group_add : Icons.group,
              size: 64,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _isCreating
                  ? (isId ? 'Buat Keluarga Baru' : 'Create a New Family')
                  : (isId ? 'Gabung Keluarga' : 'Join a Family'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if (_isCreating)
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: isId ? 'Nama Keluarga' : 'Family Name',
                  prefixIcon: const Icon(Icons.family_restroom),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? s.requiredField : null,
              )
            else
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: isId ? 'Kode Undangan' : 'Invite Code',
                  prefixIcon: const Icon(Icons.vpn_key),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? s.requiredField : null,
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: familyState.isLoading ? null : _onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _isCreating
                    ? (isId ? 'Buat Keluarga' : 'Create Family')
                    : (isId ? 'Gabung' : 'Join'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: familyState.isLoading
                  ? null
                  : () => setState(() => _isCreating = !_isCreating),
              child: Text(
                _isCreating
                    ? (isId
                          ? 'Punya kode undangan? Gabung'
                          : 'Have an invite code? Join')
                    : (isId ? 'Buat keluarga baru' : 'Create a new family'),
              ),
            ),
            if (familyState.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              isId
                  ? 'Ingin bergabung dengan keluarga lain?'
                  : 'Want to join another family?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _isCreating = !_isCreating),
              child: Text(
                _isCreating
                    ? (isId ? 'Gabung keluarga lain' : 'Join another family')
                    : (isId ? 'Buat keluarga baru' : 'Create a new family'),
              ),
            ),
          ],
          // History
          if (user != null && user.familyHistory.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text(
              isId ? 'Riwayat Keluarga' : 'Family History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            ...user.familyHistory.reversed.map(
              (h) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.savingsColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.family_restroom,
                        color: AppTheme.savingsColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h['name'] ?? s.family,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            h['id'] ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (h['id'] != user.familyId)
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () => _rejoinFamily(h['id']!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            isId ? 'Gabung' : 'Join',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.incomeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isId ? 'Aktif' : 'Active',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.incomeColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShareCodeTile extends StatelessWidget {
  final String code;
  const _ShareCodeTile({required this.code});

  @override
  Widget build(BuildContext context) {
    final isId = Localizations.localeOf(context).languageCode == 'id';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.savingsColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.savingsColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.share, color: AppTheme.savingsColor, size: 24),
          const SizedBox(height: 8),
          Text(
            isId ? 'Kode Undangan' : 'Invite Code',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            code,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              color: AppTheme.savingsColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isId
                ? 'Bagikan kode ini agar anggota lain bisa bergabung'
                : 'Share this code so others can join',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
