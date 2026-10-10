import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:family_finance_manager/core/constants/app_constants.dart';

class ReceiptExtractResult {
  final String? amount;
  final String? merchant;
  final String? category;
  final String? note;

  const ReceiptExtractResult({this.amount, this.merchant, this.category, this.note});

  bool get isEmpty => amount == null && merchant == null && category == null && note == null;
}

class ReceiptScannerService {
  static const _apiKey = String.fromEnvironment('GROQ_API_KEY');

  Future<ReceiptExtractResult> extractReceipt(XFile image) async {
    if (_apiKey.isEmpty || image.path.isEmpty) {
      return const ReceiptExtractResult();
    }

    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_apiKey');
      request.write(jsonEncode({
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
      }));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const ReceiptExtractResult();
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      final message = choices?.firstOrNull?['message'] as Map<String, dynamic>?;
      final content = (message?['content'] as String?)?.trim();
      if (content == null || content.isEmpty) return const ReceiptExtractResult();

      final cleaned = content.replaceAll('```json', '').replaceAll('```', '').trim();
      final data = jsonDecode(cleaned) as Map<String, dynamic>;
      return ReceiptExtractResult(
        amount: data['amount']?.toString(),
        merchant: data['merchant']?.toString(),
        category: data['category']?.toString(),
        note: data['note']?.toString(),
      );
    } catch (_) {
      return const ReceiptExtractResult();
    }
  }

  Future<XFile?> pickImage() async {
    return ImagePicker().pickImage(source: ImageSource.camera);
  }
}

final receiptScannerServiceProvider = Provider<ReceiptScannerService>((ref) {
  return ReceiptScannerService();
});

final receiptImageProvider = StateProvider<XFile?>((ref) => null);

final receiptExtractingProvider = StateProvider<bool>((ref) => false);

final receiptExtractResultProvider = StateProvider<ReceiptExtractResult?>((ref) => null);
