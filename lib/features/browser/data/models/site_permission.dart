import 'package:objectbox/objectbox.dart';

/// A remembered allow/block decision for one permission kind on one origin.
@Entity()
class SitePermission {
  @Id()
  int id;

  /// Normalized origin, e.g. `https://meet.example.com`.
  @Index()
  String origin;

  /// [SitePermissionKind.name].
  String kind;

  bool allowed;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  SitePermission({
    this.id = 0,
    required this.origin,
    required this.kind,
    required this.allowed,
    required this.updatedAt,
  });
}
