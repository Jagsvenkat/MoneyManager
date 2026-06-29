import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'core/security/secure_storage.dart';

class SyncService {
  static const String _repoOwner = "YOUR_GITHUB_USERNAME";
  static const String _repoName = "YOUR_PRIVATE_REPO_NAME";
  static const String _filePath = "vault_data/encrypted_transactions.hive";

  static Future<String?> _getToken() async {
    await SecureStorageService.initialize();
    return await SecureStorageService.loadGitHubPat('default');
  }

  static Future<File> _getLocalDatabaseFile() async {
    if (kIsWeb) {
      throw UnsupportedError(
        "Direct file sync is handled via browser local storage indexedDB on Web.",
      );
    }
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/encrypted_transactions.hive');
  }

  static Future<bool> uploadToBackup() async {
    if (kIsWeb) return true;

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return false;

      final file = await _getLocalDatabaseFile();
      if (!await file.exists()) return false;

      final List<int> fileBytes = await file.readAsBytes();
      final String base64Content = base64Encode(fileBytes);

      final url = Uri.parse(
        'https://api.github.com/repos/$_repoOwner/$_repoName/contents/$_filePath',
      );

      final checkResponse = await http.get(
        url,
        headers: {'Authorization': 'token $token'},
      );
      String? sha;
      if (checkResponse.statusCode == 200) {
        sha = jsonDecode(checkResponse.body)['sha'];
      }

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'token $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "message": "Automated Encrypted Vault Sync Update",
          "content": base64Content,
          if (sha != null) "sha": sha,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> downloadLatestBackup() async {
    if (kIsWeb) return true;

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return false;

      final url = Uri.parse(
        'https://api.github.com/repos/$_repoOwner/$_repoName/contents/$_filePath',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'token $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String base64Content = data['content'].replaceAll('\n', '');
        final List<int> decryptedFileBytes = base64Decode(base64Content);

        final file = await _getLocalDatabaseFile();
        await file.writeAsBytes(decryptedFileBytes);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
