import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/manage_account/domain/model/preferences/preferences_setting.dart';
import 'package:tmail_ui_user/features/manage_account/domain/model/preferences/quoted_content_config.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/preferences/model/preference_options.dart';

import '../../../../../../fixtures/preference_option_fixtures.dart';

void main() {
  test(
    'quoted content toggle persists the inverse of the displayed setting',
    () async {
      final interactor = FakeUpdateLocalSettingsInteractor();
      final option = QuotedContentPreferenceOption(interactor);
      final context = preferencesContext(
        localSettings: PreferencesSetting([
          QuotedContentConfig(isHiddenByDefault: false),
        ]),
      );

      expect(option.isAvailable(context), true);
      expect(option.isEnabled(context), false);
      await option.toggle(currentValue: false, context: context).drain<void>();
      expect(
        (interactor.captured as QuotedContentConfig).isHiddenByDefault,
        true,
      );
    },
  );
}
