import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html_editor_enhanced/utils/html_editor_constants.dart';
import 'package:tmail_ui_user/main/utils/asset_preloader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'HTML editor fonts preload using bundle keys rather than browser URLs',
    () async {
      final requested = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        requested.add(
          utf8.decode(
            message!.buffer.asUint8List(
              message.offsetInBytes,
              message.lengthInBytes,
            ),
          ),
        );
        return ByteData(1);
      });
      addTearDown(
        () => messenger.setMockMessageHandler('flutter/assets', null),
      );

      await AssetPreloader.preloadHtmlEditorAssets();

      expect(
        requested,
        unorderedEquals([
          HtmlEditorConstants.summernoteHtmlAssetPath,
          HtmlEditorConstants.jqueryAssetPath,
          HtmlEditorConstants.summernoteCSSAssetPath,
          HtmlEditorConstants.summernoteJSAssetPath,
          'packages/html_editor_enhanced/assets/font/summernote.eot',
          'packages/html_editor_enhanced/assets/font/summernote.ttf',
        ]),
      );
      // The dependency's browser URLs still retain the prefix used by iframe CSS.
      expect(
        HtmlEditorConstants.summernoteFontEOTAssetPath,
        startsWith('assets/'),
      );
      expect(
        HtmlEditorConstants.summernoteFontTTFAssetPath,
        startsWith('assets/'),
      );
    },
  );
}
