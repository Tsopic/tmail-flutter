import 'dart:async' as async;
import 'package:async/async.dart';
import 'package:core/data/constants/constant.dart';
import 'package:core/utils/platform_info.dart';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:future_loading_dialog/future_loading_dialog.dart';
import 'package:model/upload/file_info.dart';
import 'package:tmail_ui_user/features/upload/domain/extensions/x_file_extension.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';

@visibleForTesting
Future<FileInfo> fileInfoFromDroppedFile(dynamic xFile) async {
  if (PlatformInfo.isWeb && xFile is XFile) {
    return xFile.toFileInfo();
  }
  // desktop_drop uses XFile (from cross_file). Keep this helper dynamic to avoid
  // relying on transitive imports in production code.
  final String name = xFile.name as String;
  final String? mimeType = xFile.mimeType as String?;
  final String path = (xFile.path as String?) ?? '';
  final bool isInline = mimeType?.startsWith(Constant.imageType) == true;

  // Prefer file path on non-web to avoid loading entire files into memory.
  if (!PlatformInfo.isWeb && path.isNotEmpty) {
    final size = await xFile.length() as int;
    return FilePathInfo(
      fileName: name,
      fileSize: size,
      filePath: path,
      type: mimeType,
      isInline: isInline,
    );
  }

  final bytes = await xFile.readAsBytes();
  return FileBytesInfo(
    bytes: bytes,
    fileName: name,
    type: mimeType,
    fileSize: bytes.length,
    isInline: isInline,
  );
}

mixin DragDropFileMixin {
  async.Future<Result<T>> showFutureLoadingDialogFullScreen<T>({
    required BuildContext context,
    required async.Future<T> Function() future,
  }) async {
    return await showFutureLoadingDialog(
      context: context,
      title: AppLocalizations.of(context).loadingPleaseWait,
      backLabel: AppLocalizations.of(context).close,
      future: future,
    );
  }

  async.Future<({List<FileInfo> files, int folderCount})> onDragDone({
    required BuildContext context,
    required DropDoneDetails details,
  }) async {
    final files = await _withoutFolders(details.files);
    final folderCount = details.files.length - files.length;
    if (files.isEmpty || !context.mounted)
      return (files: <FileInfo>[], folderCount: folderCount);

    final result = await showFutureLoadingDialogFullScreen(
      context: context,
      future: () async {
        final converted = <FileInfo>[];
        for (final file in files) {
          converted.add(await fileInfoFromDroppedFile(file));
        }
        return converted;
      },
    );

    if (result.error != null)
      return (files: <FileInfo>[], folderCount: folderCount);

    return (files: result.result ?? <FileInfo>[], folderCount: folderCount);
  }

  async.Future<List<XFile>> _withoutFolders(List<XFile> files) async {
    final isFolder = await async.Future.wait(
      files.map((xFile) => xFile.isDroppedFolder()),
    );
    return [
      for (var i = 0; i < files.length; i++)
        if (!isFolder[i]) files[i],
    ];
  }
}
