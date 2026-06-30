import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_ce/hive.dart';
import '../security/envelope.dart';

/// Shared helpers to reduce duplicated CRUD logic across record types.
/// Each method handles the common encrypt/decrypt/box operations.
class DatabaseHelpers {
  final Box<String> box;
  final Uint8List wrappingKey;
  final String deviceId;
  final String userId;
  final String recordType; // e.g., 'expense', 'income'
  final Box<Map>? syncQueueBox;

  DatabaseHelpers({
    required this.box,
    required this.wrappingKey,
    required this.deviceId,
    required this.userId,
    required this.recordType,
    this.syncQueueBox,
  });

  /// Encrypt payload, store in box, add to sync queue.
  Future<void> create(Map<String, dynamic> payload) async {
    final recordId = payload['id'] as String;
    final envelope = await EnvelopeEncryption.encrypt(
      recordId: recordId,
      deviceId: deviceId,
      payload: payload,
      wrappingKey: wrappingKey,
      metadata: {'type': recordType, 'userId': userId},
    );
    await box.put(recordId, jsonEncode(envelope.toJson()));
    await _addToSyncQueue(recordId, 'create');
  }

  /// Read and decrypt a record by ID.
  Future<Map<String, dynamic>?> read(String id) async {
    final envelopeJson = box.get(id);
    if (envelopeJson == null) return null;
    final envelope = EncryptionEnvelope.fromJson(
      jsonDecode(envelopeJson) as Map<String, dynamic>,
    );
    return await EnvelopeEncryption.decrypt(
      envelope: envelope,
      wrappingKey: wrappingKey,
    );
  }

  /// List all decrypted records.
  Future<List<Map<String, dynamic>>> list() async {
    final results = <Map<String, dynamic>>[];
    for (final envelopeJson in box.values) {
      try {
        final envelope = EncryptionEnvelope.fromJson(
          jsonDecode(envelopeJson) as Map<String, dynamic>,
        );
        if (envelope.syncStatus == 'conflict') continue;
        final data = await EnvelopeEncryption.decrypt(
          envelope: envelope,
          wrappingKey: wrappingKey,
        );
        results.add(data);
      } catch (_) {}
    }
    return results;
  }

  /// Update a record: read existing, merge, delete old, re-create.
  Future<void> update(String id, Map<String, dynamic> updates) async {
    final current = await read(id);
    if (current == null) throw Exception('$recordType not found');
    final merged = {...current, ...updates};
    await box.delete(id);
    await create(merged);
  }

  /// Delete a record from box (tombstone management is caller's responsibility).
  Future<void> delete(String id) async {
    await box.delete(id);
    await _addToSyncQueue(id, 'delete');
  }

  Future<void> _addToSyncQueue(String recordId, String operation) async {
    if (syncQueueBox == null) return;
    final queueId = '$recordType:$recordId:${DateTime.now().millisecondsSinceEpoch}';
    await syncQueueBox!.put(queueId, {
      'recordType': recordType,
      'recordId': recordId,
      'operation': operation,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
  }
}
