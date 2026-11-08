import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:model/upload/file_info.dart';
import 'package:tmail_ui_user/features/composer/presentation/mixin/drag_drog_file_mixin.dart';

class _FakeDroppedFile {
  final String name;
  final String? mimeType;
  final String path;
  int readCalls = 0;

  _FakeDroppedFile({
    required this.path,
    required this.name,
    required this.mimeType,
  });

  Future<int> length() => File(path).length();

  Future<Uint8List> readAsBytes() async {
    readCalls++;
    return Uint8List(0);
  }
}

void main() {
  test(
    'fileInfoFromDroppedFile prefers filePath on non-web (avoids readAsBytes)',
    () async {
      final dir = await Directory.systemTemp.createTemp('tmail-drop-');
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });

      final file = File('${dir.path}/a.bin');
      await file.writeAsBytes(List<int>.generate(1024, (i) => i % 256));

      final fake = _FakeDroppedFile(
        path: file.path,
        name: 'a.bin',
        mimeType: 'application/octet-stream',
      );

      final info = await fileInfoFromDroppedFile(fake);
      expect(info, isA<FilePathInfo>());
      expect((info as FilePathInfo).filePath, file.path);
      expect(info.fileSize, 1024);
      expect(fake.readCalls, 0);
    },
  );

  test('fileInfoFromDroppedFile falls back to bytes when no path', () async {
    final fake = _FakeDroppedFile(
      path: '',
      name: 'a.bin',
      mimeType: 'application/octet-stream',
    );

    final info = await fileInfoFromDroppedFile(fake);
    expect(info, isA<FileBytesInfo>());
    expect((info as FileBytesInfo).bytes, isNotNull);
    expect(fake.readCalls, 1);
  });
}
