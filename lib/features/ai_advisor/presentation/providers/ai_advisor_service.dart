import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

enum AiChatRole { user, assistant }

class AiChatMessage {
  final AiChatRole role;
  final String text;

  const AiChatMessage({required this.role, required this.text});
}

class AiAdvisorService {
  static const _baseUrl = String.fromEnvironment(
    'AI_API_BASE_URL',
    defaultValue: 'https://finance-family-prod.vercel.app',
  );

  Future<String> ask({
    required String message,
    required List<AiChatMessage> history,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      return 'Kamu perlu login dulu supaya AI bisa membaca ringkasan finance kamu dengan aman.';
    }

    final uri = Uri.parse('$_baseUrl/api/ai/chat');
    try {
      final response = await http
          .post(
            uri,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
            },
            body: jsonEncode({
              'message': message,
              'history': history
                  .where((item) => item.text.trim().isNotEmpty)
                  .map(
                    (item) => {
                      'role': item.role.name,
                      'content': item.text,
                    },
                  )
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 35));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded['error'] as String?;
        return error?.isNotEmpty == true
            ? 'AI belum bisa merespons: $error'
            : 'AI belum bisa merespons (${response.statusCode}). Coba lagi nanti.';
      }

      final reply = decoded['reply'] as String?;
      return reply?.trim().isNotEmpty == true
          ? reply!.trim()
          : 'AI belum memberi jawaban. Coba tanya ulang dengan detail sedikit.';
    } catch (e) {
      return 'Koneksi ke AI gagal. Cek internet lalu coba lagi. ($e)';
    }
  }
}

