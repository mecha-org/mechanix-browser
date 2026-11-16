import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_browser/core/utils/app_logger.dart';
import 'package:mechanix_browser/features/browser/bloc/permission/site_permission_kind.dart';
import 'package:mechanix_browser/features/browser/data/models/site_permission.dart';
import 'package:mechanix_browser/features/browser/data/repositories/site_permission_repository.dart';
import 'package:webview_cef/webview_cef.dart';

part 'permission_event.dart';
part 'permission_state.dart';

/// Sends the answer for a request back to CEF.
typedef PermissionResponder =
    Future<void> Function(
      WebviewPermissionRequest request,
      bool allow, {
      PermissionPromptResult? promptResult,
    });

/// Handles camera, microphone, location, clipboard and MIDI requests from
/// pages: answers from remembered per-site decisions when it can, and
/// otherwise queues a prompt for the requesting tab.
///
/// Private tabs inherit remembered *blocks* but never remembered allows, and
/// their own decisions live in memory until the last private tab closes.
class PermissionBloc extends Bloc<PermissionEvent, PermissionState> {
  final SitePermissionRepository repository;
  final PermissionResponder _respond;

  /// Private-session decisions: origin -> kind -> allowed.
  final Map<String, Map<SitePermissionKind, bool>> _privateDecisions = {};

  PermissionBloc({required this.repository, PermissionResponder? respond})
    : _respond = respond ?? WebviewManager().respondToPermissionRequest,
      super(const PermissionState()) {
    on<PermissionRequested>(_onRequested);
    on<PermissionDismissed>(_onDismissed);
    on<PermissionDecided>(_onDecided);
    on<PermissionPromptClosed>(_onPromptClosed);
    on<PermissionTabNavigated>(_onTabNavigated);
    on<PermissionControllerDisposed>(_onControllerDisposed);
    on<PermissionPrivateSessionEnded>(_onPrivateSessionEnded);
    on<SitePermissionsLoadRequested>(_onLoadSitePermissions);
    on<SitePermissionChanged>(_onSitePermissionChanged);
    on<SitePermissionReset>(_onSitePermissionReset);
  }

  Map<SitePermissionKind, bool> _rememberedFor(String origin, bool isPrivate) {
    final persisted = repository.decisionsFor(origin);
    if (!isPrivate) return persisted;
    return {
      for (final e in persisted.entries)
        if (!e.value) e.key: false,
      ...?_privateDecisions[origin],
    };
  }

  Future<void> _answer(
    WebviewPermissionRequest request,
    bool allow, {
    PermissionPromptResult? promptResult,
  }) async {
    try {
      await _respond(request, allow, promptResult: promptResult);
    } catch (e, stackTrace) {
      AppLogger.e(
        'Unable to answer permission request $request',
        error: e,
        stack: stackTrace,
      );
    }
  }

  Future<void> _onRequested(
    PermissionRequested event,
    Emitter<PermissionState> emit,
  ) async {
    final request = event.request;
    final origin = normalizeOrigin(request.origin);
    final classified = classifyPermissionRequest(request);

    if (classified.hasUnsupported || classified.kinds.isEmpty) {
      AppLogger.i(
        '[Permission] Denying unsupported request from $origin: $request',
      );
      await _answer(request, false);
      return;
    }

    final decision = resolveFromRemembered(
      classified.kinds,
      _rememberedFor(origin, event.isPrivate),
    );
    if (decision != null) {
      AppLogger.i(
        '[Permission] ${decision ? 'Allowing' : 'Blocking'} $origin ${classified.kinds.map((k) => k.name)} (remembered)',
      );
      await _answer(request, decision);
      return;
    }

    emit(
      state.copyWith(
        pending: [
          ...state.pending,
          PendingPermission(
            tabId: event.tabId,
            controller: event.controller,
            request: request,
            origin: origin,
            kinds: classified.kinds,
            isPrivate: event.isPrivate,
          ),
        ],
      ),
    );
  }

  void _onDismissed(PermissionDismissed event, Emitter<PermissionState> emit) {
    _removeWhere(
      emit,
      (p) =>
          p.controller == event.controller &&
          p.request.requestId == event.requestId &&
          p.request.isMedia == event.isMedia,
    );
  }

  Future<void> _onDecided(
    PermissionDecided event,
    Emitter<PermissionState> emit,
  ) async {
    final pending = event.pending;
    if (!state.pending.contains(pending)) return;

    if (pending.isPrivate) {
      final forOrigin = _privateDecisions.putIfAbsent(pending.origin, () => {});
      for (final kind in pending.kinds) {
        forOrigin[kind] = event.allow;
      }
    } else {
      repository.save(pending.origin, pending.kinds, event.allow);
    }

    _removeWhere(emit, (p) => p == pending);
    await _answer(pending.request, event.allow);

    // Other requests that the new decision now settles (duplicates, other
    // tabs on the same site) are answered without prompting again.
    final settled = <PendingPermission, bool>{};
    for (final other in state.pending) {
      if (other.origin != pending.origin) continue;
      final decision = resolveFromRemembered(
        other.kinds,
        _rememberedFor(other.origin, other.isPrivate),
      );
      if (decision != null) settled[other] = decision;
    }
    if (settled.isNotEmpty) {
      _removeWhere(emit, settled.containsKey);
      for (final entry in settled.entries) {
        await _answer(entry.key.request, entry.value);
      }
    }

    if (!pending.isPrivate) add(const SitePermissionsLoadRequested());
  }

  Future<void> _onPromptClosed(
    PermissionPromptClosed event,
    Emitter<PermissionState> emit,
  ) async {
    if (!state.pending.contains(event.pending)) return;
    _removeWhere(emit, (p) => p == event.pending);
    await _answer(
      event.pending.request,
      false,
      promptResult: PermissionPromptResult.dismiss,
    );
  }

  Future<void> _onTabNavigated(
    PermissionTabNavigated event,
    Emitter<PermissionState> emit,
  ) async {
    final newOrigin = normalizeOrigin(event.url);
    final stale = state.pending
        .where((p) => p.tabId == event.tabId && p.origin != newOrigin)
        .toList();
    if (stale.isEmpty) return;
    _removeWhere(emit, stale.contains);
    // Usually already cancelled by Chromium; answering a gone request is a
    // no-op on the native side.
    for (final p in stale) {
      await _answer(
        p.request,
        false,
        promptResult: PermissionPromptResult.ignore,
      );
    }
  }

  void _onControllerDisposed(
    PermissionControllerDisposed event,
    Emitter<PermissionState> emit,
  ) {
    // Closing the browser cancels its requests natively.
    _removeWhere(emit, (p) => p.controller == event.controller);
  }

  Future<void> _onPrivateSessionEnded(
    PermissionPrivateSessionEnded event,
    Emitter<PermissionState> emit,
  ) async {
    _privateDecisions.clear();
    _removeWhere(emit, (p) => p.isPrivate);
  }

  void _onLoadSitePermissions(
    SitePermissionsLoadRequested event,
    Emitter<PermissionState> emit,
  ) {
    emit(state.copyWith(sitePermissions: repository.all()));
  }

  void _onSitePermissionChanged(
    SitePermissionChanged event,
    Emitter<PermissionState> emit,
  ) {
    repository.save(event.origin, [event.kind], event.allowed);
    emit(state.copyWith(sitePermissions: repository.all()));
  }

  void _onSitePermissionReset(
    SitePermissionReset event,
    Emitter<PermissionState> emit,
  ) {
    repository.remove(event.origin, event.kind);
    emit(state.copyWith(sitePermissions: repository.all()));
  }

  void _removeWhere(
    Emitter<PermissionState> emit,
    bool Function(PendingPermission) test,
  ) {
    final remaining = state.pending.where((p) => !test(p)).toList();
    if (remaining.length != state.pending.length) {
      emit(state.copyWith(pending: remaining));
    }
  }
}
