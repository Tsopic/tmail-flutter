import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:linagora_design_flutter/linagora_design_flutter.dart';
import 'package:tmail_ui_user/features/base/model/ui_keys.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';

class ComposeButtonWidget extends StatelessWidget {
  final ImagePaths imagePaths;
  final VoidCallback onTapAction;
  final bool isCollapsed;
  final EdgeInsetsGeometry? padding;
  final double? width;

  const ComposeButtonWidget({
    super.key,
    required this.imagePaths,
    required this.onTapAction,
    this.isCollapsed = false,
    this.padding,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final primaryActionStyle = LinagoraSidebarButtonStyles.primaryAction(
      context,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The light theme keeps the TMail compose brand color instead of the
    // design system primary action color, which stays in use for dark mode.
    final style = isDark
        ? primaryActionStyle
        : primaryActionStyle.copyWith(
            backgroundColor: const WidgetStatePropertyAll(
              AppColor.colorComposeButton,
            ),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
          );
    final iconColor =
        style.foregroundColor?.resolve(const <WidgetState>{}) ?? Colors.white;
    if (isCollapsed) {
      return Padding(
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Tooltip(
          message: AppLocalizations.of(context).compose,
          child: SizedBox(
            width: 44,
            height: 44,
            child: FilledButton(
              key: const Key('compose_email_button_collapsed'),
              style: style.copyWith(
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
              ),
              onPressed: onTapAction,
              child: SvgPicture.asset(
                imagePaths.icPenNoBorder,
                width: 16,
                height: 16,
                colorFilter: iconColor.asFilter(),
              ),
            ),
          ),
        ),
      );
    }
    final resolvedPadding =
        padding ??
        const EdgeInsetsDirectional.only(
          start: 16,
          end: 16,
          top: 16,
          bottom: 8,
        );
    final horizontalPadding = resolvedPadding
        .resolve(Directionality.of(context))
        .horizontal;
    final defaultWidth = ResponsiveUtils.sidebarMenuWidth - horizontalPadding;

    return LinagoraSidebarPrimaryAction(
      label: AppLocalizations.of(context).compose,
      onPressed: onTapAction,
      buttonKey: const Key(UiKeys.composeEmailPrimaryAction),
      iconSpacing: LinagoraSidebarButtonStyles.primaryActionIconSpacing,
      outerPadding: resolvedPadding,
      width: width ?? (defaultWidth < 0 ? 0 : defaultWidth),
      alignment: AlignmentDirectional.centerStart,
      style: style,
      iconWidget: SvgPicture.asset(
        imagePaths.icPenNoBorder,
        width: 12,
        height: 12,
        colorFilter: iconColor.asFilter(),
        fit: BoxFit.contain,
      ),
    );
  }
}
