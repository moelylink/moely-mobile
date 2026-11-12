import 'dart:io' as io;
import 'package:file/file.dart' as file;
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Custom FileSystem implementation that stores cached files in the application's
/// persistent support directory (`getApplicationSupportDirectory`), rather than
/// the system temporary directory (`getTemporaryDirectory`).
///
/// On Android, this points to `context.filesDir` instead of `context.cacheDir`,
/// meaning Android system settings categorizes this storage as "App Data / User data"
/// rather than "Cache", and the OS will never automatically wipe it under low memory pressure.
class PersistentFileSystem implements FileSystem {
  final Future<file.Directory> _fileDir;
  final String _cacheKey;

  PersistentFileSystem(this._cacheKey) : _fileDir = createDirectory(_cacheKey);

  static Future<file.Directory> createDirectory(String key) async {
    final baseDir = await getApplicationSupportDirectory();
    final path = p.join(baseDir.path, key);

    const fs = LocalFileSystem();
    final directory = fs.directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  @override
  Future<file.File> createFile(String name) async {
    final directory = await _fileDir;
    if (!(await directory.exists())) {
      await createDirectory(_cacheKey);
    }
    return directory.childFile(name);
  }
}

/// Global Application Image Cache Manager.
///
/// Ensures all network images and metadata are stored in persistent storage
/// (Application Support Directory), preventing Android from treating them as ephemeral
/// system cache. Users can manage or clear image caches directly inside the App settings.
class AppImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'libCachedImageData';

  static final AppImageCacheManager _instance = AppImageCacheManager._();
  factory AppImageCacheManager() => _instance;

  AppImageCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 90),
            maxNrOfCacheObjects: 2000,
            fileSystem: PersistentFileSystem(key),
            fileService: HttpFileService(),
          ),
        );

  static bool _migrated = false;

  /// Migrates legacy image files from temporary directory (`getTemporaryDirectory`)
  /// to persistent application support directory (`getApplicationSupportDirectory`).
  ///
  /// This ensures existing downloaded images are preserved without re-downloading,
  /// while immediately shrinking the cache size reported by the Android OS system settings.
  static Future<void> migrateLegacyCache() async {
    if (_migrated) return;
    _migrated = true;

    try {
      final tempDir = await getTemporaryDirectory();
      final supportDir = await getApplicationSupportDirectory();

      final oldDir = io.Directory('${tempDir.path}/$key');
      final newDir = io.Directory('${supportDir.path}/$key');

      if (!oldDir.existsSync()) return;
      if (!newDir.existsSync()) {
        newDir.createSync(recursive: true);
      }

      final entities = oldDir.listSync(recursive: false);
      for (final entity in entities) {
        if (entity is io.File) {
          try {
            final targetPath = p.join(newDir.path, p.basename(entity.path));
            final targetFile = io.File(targetPath);
            if (!targetFile.existsSync()) {
              entity.renameSync(targetPath);
            } else {
              entity.deleteSync();
            }
          } catch (_) {}
        }
      }

      // Also clean up any lingering files in legacy temporary cache manager dirs
      try {
        if (oldDir.listSync().isEmpty) {
          oldDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('AppImageCacheManager migration error: $e');
    }
  }
}
