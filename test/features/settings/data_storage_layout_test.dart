import 'package:ababilx/core/network/network_class.dart';
import 'package:ababilx/core/network/network_probe.dart';
import 'package:ababilx/features/attachments/storage/storage_providers.dart';
import 'package:ababilx/features/attachments/storage/storage_usage.dart';
import 'package:ababilx/features/notifications/native/android_battery.dart';
import 'package:ababilx/features/notifications/providers/battery_optimization_provider.dart';
import 'package:ababilx/features/settings/data-storage/data_storage_screen.dart';
import 'package:ababilx/features/settings/data-storage/storage_management_screen.dart';
import 'package:ababilx/features/settings/settings-hub/settings_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Data-and-storage screens on the narrowest phone we support.
///
/// A RenderFlex overflow throws inside `pumpWidget`, so "no exception" is the
/// assertion — these screens are almost entirely rows of label plus value, and
/// a translated label next to "Wi-Fi, Cellular" is exactly the pair that runs
/// out of width first.
void main() {
  const small = Size(320, 640);

  const usage = StorageUsage(
    bytes: {
      StorageBucket.photos: 1200 * 1024 * 1024,
      StorageBucket.videos: 3400 * 1024 * 1024,
      StorageBucket.audio: 1,
    },
    counts: {
      StorageBucket.photos: 210,
      StorageBucket.videos: 12,
      StorageBucket.audio: 1,
    },
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = small;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageUsageProvider.overrideWith((ref) async => usage),
          storageByConversationProvider.overrideWith((ref) async => const []),
          networkClassProvider.overrideWith(
            (ref) => Stream.value(NetworkClass.roaming),
          ),
          batteryRestrictionsProvider.overrideWith(
            (ref) async => const BatteryRestrictions(),
          ),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Data and storage lays out at 320dp', (tester) async {
    await pump(tester, const DataStorageScreen());
    expect(find.text('Media auto-download'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    // Defaults, rendered as the row's trailing value.
    expect(find.text('Wi-Fi, Cellular'), findsWidgets);
    expect(find.text('Never'), findsWidgets);
    // The total from Manage storage, and the live connection under the group.
    expect(find.text('4.5 GB'), findsOneWidget);
    expect(find.textContaining('roaming right now'), findsOneWidget);
    // The ceiling is quoted from the constant that enforces it, so the copy
    // cannot drift away from the behaviour.
    expect(find.textContaining('larger than 5.0 MB'), findsOneWidget);
  });

  testWidgets('Manage storage lays out at 320dp', (tester) async {
    await pump(tester, const StorageManagementScreen());
    expect(find.text('4.5 GB'), findsOneWidget);
    expect(find.text('223 files kept on this phone'), findsOneWidget);
    // A bucket holding a single byte still earns a legend entry rather than
    // rounding out of the chart.
    expect(find.text('Audio'), findsOneWidget);
    expect(
      find.text('No chat is using storage on this phone.'),
      findsOneWidget,
    );
    expect(find.text('Delete older media'), findsOneWidget);
  });

  testWidgets('a row with nothing to do reads as disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsRow(
            icon: HugeIcons.strokeRoundedDelete02,
            title: 'Delete all downloaded media',
            subtitle: 'Messages stay — media can be downloaded again',
            destructive: true,
          ),
        ),
      ),
    );
    final title = tester.widget<Text>(find.text('Delete all downloaded media'));
    expect(title.style?.color?.a, closeTo(0.38, 0.01));
  });

  testWidgets('a long value never pushes the title off the row', (
    tester,
  ) async {
    tester.view.physicalSize = small;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsRow(
            icon: HugeIcons.strokeRoundedImage01,
            title: 'Automatikus letoltes mobilhalozaton keresztul',
            value: 'Wi-Fi, Cellular, Roaming',
            onTap: () {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
