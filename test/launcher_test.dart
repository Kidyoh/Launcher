import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/apps.dart';
import 'package:launcher/main.dart';
import 'package:launcher/native.dart';
import 'package:launcher/scope.dart';
import 'package:launcher/settings.dart';
import 'package:launcher/ui/drawer_screen.dart';
import 'package:launcher/ui/settings_screen.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _apps = [
  {
    'label': 'Calculator',
    'package': 'calc',
    'activity': 'Main',
    'user': 0,
    'work': false,
  },
  {
    'label': 'Camera',
    'package': 'cam',
    'activity': 'Main',
    'user': 0,
    'work': false,
  },
  {
    'label': 'Messages',
    'package': 'msg',
    'activity': 'Main',
    'user': 0,
    'work': false,
  },
  {
    'label': 'Slack',
    'package': 'slack',
    'activity': 'Main',
    'user': 10,
    'work': true,
  },
];

void main() {
  late List<MethodCall> calls;
  late bool isDefault;

  setUp(() {
    calls = [];
    isDefault = true;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('launcher/native'), (
          call,
        ) async {
          calls.add(call);
          return switch (call.method) {
            'getApps' => _apps,
            'lockScreen' => 'needs_permission',
            'isDefaultLauncher' => isDefault,
            _ => true,
          };
        });
  });

  Future<void> pumpLauncher(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Native.init();
    final settings = await Settings.load();
    final apps = AppRepository(settings);
    await apps.refresh();
    await tester.pumpWidget(
      Launcher(settings: settings, apps: apps, child: const LauncherApp()),
    );
    await tester.pumpAndSettle();
  }

  // Unmounts the clock so its minute timer doesn't outlive the test.
  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  List<String> called(String method) => [
    for (final c in calls)
      if (c.method == method) '${c.arguments}',
  ];

  const emptySpot = Offset(180, 330);

  testWidgets('swipe up, search, and the single match opens', (tester) async {
    await pumpLauncher(tester);
    expect(find.textContaining('Swipe up for all apps'), findsOneWidget);

    await tester.flingFrom(const Offset(180, 600), const Offset(0, -400), 1500);
    await tester.pumpAndSettle();
    expect(find.byType(DrawerScreen), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.textContaining('work', findRichText: true), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ca');
    await tester.pump();
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Messages'), findsNothing);

    await tester.enterText(find.byType(TextField), 'calc');
    await tester.pumpAndSettle();
    expect(called('launch').single, contains('calc'));
    expect(find.byType(DrawerScreen), findsNothing);

    await unmount(tester);
  });

  testWidgets('long-press adds to home, rename shows on home', (tester) async {
    await pumpLauncher(tester);
    await tester.flingFrom(const Offset(180, 600), const Offset(0, -400), 1500);
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Messages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to home'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Messages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Texts');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Home button returns to the home page from anywhere.
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'launcher/native',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('home'),
          ),
          (_) {},
        );
    await tester.pumpAndSettle();
    expect(find.byType(DrawerScreen), findsNothing);
    expect(find.text('Texts'), findsOneWidget);

    await tester.tap(find.text('Texts'));
    await tester.pump();
    expect(called('launch').single, contains('msg'));

    await unmount(tester);
  });

  testWidgets('gestures run their actions', (tester) async {
    await pumpLauncher(tester);

    await tester.flingFrom(const Offset(300, 400), const Offset(-250, 0), 1500);
    await tester.pumpAndSettle();
    expect(called('open'), ['{target: dialer, query: null}']);

    await tester.flingFrom(const Offset(60, 400), const Offset(250, 0), 1500);
    await tester.pumpAndSettle();
    expect(called('open').last, contains('camera'));

    await tester.flingFrom(const Offset(180, 300), const Offset(0, 300), 1500);
    await tester.pumpAndSettle();
    expect(called('expandNotifications'), hasLength(1));

    await tester.tapAt(emptySpot);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(emptySpot);
    await tester.pumpAndSettle();
    expect(find.text('Double tap to lock'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    await unmount(tester);
  });

  testWidgets('first open offers to become the home app, once', (tester) async {
    isDefault = false;
    await pumpLauncher(tester);
    expect(find.text('Make this your home screen'), findsOneWidget);
    await tester.tap(find.text('Set as default'));
    await tester.pumpAndSettle();
    expect(called('requestDefaultLauncher'), hasLength(1));
    expect(find.text('Make this your home screen'), findsNothing);

    // Not asked again on the next start, even if the user declined.
    await unmount(tester);
    await pumpLauncher(tester);
    expect(find.text('Make this your home screen'), findsNothing);
    await unmount(tester);
  });

  testWidgets('settings change the look', (tester) async {
    isDefault = false;
    await pumpLauncher(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    await tester.longPressAt(emptySpot);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Make this your home screen'), findsOneWidget);
    await tester.tap(find.text('Make this your home screen'));
    await tester.pumpAndSettle();
    expect(called('requestDefaultLauncher'), hasLength(1));

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.light,
    );

    await tester.tap(find.text('Show clock'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Double tap'), 200);
    await tester.tap(find.text('Double tap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Do nothing'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Home apps'), -200);
    await tester.tap(find.text('Home apps'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d{1,2}:\d\d$')), findsNothing);

    // Double tap now does nothing.
    await tester.tapAt(emptySpot);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(emptySpot);
    await tester.pumpAndSettle();
    expect(called('lockScreen'), isEmpty);

    await unmount(tester);
  });
}
