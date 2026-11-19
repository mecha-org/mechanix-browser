import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_browser/features/browser/bloc/permission/permission_bloc.dart';
import 'package:mechanix_browser/features/browser/bloc/permission/site_permission_kind.dart';
import 'package:mechanix_browser/features/browser/data/models/site_permission.dart';
import 'package:mechanix_browser/features/browser/data/repositories/site_permission_repository.dart';
import 'package:webview_cef/webview_cef.dart';

class InMemorySitePermissionRepository implements SitePermissionRepository {
  final Map<String, Map<SitePermissionKind, bool>> data = {};

  @override
  Map<SitePermissionKind, bool> decisionsFor(String origin) =>
      Map.of(data[origin] ?? const {});

  @override
  void save(String origin, Iterable<SitePermissionKind> kinds, bool allowed) {
    final forOrigin = data.putIfAbsent(origin, () => {});
    for (final k in kinds) {
      forOrigin[k] = allowed;
    }
  }

  @override
  void remove(String origin, [SitePermissionKind? kind]) {
    if (kind == null) {
      data.remove(origin);
    } else {
      data[origin]?.remove(kind);
    }
  }

  @override
  List<SitePermission> all() => [
    for (final o in data.entries)
      for (final k in o.value.entries)
        SitePermission(
          origin: o.key,
          kind: k.key.name,
          allowed: k.value,
          updatedAt: DateTime(2026),
        ),
  ];
}

class Answer {
  final WebviewPermissionRequest request;
  final bool allow;
  final PermissionPromptResult? promptResult;
  Answer(this.request, this.allow, this.promptResult);
}

WebviewPermissionRequest media(
  int id,
  int mask, [
  String origin = 'https://meet.example.com/',
]) => WebviewPermissionRequest(
  requestId: id,
  isMedia: true,
  origin: origin,
  permissions: mask,
);

WebviewPermissionRequest prompt(
  int id,
  int mask, [
  String origin = 'https://maps.example.com/',
]) => WebviewPermissionRequest(
  requestId: id,
  isMedia: false,
  origin: origin,
  permissions: mask,
);

const camMic =
    MediaPermission.deviceVideoCapture | MediaPermission.deviceAudioCapture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemorySitePermissionRepository repo;
  late List<Answer> answers;
  late PermissionBloc bloc;
  late WebViewController tabA;
  late WebViewController tabB;

  setUp(() {
    repo = InMemorySitePermissionRepository();
    answers = [];
    bloc = PermissionBloc(
      repository: repo,
      respond: (request, allow, {promptResult}) async {
        answers.add(Answer(request, allow, promptResult));
      },
    );
    const channel = MethodChannel('test');
    tabA = WebViewController(channel, 1);
    tabB = WebViewController(channel, 2);
  });

  tearDown(() => bloc.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  void request(
    WebViewController c,
    String tabId,
    WebviewPermissionRequest r, {
    bool isPrivate = false,
  }) {
    bloc.add(
      PermissionRequested(
        tabId: tabId,
        controller: c,
        request: r,
        isPrivate: isPrivate,
      ),
    );
  }

  group('classifyPermissionRequest', () {
    test('maps media bits to camera and microphone', () {
      final c = classifyPermissionRequest(media(1, camMic));
      expect(c.kinds, [
        SitePermissionKind.camera,
        SitePermissionKind.microphone,
      ]);
      expect(c.hasUnsupported, isFalse);
    });

    test('screen capture and notifications are unsupported', () {
      expect(
        classifyPermissionRequest(
          media(1, MediaPermission.desktopVideoCapture),
        ).hasUnsupported,
        isTrue,
      );
      expect(
        classifyPermissionRequest(
          prompt(1, PromptPermission.notifications),
        ).hasUnsupported,
        isTrue,
      );
    });

    test('normalizeOrigin strips path and trailing slash', () {
      expect(normalizeOrigin('https://a.com/'), 'https://a.com');
      expect(normalizeOrigin('https://a.com:8443/x?y'), 'https://a.com:8443');
    });
  });

  test('unknown site is queued for a prompt, nothing answered yet', () async {
    request(tabA, 'a', media(1, camMic));
    await settle();
    expect(bloc.state.promptFor('a')?.kinds, [
      SitePermissionKind.camera,
      SitePermissionKind.microphone,
    ]);
    expect(bloc.state.promptFor('b'), isNull);
    expect(answers, isEmpty);
  });

  test('unsupported request is denied without prompting', () async {
    request(tabA, 'a', prompt(7, PromptPermission.notifications));
    await settle();
    expect(bloc.state.pending, isEmpty);
    expect(answers.single.allow, isFalse);
  });

  test('Allow answers, remembers, and settles duplicates', () async {
    request(tabA, 'a', media(1, camMic));
    request(tabB, 'b', media(2, MediaPermission.deviceVideoCapture));
    await settle();
    expect(bloc.state.pending, hasLength(2));

    bloc.add(PermissionDecided(bloc.state.promptFor('a')!, allow: true));
    await settle();

    expect(bloc.state.pending, isEmpty);
    expect(answers.map((a) => (a.request.requestId, a.allow)), [
      (1, true),
      (2, true),
    ]);
    expect(repo.decisionsFor('https://meet.example.com'), {
      SitePermissionKind.camera: true,
      SitePermissionKind.microphone: true,
    });

    // Next request is answered from memory.
    request(tabA, 'a', media(3, camMic));
    await settle();
    expect(bloc.state.pending, isEmpty);
    expect(answers.last.allow, isTrue);
  });

  test('a remembered block wins over an unknown kind', () async {
    repo.save('https://meet.example.com', [
      SitePermissionKind.microphone,
    ], false);
    request(tabA, 'a', media(1, camMic));
    await settle();
    expect(bloc.state.pending, isEmpty);
    expect(answers.single.allow, isFalse);
  });

  test('closing the prompt denies once and remembers nothing', () async {
    request(tabA, 'a', prompt(5, PromptPermission.geolocation));
    await settle();
    bloc.add(PermissionPromptClosed(bloc.state.promptFor('a')!));
    await settle();
    expect(answers.single.allow, isFalse);
    expect(answers.single.promptResult, PermissionPromptResult.dismiss);
    expect(repo.data, isEmpty);
  });

  test('navigating to another origin drops the request', () async {
    request(tabA, 'a', media(1, camMic));
    await settle();
    bloc.add(
      const PermissionTabNavigated(
        tabId: 'a',
        url: 'https://meet.example.com/room/2',
      ),
    );
    await settle();
    expect(bloc.state.pending, hasLength(1), reason: 'same origin keeps it');

    bloc.add(
      const PermissionTabNavigated(tabId: 'a', url: 'https://other.org/'),
    );
    await settle();
    expect(bloc.state.pending, isEmpty);
  });

  test('native dismissal and disposed tabs remove pending requests', () async {
    request(tabA, 'a', prompt(9, PromptPermission.geolocation));
    request(tabB, 'b', media(9, camMic));
    await settle();
    bloc.add(
      PermissionDismissed(controller: tabA, requestId: 9, isMedia: false),
    );
    await settle();
    expect(bloc.state.pending.single.tabId, 'b');
    bloc.add(PermissionControllerDisposed(tabB));
    await settle();
    expect(bloc.state.pending, isEmpty);
    expect(answers, isEmpty);
  });

  group('private tabs', () {
    test('inherit blocks but not allows', () async {
      repo.save('https://meet.example.com', [SitePermissionKind.camera], true);
      repo.save('https://maps.example.com', [
        SitePermissionKind.location,
      ], false);

      request(
        tabA,
        'a',
        media(1, MediaPermission.deviceVideoCapture),
        isPrivate: true,
      );
      request(
        tabA,
        'a',
        prompt(2, PromptPermission.geolocation),
        isPrivate: true,
      );
      await settle();

      expect(bloc.state.pending.single.request.requestId, 1);
      expect(answers.single.request.requestId, 2);
      expect(answers.single.allow, isFalse);
    });

    test('decisions stay in memory and end with the session', () async {
      request(tabA, 'a', media(1, camMic), isPrivate: true);
      await settle();
      bloc.add(PermissionDecided(bloc.state.promptFor('a')!, allow: true));
      await settle();
      expect(repo.data, isEmpty);

      request(tabA, 'a', media(2, camMic), isPrivate: true);
      await settle();
      expect(answers.last.allow, isTrue);
      expect(bloc.state.pending, isEmpty);

      bloc.add(const PermissionPrivateSessionEnded());
      request(tabA, 'a', media(3, camMic), isPrivate: true);
      await settle();
      expect(bloc.state.pending, hasLength(1));
    });
  });

  test('settings changes and resets update the list', () async {
    bloc.add(
      const SitePermissionChanged(
        origin: 'https://a.com',
        kind: SitePermissionKind.camera,
        allowed: false,
      ),
    );
    await settle();
    expect(bloc.state.sitePermissions.single.allowed, isFalse);
    bloc.add(const SitePermissionReset('https://a.com'));
    await settle();
    expect(bloc.state.sitePermissions, isEmpty);
  });
}
