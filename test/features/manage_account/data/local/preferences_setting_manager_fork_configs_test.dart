import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tmail_ui_user/features/manage_account/data/local/preferences_setting_manager.dart';
import 'package:tmail_ui_user/features/manage_account/domain/model/preferences/auto_sync_config.dart';
import 'package:tmail_ui_user/features/manage_account/domain/model/preferences/quoted_content_config.dart';
import 'package:tmail_ui_user/features/manage_account/domain/model/preferences/sidebar_config.dart';

void main() {
  test(
    'fork settings retain legacy keys and concrete types when loaded',
    () async {
      SharedPreferences.setMockInitialValues({
        'PREFERENCES_SETTING_AUTO_SYNC': jsonEncode({'isEnabled': false}),
        'PREFERENCES_SETTING_QUOTED_CONTENT': jsonEncode({
          'isHiddenByDefault': false,
        }),
        'PREFERENCES_SETTING_SIDEBAR': jsonEncode({'isExpanded': false}),
      });
      final storage = await SharedPreferences.getInstance();
      final manager = PreferencesSettingManager(storage);

      final loaded = await manager.loadPreferences();

      expect(
        loaded.configs.whereType<AutoSyncConfig>().single.isEnabled,
        false,
      );
      expect(loaded.quotedContentConfig.isHiddenByDefault, false);
      expect(
        loaded.configs.whereType<SidebarConfig>().single.isExpanded,
        false,
      );
      await manager.savePreferences(AutoSyncConfig(isEnabled: true));
      await manager.savePreferences(
        QuotedContentConfig(isHiddenByDefault: true),
      );
      await manager.savePreferences(SidebarConfig(isExpanded: true));
      expect(jsonDecode(storage.getString('PREFERENCES_SETTING_AUTO_SYNC')!), {
        'isEnabled': true,
      });
      expect(
        jsonDecode(storage.getString('PREFERENCES_SETTING_QUOTED_CONTENT')!),
        {'isHiddenByDefault': true},
      );
      expect(jsonDecode(storage.getString('PREFERENCES_SETTING_SIDEBAR')!), {
        'isExpanded': true,
      });
    },
  );

  test(
    'malformed fork settings fall back to defaults without blocking load',
    () async {
      SharedPreferences.setMockInitialValues({
        'PREFERENCES_SETTING_AUTO_SYNC': 'invalid json',
        'PREFERENCES_SETTING_QUOTED_CONTENT': '[]',
        'PREFERENCES_SETTING_SIDEBAR': jsonEncode({'isExpanded': 'invalid'}),
      });
      final manager = PreferencesSettingManager(
        await SharedPreferences.getInstance(),
      );

      expect((await manager.getAutoSyncConfig()).isEnabled, true);
      expect((await manager.getQuotedContentConfig()).isHiddenByDefault, true);
      expect((await manager.getSidebarConfig()).isExpanded, true);
      expect((await manager.loadPreferences()).configs, isEmpty);
    },
  );
}
