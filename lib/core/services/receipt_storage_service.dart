import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Uploads and removes transaction receipt attachments (photos/PDFs) in
/// Firebase Storage. Files are stored under `receipts/{uid}/…` and referenced
/// from the transaction document by their tokenized download URL.
class ReceiptStorageService {
  static final _storage = FirebaseStorage.instance;

  /// Uploads [bytes] and returns the download URL. [uid] must be the signed-in
  /// user's uid so the storage security rules accept the write.
  static Future<String> upload({
    required String uid,
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    final safeName = filename.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path = 'receipts/$uid/${const Uuid().v4()}_$safeName';
    final ref = _storage.ref(path);
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return task.ref.getDownloadURL();
  }

  /// Best-effort deletion of a previously uploaded attachment by its URL.
  /// Failures are swallowed (the file may already be gone).
  static Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      debugPrint('[Receipt] delete error: $e');
    }
  }

  /// True when [url] points at an image (by file extension in the path).
  static bool isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('.heic') ||
        lower.contains('.gif');
  }
}
