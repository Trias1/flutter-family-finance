import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:family_finance_manager/core/services/backup_service.dart';

class DriveBackupService {
  static const _driveScope = 'https://www.googleapis.com/auth/drive.file';
  static const _appFolder = 'FamilyFinanceBackup';

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: [_driveScope]);

  Future<String?> _getToken() async {
    final account = await _googleSignIn.signInSilently();
    if (account == null) return null;
    final auth = await account.authHeaders;
    return auth['Authorization']?.replaceFirst('Bearer ', '');
  }

  Future<String?> _createOrGetAppFolder(String token) async {
    final query = Uri.encodeComponent(
      "name='$_appFolder' and mimeType='application/vnd.google-apps.folder' and trashed=false",
    );
    final res = await http.get(
      Uri.parse('https://www.googleapis.com/drive/v3/files?q=$query'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final files = jsonDecode(res.body)['files'] as List;
      if (files.isNotEmpty) return files.first['id'] as String;
    }
    final createRes = await http.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': _appFolder,
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    );
    if (createRes.statusCode == 200) {
      return jsonDecode(createRes.body)['id'] as String;
    }
    return null;
  }

  Future<bool> uploadBackup(BackupData backup) async {
    final token = await _getToken();
    if (token == null) return false;

    final folderId = await _createOrGetAppFolder(token);
    if (folderId == null) return false;

    final jsonStr = backup.toJson();
    final boundary = 'boundary${DateTime.now().millisecondsSinceEpoch}';
    final body = StringBuffer();
    body.writeln('--$boundary');
    body.writeln('Content-Type: application/json; charset=UTF-8');
    body.writeln();
    body.writeln(
      jsonEncode({
        'name': 'backup_${backup.createdAt.millisecondsSinceEpoch}.json',
        'parents': [folderId],
      }),
    );
    body.writeln('--$boundary');
    body.writeln('Content-Type: application/json');
    body.writeln();
    body.write(jsonStr);
    body.writeln();
    body.writeln('--$boundary--');

    final res = await http.post(
      Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body.toString(),
    );
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> listBackups() async {
    final token = await _getToken();
    if (token == null) return [];

    final folderId = await _createOrGetAppFolder(token);
    if (folderId == null) return [];

    final query = Uri.encodeComponent(
      "'$folderId' in parents and mimeType='application/json' and trashed=false",
    );
    final res = await http.get(
      Uri.parse(
        'https://www.googleapis.com/drive/v3/files?q=$query&orderBy=createdTime desc',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(
        jsonDecode(res.body)['files'] ?? [],
      );
    }
    return [];
  }

  Future<BackupData?> downloadBackup(String fileId) async {
    final token = await _getToken();
    if (token == null) return null;

    final res = await http.get(
      Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      return BackupData.fromJson(res.body);
    }
    return null;
  }
}
