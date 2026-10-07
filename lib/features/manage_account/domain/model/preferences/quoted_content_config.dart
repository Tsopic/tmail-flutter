import 'package:tmail_ui_user/features/manage_account/domain/model/preferences/preferences_config.dart';

class QuotedContentConfig extends PreferencesConfig {
  static const keySuffix = 'QUOTED_CONTENT';

  @override
  String get configKey => keySuffix;

  final bool isHiddenByDefault;

  QuotedContentConfig({this.isHiddenByDefault = true});

  factory QuotedContentConfig.initial() => QuotedContentConfig();

  factory QuotedContentConfig.fromJson(Map<String, dynamic> json) {
    return QuotedContentConfig(
      isHiddenByDefault: json['isHiddenByDefault'] as bool? ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {'isHiddenByDefault': isHiddenByDefault};

  @override
  List<Object> get props => [isHiddenByDefault];
}

extension QuotedContentConfigExtension on QuotedContentConfig {
  QuotedContentConfig copyWith({bool? isHiddenByDefault}) {
    return QuotedContentConfig(
      isHiddenByDefault: isHiddenByDefault ?? this.isHiddenByDefault,
    );
  }
}
