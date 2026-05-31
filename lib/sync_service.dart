import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class SyncService {
  // Your private repository sync configurations
  static const String _githubToken =
      "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";
  static const String _repoOwner = "YOUR_GITHUB_USERNAME";
  static const String _repoName = "YOUR_PRIVATE_REPO_NAME";
  static const String _filePath = "vault_data/encrypted_transactions.hive";

  /// Gets the local file path where Hive stores data on the device
  static Future<File> _getLocalDatabaseFile() async {
    if (kIsWeb) {
      throw UnsupportedError(
        "Direct file sync is handled via browser local storage indexedDB on Web.",
      );
    }
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/encrypted_transactions.hive');
  }

  /// Pushes the local encrypted binary file straight to your private backup repository
  static Future<bool> uploadToBackup() async {
    if (kIsWeb) return true; // Web uses automated browser backup layers

    try {
      final file = await _getLocalDatabaseFile();
      if (!await file.exists()) return false;

      final List<int> fileBytes = await file.readAsBytes();
      final String base64Content = base64Encode(fileBytes);

      final url = Uri.parse(
        'https://api.github.com/repos/$_repoOwner/$_repoName/contents/$_filePath',
      );

      // We first check if the file already exists on GitHub to get its version SHA
      final checkResponse = await http.get(
        url,
        headers: {'Authorization': 'token $_githubToken'},
      );
      String? sha;
      if (checkResponse.statusCode == 200) {
        sha = jsonDecode(checkResponse.body)['sha'];
      }

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'token $_githubToken',
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
      debugPrint("Sync Upload Failed: $e");
      return false;
    }
  }

  /// Pulls down the latest encrypted version from the repository before the app unlocks
  static Future<bool> downloadLatestBackup() async {
    if (kIsWeb) return true;

    try {
      final url = Uri.parse(
        'https://api.github.com/repos/$_repoOwner/$_repoName/contents/$_filePath',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'token $_githubToken'},
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
      debugPrint("Sync Download Failed: $e");
      return false;
    }
  }
}
