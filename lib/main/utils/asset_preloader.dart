import 'package:core/utils/app_logger.dart';
import 'package:html_editor_enhanced/utils/html_editor_constants.dart';
import 'package:html_editor_enhanced/utils/html_editor_utils.dart';

class AssetPreloader {
  const AssetPreloader._();

  static Future<void> preloadHtmlEditorAssets() async {
    try {
      await Future.wait([
        HtmlEditorUtils.loadAsset(HtmlEditorConstants.summernoteHtmlAssetPath),
        HtmlEditorUtils.loadAsset(HtmlEditorConstants.jqueryAssetPath),
        HtmlEditorUtils.loadAsset(HtmlEditorConstants.summernoteCSSAssetPath),
        HtmlEditorUtils.loadAsset(HtmlEditorConstants.summernoteJSAssetPath),
        // Font constants are browser URLs; rootBundle expects manifest keys.
        HtmlEditorUtils.loadAsset(
          HtmlEditorConstants.summernoteFontEOTAssetPath.replaceFirst(
            'assets/',
            '',
          ),
        ),
        HtmlEditorUtils.loadAsset(
          HtmlEditorConstants.summernoteFontTTFAssetPath.replaceFirst(
            'assets/',
            '',
          ),
        ),
      ]);
    } catch (e) {
      logWarning('AssetPreloader::preloadHtmlEditorAssets:Exception = $e');
    }
  }
}
