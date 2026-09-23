import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in4up/services/auth_service.dart';
import 'package:in4up/services/firebase_rest_auth.dart' show FirebaseRestAuth;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final restAuth = FirebaseRestAuth();
  final subscriptions = <StreamSubscription<AppUser?>>[];
  late Directory directory;

  List<AppUser?> listen(Stream<AppUser?> stream) {
    final events = <AppUser?>[];
    subscriptions.add(stream.listen(events.add));
    return events;
  }

  Future<void> flushEvents() => Future<void>.delayed(Duration.zero);

  Future<AppUser?> signIn() async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/accounts:signInWithIdp');
      return http.Response(
        jsonEncode({
          'localId': 'test-user',
          'email': 'test@example.com',
          'displayName': 'Test User',
          'idToken': 'test-id-token',
          'refreshToken': 'test-refresh-token',
          'expiresIn': '3600',
        }),
        200,
      );
    });
    try {
      return await http.runWithClient(
        () => restAuth.signInWithGoogleIdToken(
          googleIdToken: 'test-google-token',
          requestUri: 'http://localhost',
        ),
        () => client,
      );
    } finally {
      client.close();
    }
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('rest_auth_stream_');
    Hive.init(directory.path);
    await restAuth.signOut();
  });

  tearDown(() async {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    subscriptions.clear();
    await restAuth.signOut();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('the same REST stream supports simultaneous listeners', () async {
    final stream = restAuth.authStateChanges;
    expect(stream.isBroadcast, isTrue);
    expect(identical(stream, restAuth.authStateChanges), isTrue);

    final sync = listen(stream);
    final home = listen(stream);
    await flushEvents();
    expect(sync, [null]);
    expect(home, [null]);

    final user = await signIn();
    await flushEvents();
    expect(sync, [null, user]);
    expect(home, [null, user]);

    await restAuth.signOut();
    await flushEvents();
    expect(sync, [null, user, null]);
    expect(home, [null, user, null]);
  });

  test('late listener receives current user without notifying others', () async {
    final stream = restAuth.authStateChanges;
    final sync = listen(stream);
    await flushEvents();
    final user = await signIn();
    await flushEvents();

    final home = listen(stream);
    await flushEvents();
    expect(home, [user]);
    expect(home.single?.uid, 'test-user');
    expect(sync, [null, user]);

    await restAuth.signOut();
    await flushEvents();
    final lateHome = listen(stream);
    await flushEvents();
    expect(lateHome, [null]);
    expect(home, [user, null]);
    expect(sync, [null, user, null]);
  });

  test('cancelling one listener leaves others active', () async {
    final stream = restAuth.authStateChanges;
    final home = listen(stream);
    final homeSubscription = subscriptions.last;
    final sync = listen(stream);
    await flushEvents();
    await homeSubscription.cancel();

    final user = await signIn();
    await flushEvents();
    expect(home, [null]);
    expect(sync, [null, user]);
  });

  test('same stream can be listened to again after all listeners cancel',
      () async {
    final stream = restAuth.authStateChanges;
    final first = listen(stream);
    await flushEvents();
    await subscriptions.last.cancel();

    // Auth can change while Home is unmounted and no listeners remain.
    final user = await signIn();
    final reopened = listen(stream);
    await flushEvents();
    expect(first, [null]);
    expect(reopened, [user]);
  });

  test('pausing one listener does not pause other listeners', () async {
    final stream = restAuth.authStateChanges;
    final paused = listen(stream);
    final pausedSubscription = subscriptions.last;
    final active = listen(stream);
    await flushEvents();
    pausedSubscription.pause();

    final user = await signIn();
    await restAuth.signOut();
    await flushEvents();
    expect(paused, [null]);
    expect(active, [null, user, null]);

    pausedSubscription.resume();
    await flushEvents();
    expect(paused, [null, user, null]);
  });

  testWidgets('cached AuthService stream supports sync and Home remount',
      (tester) async {
    // No Firebase app/plugin is initialized, matching Linux's REST fallback.
    final auth = AuthService();
    expect(auth.isPluginAuthAvailable, isFalse);
    final stream = auth.authStateChanges;
    expect(identical(stream, auth.authStateChanges), isTrue);

    final sync = listen(stream);
    await tester.pump();
    expect(sync, [null]);

    Widget homeAuthButton() => Directionality(
          textDirection: TextDirection.ltr,
          child: StreamBuilder<AppUser?>(
            stream: auth.authStateChanges,
            builder: (context, snapshot) => Text(
              snapshot.connectionState == ConnectionState.waiting
                  ? 'waiting'
                  : snapshot.data?.uid ?? 'signed out',
            ),
          ),
        );

    await tester.pumpWidget(homeAuthButton());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('signed out'), findsOneWidget);
    expect(find.text('waiting'), findsNothing);
    expect(sync, [null]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(homeAuthButton());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('signed out'), findsOneWidget);
    expect(sync, [null]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
