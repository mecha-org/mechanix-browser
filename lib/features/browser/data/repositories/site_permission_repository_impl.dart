import 'package:mechanix_browser/core/services/objectbox_service.dart';
import 'package:mechanix_browser/core/utils/app_logger.dart';
import 'package:mechanix_browser/features/browser/bloc/permission/site_permission_kind.dart';
import 'package:mechanix_browser/features/browser/data/models/site_permission.dart';
import 'package:mechanix_browser/features/browser/data/repositories/site_permission_repository.dart';
import 'package:mechanix_browser/objectbox.g.dart';

class SitePermissionRepositoryImpl implements SitePermissionRepository {
  final Box<SitePermission> _box;

  SitePermissionRepositoryImpl({Store? store})
    : _box = (store ?? ObjectBoxService.store).box<SitePermission>();

  List<SitePermission> _forOrigin(String origin) {
    final query = _box.query(SitePermission_.origin.equals(origin)).build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  @override
  Map<SitePermissionKind, bool> decisionsFor(String origin) {
    try {
      final result = <SitePermissionKind, bool>{};
      for (final entry in _forOrigin(origin)) {
        final kind = SitePermissionKind.values
            .where((k) => k.name == entry.kind)
            .firstOrNull;
        if (kind != null) result[kind] = entry.allowed;
      }
      return result;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Unable to read site permissions',
        error: e,
        stack: stackTrace,
      );
      return const {};
    }
  }

  @override
  void save(String origin, Iterable<SitePermissionKind> kinds, bool allowed) {
    try {
      final existing = {for (final e in _forOrigin(origin)) e.kind: e};
      final now = DateTime.now();
      _box.putMany([
        for (final kind in kinds)
          (existing[kind.name] ??
                SitePermission(
                  origin: origin,
                  kind: kind.name,
                  allowed: allowed,
                  updatedAt: now,
                ))
            ..allowed = allowed
            ..updatedAt = now,
      ]);
    } catch (e, stackTrace) {
      AppLogger.e(
        'Unable to save site permission',
        error: e,
        stack: stackTrace,
      );
    }
  }

  @override
  void remove(String origin, [SitePermissionKind? kind]) {
    try {
      final ids = _forOrigin(origin)
          .where((e) => kind == null || e.kind == kind.name)
          .map((e) => e.id)
          .toList();
      _box.removeMany(ids);
    } catch (e, stackTrace) {
      AppLogger.e(
        'Unable to remove site permission',
        error: e,
        stack: stackTrace,
      );
    }
  }

  @override
  List<SitePermission> all() {
    try {
      final query = _box
          .query()
          .order(SitePermission_.updatedAt, flags: Order.descending)
          .build();
      try {
        return query.find();
      } finally {
        query.close();
      }
    } catch (e, stackTrace) {
      AppLogger.e(
        'Unable to list site permissions',
        error: e,
        stack: stackTrace,
      );
      return const [];
    }
  }
}
