import 'package:mechanix_browser/features/browser/bloc/permission/site_permission_kind.dart';
import 'package:mechanix_browser/features/browser/data/models/site_permission.dart';

/// Persistent per-site permission decisions.
abstract class SitePermissionRepository {
  /// Remembered decisions for [origin], keyed by kind.
  Map<SitePermissionKind, bool> decisionsFor(String origin);

  /// Remembers [allowed] for every kind in [kinds] on [origin].
  void save(String origin, Iterable<SitePermissionKind> kinds, bool allowed);

  /// Forgets one kind, or every kind when [kind] is null.
  void remove(String origin, [SitePermissionKind? kind]);

  /// All remembered decisions, newest first.
  List<SitePermission> all();
}
