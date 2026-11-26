import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/model/state/network_state.dart';
import 'package:localsend_app/model/state/server/server_state.dart';
import 'package:localsend_app/model/state/settings_state.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/tabs/receive_tab.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/widget/column_list_view.dart';
import 'package:localsend_app/widget/local_send_logo.dart';
import 'package:localsend_app/widget/responsive_builder.dart';
import 'package:localsend_isolates/constants.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../mocks.mocks.dart';

class _TestSettingsNotifier extends SettingsService {
  final SettingsState _initial;

  _TestSettingsNotifier(this._initial) : super(MockPersistenceService());

  @override
  SettingsState init() => _initial;
}

class _TestLocalIpNotifier extends LocalIpService {
  final NetworkState _initial;

  _TestLocalIpNotifier(this._initial, super.settingsService);

  @override
  NetworkState init() => _initial;
}

class _TestServerNotifier extends ServerService {
  final ServerState? _initial;

  _TestServerNotifier(this._initial);

  @override
  ServerState? init() => _initial;
}

const _onlineServerState = ServerState(
  alias: 'Test Device',
  port: defaultPort,
  https: true,
  session: null,
  web: null,
);

SettingsState _fakeSettings() {
  return const SettingsState(
    showToken: 'token',
    alias: 'Test Device',
    theme: ThemeMode.dark,
    colorMode: ColorMode.system,
    customColor: Colors.teal,
    locale: null,
    port: defaultPort,
    networkWhitelist: null,
    networkBlacklist: null,
    multicastGroup: defaultMulticastGroup,
    destination: null,
    saveToGallery: false,
    saveToHistory: true,
    quickSave: false,
    quickSaveFromFavorites: false,
    receivePin: null,
    autoFinish: false,
    minimizeToTray: false,
    https: true,
    sendMode: SendMode.single,
    saveWindowPlacement: true,
    alwaysOnTop: false,
    enableAnimations: true,
    deviceType: DeviceType.mobile,
    deviceModel: 'iPhone',
    shareViaLinkAutoAccept: false,
    receiveViaLinkAutoAccept: false,
    createChecksums: false,
    verifyChecksums: false,
    discoveryTimeout: defaultDiscoveryTimeout,
    advancedSettings: false,
  );
}

Finder _findLinkButton() {
  return find.ancestor(
    of: find.text(t.receiveTab.link),
    matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
  );
}

SafeArea _contentSafeArea(WidgetTester tester) {
  final finder = find.ancestor(
    of: find.byType(ReceiveTab),
    matching: find.byType(SafeArea),
  );
  return tester.widget<SafeArea>(finder.first);
}

Future<void> _withHomeScaffold(
  WidgetTester tester, {
  required Size size,
  EdgeInsets padding = EdgeInsets.zero,
  TextDirection textDirection = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
  ServerState? serverState = _onlineServerState,
  required Future<void> Function() body,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final errors = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = errors.add;

  try {
    final settingsNotifier = _TestSettingsNotifier(_fakeSettings());
    await tester.pumpWidget(
      RefenaScope(
        overrides: [
          settingsProvider.overrideWithNotifier((_) => settingsNotifier),
          localIpProvider.overrideWithNotifier(
            (_) => _TestLocalIpNotifier(
              const NetworkState(localIps: ['192.0.2.1'], initialized: true),
              settingsNotifier,
            ),
          ),
          serverProvider.overrideWithNotifier((_) => _TestServerNotifier(serverState)),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: padding,
              viewPadding: padding,
              textScaler: textScaler,
            ),
            child: Directionality(
              textDirection: textDirection,
              child: HomeScaffold(
                currentTab: HomeTab.receive,
                onTabChanged: (_) {},
                child: const ReceiveTab(),
              ),
            ),
          ),
        ),
      ),
    );
    // Advance past InitialFadeTransition delays (200ms/500ms) and 300ms fade durations.
    // Avoid pumpAndSettle because RotatingWidget ticks continuously while serverState != null.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 350));

    expect(errors, isEmpty);
    expect(tester.takeException(), isNull);

    await body();

    expect(errors, isEmpty);
    expect(tester.takeException(), isNull);
  } finally {
    // Unmount and drain RotatingWidget's 33ms sleep timer cleanly.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    FlutterError.onError = previousOnError;
  }
}

void main() {
  group('SizingInformation', () {
    test('uses navigation rail on compact-height landscape viewports', () {
      const foldedLandscape = SizingInformation(678, 466);
      expect(foldedLandscape.isMobile, isTrue);
      expect(foldedLandscape.isDesktop, isFalse);
      expect(foldedLandscape.useNavigationRail, isTrue);

      const phoneLandscape = SizingInformation(667, 375);
      expect(phoneLandscape.isMobile, isTrue);
      expect(phoneLandscape.useNavigationRail, isTrue);
    });

    test('keeps bottom navigation bar on portrait mobile and unfolded portrait', () {
      const foldedPortrait = SizingInformation(466, 678);
      expect(foldedPortrait.isMobile, isTrue);
      expect(foldedPortrait.useNavigationRail, isFalse);

      const unfoldedPortrait = SizingInformation(669, 951);
      expect(unfoldedPortrait.isMobile, isTrue);
      expect(unfoldedPortrait.useNavigationRail, isFalse);

      const singleArgNarrow = SizingInformation(600);
      expect(singleArgNarrow.useNavigationRail, isFalse);
    });

    test('uses extended desktop navigation rail on wide viewports', () {
      const unfoldedLandscape = SizingInformation(951, 669);
      expect(unfoldedLandscape.isMobile, isFalse);
      expect(unfoldedLandscape.isTabletOrDesktop, isTrue);
      expect(unfoldedLandscape.isDesktop, isTrue);
      expect(unfoldedLandscape.useNavigationRail, isTrue);
    });

    test('enforces exact width and compact-height threshold boundaries', () {
      expect(const SizingInformation(650, 550).useNavigationRail, isFalse);
      expect(const SizingInformation(650, 549).useNavigationRail, isTrue);
      expect(const SizingInformation(500, 500).useNavigationRail, isFalse);
      expect(const SizingInformation(700, 900).useNavigationRail, isTrue);
      expect(const SizingInformation(700).useNavigationRail, isTrue);
      expect(const SizingInformation(699).useNavigationRail, isFalse);
    });
  });

  group('ResponsiveBuilder', () {
    testWidgets('passes both width and height from MediaQuery to SizingInformation', (tester) async {
      late SizingInformation captured;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(678, 466)),
          child: ResponsiveBuilder(
            builder: (info) {
              captured = info;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(captured.isMobile, isTrue);
      expect(captured.useNavigationRail, isTrue);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(466, 678)),
          child: ResponsiveBuilder(
            builder: (info) {
              captured = info;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(captured.isMobile, isTrue);
      expect(captured.useNavigationRail, isFalse);
    });
  });

  group('HomeScaffold and ReceiveTab layout', () {
    testWidgets('compact landscape 678x466 LTR uses rail, safe insets, and keeps Receive via link tappable', (tester) async {
      await _withHomeScaffold(
        tester,
        size: const Size(678, 466),
        padding: const EdgeInsets.only(left: 59, bottom: 21),
        body: () async {
          final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
          expect(rail.extended, isFalse);
          expect(find.byType(NavigationBar), findsNothing);

          final safeArea = _contentSafeArea(tester);
          expect(safeArea.left, isFalse);
          expect(safeArea.right, isTrue);

          final aliasFinder = find.descendant(
            of: find.byType(ColumnListView),
            matching: find.text('Test Device'),
          );
          expect(aliasFinder, findsOneWidget);
          expect(find.text('#1'), findsOneWidget);

          final linkButton = _findLinkButton();
          expect(linkButton.hitTestable(), findsOneWidget);
          expect(tester.getBottomLeft(linkButton).dy, lessThanOrEqualTo(466 - 21));

          final logo = tester.widget<LocalSendLogo>(find.byType(LocalSendLogo));
          expect(logo.size, lessThan(200));
        },
      );
    });

    testWidgets('compact landscape 678x466 RTL flips content SafeArea horizontal edges', (tester) async {
      await _withHomeScaffold(
        tester,
        size: const Size(678, 466),
        padding: const EdgeInsets.only(right: 59, bottom: 21),
        textDirection: TextDirection.rtl,
        body: () async {
          expect(find.byType(NavigationRail), findsOneWidget);
          expect(find.byType(NavigationBar), findsNothing);

          final safeArea = _contentSafeArea(tester);
          expect(safeArea.left, isTrue);
          expect(safeArea.right, isFalse);

          expect(find.text('#1'), findsOneWidget);
          expect(_findLinkButton().hitTestable(), findsOneWidget);
        },
      );
    });

    testWidgets('compact phone landscape 667x375 uses rail and keeps #1 and Receive via link visible', (tester) async {
      await _withHomeScaffold(
        tester,
        size: const Size(667, 375),
        padding: const EdgeInsets.only(bottom: 21),
        body: () async {
          expect(find.byType(NavigationRail), findsOneWidget);
          expect(find.byType(NavigationBar), findsNothing);
          expect(find.text('#1'), findsOneWidget);

          final linkButton = _findLinkButton();
          expect(linkButton.hitTestable(), findsOneWidget);
          expect(tester.getBottomLeft(linkButton).dy, lessThanOrEqualTo(375));
        },
      );
    });

    testWidgets('portrait 466x678 uses bottom NavigationBar, full SafeArea, and 200px logo', (tester) async {
      await _withHomeScaffold(
        tester,
        size: const Size(466, 678),
        body: () async {
          expect(find.byType(NavigationBar), findsOneWidget);
          expect(find.byType(NavigationRail), findsNothing);

          final safeArea = _contentSafeArea(tester);
          expect(safeArea.left, isTrue);
          expect(safeArea.right, isTrue);

          final logo = tester.widget<LocalSendLogo>(find.byType(LocalSendLogo));
          expect(logo.size, equals(200));
          expect(find.text('#1'), findsOneWidget);
        },
      );
    });

    testWidgets('tall portrait 669x951 uses bottom NavigationBar, full SafeArea, and 200px logo', (tester) async {
      await _withHomeScaffold(
        tester,
        size: const Size(669, 951),
        body: () async {
          expect(find.byType(NavigationBar), findsOneWidget);
          expect(find.byType(NavigationRail), findsNothing);

          final safeArea = _contentSafeArea(tester);
          expect(safeArea.left, isTrue);
          expect(safeArea.right, isTrue);

          final logo = tester.widget<LocalSendLogo>(find.byType(LocalSendLogo));
          expect(logo.size, equals(200));
          expect(find.text('#1'), findsOneWidget);
        },
      );
    });

    testWidgets('wide landscape 951x669 uses extended NavigationRail and 200px logo', (tester) async {
      await _withHomeScaffold(
        tester,
        size: const Size(951, 669),
        body: () async {
          final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
          expect(rail.extended, isTrue);
          expect(find.byType(NavigationBar), findsNothing);

          final logo = tester.widget<LocalSendLogo>(find.byType(LocalSendLogo));
          expect(logo.size, equals(200));
          expect(find.text('#1'), findsOneWidget);
        },
      );
    });

    testWidgets('extreme small height 667x240 scrolls cleanly with zero overflow and reachable Receive via link', (tester) async {
      await _withHomeScaffold(
        tester,
        size: const Size(667, 240),
        body: () async {
          expect(find.byType(ColumnListView), findsOneWidget);

          final logo = tester.widget<LocalSendLogo>(find.byType(LocalSendLogo));
          expect(logo.size, lessThan(80));
          expect(logo.size, greaterThanOrEqualTo(64));

          final linkButton = _findLinkButton();
          await tester.ensureVisible(linkButton);
          await tester.pump();
          expect(linkButton.hitTestable(), findsOneWidget);
        },
      );
    });

    testWidgets('large text scale 2.0 at 667x375 scrolls cleanly with zero overflow and reachable Receive via link', (tester) async {
      await _withHomeScaffold(
        tester,
        size: const Size(667, 375),
        textScaler: const TextScaler.linear(2.0),
        body: () async {
          expect(find.byType(ColumnListView), findsOneWidget);

          final linkButton = _findLinkButton();
          await tester.ensureVisible(linkButton);
          await tester.pump();
          expect(linkButton.hitTestable(), findsOneWidget);
        },
      );
    });
  });
}
