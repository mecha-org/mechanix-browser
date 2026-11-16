part of 'permission_bloc.dart';

sealed class PermissionEvent extends Equatable {
  const PermissionEvent();

  @override
  List<Object?> get props => [];
}

/// A page in [tabId] asked for a permission.
class PermissionRequested extends PermissionEvent {
  final String tabId;
  final WebViewController controller;
  final WebviewPermissionRequest request;
  final bool isPrivate;

  const PermissionRequested({
    required this.tabId,
    required this.controller,
    required this.request,
    required this.isPrivate,
  });

  @override
  List<Object?> get props => [tabId, controller, request, isPrivate];
}

/// CEF withdrew a request (navigation, browser closed).
class PermissionDismissed extends PermissionEvent {
  final WebViewController controller;
  final int requestId;
  final bool isMedia;

  const PermissionDismissed({
    required this.controller,
    required this.requestId,
    required this.isMedia,
  });

  @override
  List<Object?> get props => [controller, requestId, isMedia];
}

/// The user chose Allow or Block on the prompt. The choice is remembered for
/// the origin (in memory only for private tabs).
class PermissionDecided extends PermissionEvent {
  final PendingPermission pending;
  final bool allow;

  const PermissionDecided(this.pending, {required this.allow});

  @override
  List<Object?> get props => [pending, allow];
}

/// The user closed the prompt without choosing. The request is denied this
/// time and nothing is remembered.
class PermissionPromptClosed extends PermissionEvent {
  final PendingPermission pending;

  const PermissionPromptClosed(this.pending);

  @override
  List<Object?> get props => [pending];
}

/// [tabId] navigated to [url]; requests from another origin are dropped.
class PermissionTabNavigated extends PermissionEvent {
  final String tabId;
  final String url;

  const PermissionTabNavigated({required this.tabId, required this.url});

  @override
  List<Object?> get props => [tabId, url];
}

/// A tab's webview is being disposed.
class PermissionControllerDisposed extends PermissionEvent {
  final WebViewController controller;

  const PermissionControllerDisposed(this.controller);

  @override
  List<Object?> get props => [controller];
}

/// The last private tab closed: forget private-session decisions.
class PermissionPrivateSessionEnded extends PermissionEvent {
  const PermissionPrivateSessionEnded();
}

/// Reload remembered decisions for the Site permissions screen.
class SitePermissionsLoadRequested extends PermissionEvent {
  const SitePermissionsLoadRequested();
}

/// Change a remembered decision from the Site permissions screen.
class SitePermissionChanged extends PermissionEvent {
  final String origin;
  final SitePermissionKind kind;
  final bool allowed;

  const SitePermissionChanged({
    required this.origin,
    required this.kind,
    required this.allowed,
  });

  @override
  List<Object?> get props => [origin, kind, allowed];
}

/// Forget remembered decisions for [origin] ([kind] null = all kinds).
class SitePermissionReset extends PermissionEvent {
  final String origin;
  final SitePermissionKind? kind;

  const SitePermissionReset(this.origin, [this.kind]);

  @override
  List<Object?> get props => [origin, kind];
}
