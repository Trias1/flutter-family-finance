import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/image_utils.dart';
import 'package:family_finance_manager/core/utils/validators.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      context.go('/family');
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
        const SnackBar(
          content: Text(
            'Minta kode undangan ke pemilik keluarga, lalu masukkan di kolom kode.',
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      context.go('/family');
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyNotifierProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final familyAsync = ref.watch(familyProvider);
    final membersAsync = ref.watch(familyMembersProvider);
    final hasFamily = user?.familyId != null && user!.familyId!.isNotEmpty;

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
                    family?.name ?? 'Keluarga',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (family != null && family.createdBy == user?.id) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.warningColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 14, color: AppTheme.warningColor),
                          SizedBox(width: 4),
                          Text('Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.warningColor)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              loading: () => const Center(child: Text('Memuat...')),
              error: (_, __) => const Text('Keluarga'),
            ),
            const SizedBox(height: 24),
            // Members section
            Text('Anggota Keluarga', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 12),
            membersAsync.when(
              data: (members) => Column(
                children: members.map((m) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                        backgroundImage: getAvatarProvider(m.photoUrl),
                        child: m.photoUrl == null
                            ? Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                                style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(width: 6),
                                familyAsync.when(
                                  data: (family) => family?.createdBy == m.id
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: AppTheme.warningColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                          child: const Text('Admin', style: TextStyle(fontSize: 10, color: AppTheme.warningColor, fontWeight: FontWeight.bold)),
                                        )
                                      : const SizedBox.shrink(),
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, __) => const SizedBox.shrink(),
                                ),
                              ],
                            ),
                            Text(m.email, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      if (familyAsync.valueOrNull?.createdBy == user?.id && m.id != user?.id)
                        PopupMenuButton<String>(
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'transfer', child: Text('Jadikan Admin')),
                            const PopupMenuItem(value: 'kick', child: Text('Keluarkan')),
                          ],
                          onSelected: (action) async {
                            if (action == 'transfer') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Transfer Admin'),
                                  content: Text('Jadikan ${m.name} sebagai admin keluarga?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Transfer')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final family = familyAsync.valueOrNull;
                                if (family != null) {
                                  final err = await ref.read(familyNotifierProvider.notifier).transferOwnership(family, m.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'Admin berhasil ditransfer ke ${m.name}')));
                                  }
                                }
                              }
                            } else if (action == 'kick') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Keluarkan Anggota'),
                                  content: Text('Keluarkan ${m.name} dari keluarga?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Keluarkan')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final err = await ref.read(authNotifierProvider.notifier).kickMember(m.id, fromFamilyId: familyAsync.valueOrNull?.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? '${m.name} berhasil dikeluarkan')));
                                }
                              }
                            }
                          },
                        ),
                    ],
                  ),
                )).toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Text('Gagal memuat anggota', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 24),
            if (familyAsync.valueOrNull?.createdBy == user?.id) ...[
              _ShareCodeTile(code: familyAsync.valueOrNull?.inviteCode ?? ''),
              const SizedBox(height: 24),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final family = familyAsync.valueOrNull;
                  final isOwner = family?.createdBy == user?.id;
                  final msg = isOwner
                      ? 'Kamu adalah admin. Admin akan otomatis pindah ke anggota lain saat kamu keluar. Lanjutkan?'
                      : 'Yakin ingin keluar dari keluarga?';
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Keluar dari Keluarga'),
                      content: Text(msg),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Keluar')),
                      ],
                    ),
                  );
                  if (confirm != true) return;
                  final err = await ref.read(authNotifierProvider.notifier).leaveFamily();
                  if (context.mounted && err != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                  }
                },
                icon: const Icon(Icons.exit_to_app_rounded, color: AppTheme.errorColor),
                label: const Text('Keluar dari Keluarga', style: TextStyle(color: AppTheme.errorColor)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.errorColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const Divider(height: 48),
          ],
          // Create / Join form
          if (!hasFamily) ...[
            const SizedBox(height: 16),
            Icon(_isCreating ? Icons.group_add : Icons.group, size: 64, color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            Text(
              _isCreating ? 'Buat Keluarga Baru' : 'Gabung Keluarga',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if (_isCreating)
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Keluarga', prefixIcon: Icon(Icons.family_restroom)),
                validator: (v) => Validators.required(v, 'Nama Keluarga'),
              )
            else
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Kode Undangan', prefixIcon: Icon(Icons.vpn_key)),
                validator: (v) => Validators.required(v, 'Kode Undangan'),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: familyState.isLoading ? null : _onSubmit,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              child: Text(_isCreating ? 'Buat Keluarga' : 'Gabung'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: familyState.isLoading ? null : () => setState(() => _isCreating = !_isCreating),
              child: Text(_isCreating ? 'Punya kode undangan? Gabung' : 'Buat keluarga baru'),
            ),
            if (familyState.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              'Ingin bergabung dengan keluarga lain?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _isCreating = !_isCreating),
              child: Text(_isCreating ? 'Gabung keluarga lain' : 'Buat keluarga baru'),
            ),
          ],
          // History
          if (user != null && user.familyHistory.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text('Riwayat Keluarga', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 12),
            ...user.familyHistory.reversed.map((h) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.savingsColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.family_restroom, color: AppTheme.savingsColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h['name'] ?? 'Keluarga', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(h['id'] ?? '', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (h['id'] != user?.familyId)
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () => _rejoinFamily(h['id']!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Gabung', style: TextStyle(fontSize: 12)),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppTheme.incomeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('Aktif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.incomeColor)),
                    ),
                ],
              ),
            )),
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
          Text('Kode Undangan', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(code, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 4, color: AppTheme.savingsColor)),
          const SizedBox(height: 8),
          Text('Bagikan kode ini agar anggota lain bisa bergabung', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
