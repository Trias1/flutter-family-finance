import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:family_finance_manager/core/constants/app_constants.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/expense/presentation/providers/expense_provider.dart';

class ReceiptScannerPage extends ConsumerStatefulWidget {
  const ReceiptScannerPage({super.key});

  @override
  ConsumerState<ReceiptScannerPage> createState() => _ReceiptScannerPageState();
}

class _ReceiptScannerPageState extends ConsumerState<ReceiptScannerPage> {
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  XFile? _image;
  String _category = AppConstants.expenseCategories.first;
  bool _extracting = false;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 190,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: _image == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.document_scanner_rounded, size: 42),
                        SizedBox(height: 8),
                        Text('Pilih / foto struk belanja'),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(File(_image!.path), fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (_extracting) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(child: Text('AI sedang membaca struk...')),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Total Belanja',
              prefixText: 'Rp ',
              prefixIcon: Icon(Icons.payments_rounded),
            ),
            validator: (value) => value == null || value.isEmpty
                ? 'Total belanja wajib diisi'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              prefixIcon: Icon(Icons.category_rounded),
            ),
            items: AppConstants.expenseCategories
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _merchantController,
            decoration: const InputDecoration(
              labelText: 'Toko / Merchant',
              prefixIcon: Icon(Icons.store_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Catatan tambahan',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Setelah foto struk, AI akan coba isi total, toko, kategori, dan catatan otomatis. Tetap cek ulang sebelum simpan.',
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _saveExpense,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan Pengeluaran'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.camera);
    if (image == null || !mounted) return;
    setState(() {
      _image = image;
      _extracting = true;
    });
    final result = await _GroqReceiptReader().extract(image);
    if (!mounted) return;
    setState(() {
      if (result.amount != null) _amountController.text = result.amount!;
      if (result.merchant != null) _merchantController.text = result.merchant!;
      if (result.category != null &&
          AppConstants.expenseCategories.contains(result.category)) {
        _category = result.category!;
      }
      if (result.note != null) _noteController.text = result.note!;
      _extracting = false;
    });
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final familyId = ref.read(financeScopeIdProvider);
    final uid = ref.read(currentUserProvider).valueOrNull?.id ?? '';
    final merchant = _merchantController.text.trim();
    final extraNote = _noteController.text.trim();
    final note = [
      if (merchant.isNotEmpty) merchant,
      if (extraNote.isNotEmpty) extraNote,
      if (_image != null) 'Foto struk: ${_image!.name}',
    ].join(' | ');

    final model = ExpenseModel(
      id: '',
      familyId: familyId,
      userId: uid,
      amount: double.parse(_amountController.text),
      category: _category,
      note: note.isEmpty ? null : note,
      date: DateTime.now(),
    );

    await ref.read(expenseNotifierProvider.notifier).addExpense(model);
    if (!mounted) return;
    setState(() => _saving = false);
    context.pop();
  }
}

class _GroqReceiptReader {
  static const _apiKey = String.fromEnvironment('GROQ_API_KEY');

  Future<_ReceiptExtract> extract(XFile image) async {
    if (_apiKey.isEmpty) return const _ReceiptExtract();

    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_apiKey');
      request.write(
        jsonEncode({
          'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
          'temperature': 0,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text':
                      'Baca struk ini. Balas JSON valid saja tanpa markdown: {"amount":"angka total tanpa titik/koma/rp", "merchant":"nama toko", "category":"salah satu: ${AppConstants.expenseCategories.join(', ')}", "note":"ringkasan singkat barang/tanggal jika ada"}. Jika tidak yakin, pakai null.',
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
                },
              ],
            },
          ],
        }),
      );

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const _ReceiptExtract();
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      final message = choices?.firstOrNull?['message'] as Map<String, dynamic>?;
      final content = (message?['content'] as String?)?.trim();
      if (content == null || content.isEmpty) return const _ReceiptExtract();

      final cleaned = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final data = jsonDecode(cleaned) as Map<String, dynamic>;
      return _ReceiptExtract(
        amount: data['amount']?.toString(),
        merchant: data['merchant']?.toString(),
        category: data['category']?.toString(),
        note: data['note']?.toString(),
      );
    } catch (_) {
      return const _ReceiptExtract();
    }
  }
}

class _ReceiptExtract {
  final String? amount;
  final String? merchant;
  final String? category;
  final String? note;

  const _ReceiptExtract({this.amount, this.merchant, this.category, this.note});
}
