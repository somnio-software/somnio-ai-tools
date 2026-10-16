import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/runner/drive_upload.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('drive_upload_test_');
  });

  tearDown(() => tmpDir.deleteSync(recursive: true));

  group('parseDriveFolderId', () {
    test('reads the ID from a folder link', () {
      expect(
        parseDriveFolderId(
          'https://drive.google.com/drive/folders/1AbC_dEf-123456789',
        ),
        '1AbC_dEf-123456789',
      );
    });

    test('ignores the query string of a shared link', () {
      expect(
        parseDriveFolderId(
          'https://drive.google.com/drive/u/0/folders/1AbCdEf123456?usp=sharing',
        ),
        '1AbCdEf123456',
      );
    });

    test('reads the ID from an open?id= link', () {
      expect(
        parseDriveFolderId('https://drive.google.com/open?id=1AbCdEf123456'),
        '1AbCdEf123456',
      );
    });

    test('accepts a bare ID with surrounding spaces', () {
      expect(parseDriveFolderId('  1AbCdEf123456  '), '1AbCdEf123456');
    });

    test('rejects empty input and things that are not IDs', () {
      expect(parseDriveFolderId(''), isNull);
      expect(parseDriveFolderId('my reports folder'), isNull);
      expect(parseDriveFolderId('short'), isNull);
    });
  });

  test('driveFolderUrl builds the folder link', () {
    expect(
      driveFolderUrl('abc123'),
      'https://drive.google.com/drive/folders/abc123',
    );
  });

  group('reportPrefsPath', () {
    test('defaults to ~/.somnio-reports-prefs.json', () {
      expect(
        reportPrefsPath(home: '/home/me'),
        p.join('/home/me', '.somnio-reports-prefs.json'),
      );
    });

    test('honours SOMNIO_REPORTS_PREFS_PATH', () {
      expect(
        reportPrefsPath(
          home: '/home/me',
          environment: {'SOMNIO_REPORTS_PREFS_PATH': '/tmp/prefs.json'},
        ),
        '/tmp/prefs.json',
      );
    });

    test('ignores an empty SOMNIO_REPORTS_PREFS_PATH', () {
      expect(
        reportPrefsPath(
          home: '/home/me',
          environment: {'SOMNIO_REPORTS_PREFS_PATH': ''},
        ),
        p.join('/home/me', '.somnio-reports-prefs.json'),
      );
    });
  });

  group('project folder prefs', () {
    late String prefsPath;

    setUp(() => prefsPath = p.join(tmpDir.path, 'nested', 'prefs.json'));

    Map<String, dynamic> readPrefs() =>
        jsonDecode(File(prefsPath).readAsStringSync()) as Map<String, dynamic>;

    test('returns null when the file does not exist', () {
      expect(readProjectFolderId(prefsPath, 'hoopis-backend'), isNull);
    });

    test('saves and reads back a project folder', () {
      saveProjectFolderId(prefsPath, 'hoopis-backend', 'folder123');

      expect(readProjectFolderId(prefsPath, 'hoopis-backend'), 'folder123');
      expect(readPrefs()['report_folders']['hoopis-backend'], {
        'folder_id': 'folder123',
        'folder_url': 'https://drive.google.com/drive/folders/folder123',
      });
    });

    test('keeps other keys and projects when saving', () {
      File(prefsPath)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            'other': true,
            'report_folders': {
              'app-one': {'folder_id': 'one'},
            },
          }),
        );

      saveProjectFolderId(prefsPath, 'app-two', 'two');

      final prefs = readPrefs();
      expect(prefs['other'], isTrue);
      expect(readProjectFolderId(prefsPath, 'app-one'), 'one');
      expect(readProjectFolderId(prefsPath, 'app-two'), 'two');
    });

    test('returns null for an unknown project or a malformed entry', () {
      File(prefsPath)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            'report_folders': {
              'bad-entry': 'not a map',
              'empty-id': {'folder_id': ''},
            },
          }),
        );

      expect(readProjectFolderId(prefsPath, 'missing'), isNull);
      expect(readProjectFolderId(prefsPath, 'bad-entry'), isNull);
      expect(readProjectFolderId(prefsPath, 'empty-id'), isNull);
    });

    test('returns null when report_folders is not a map', () {
      File(prefsPath)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode({'report_folders': []}));

      expect(readProjectFolderId(prefsPath, 'hoopis-backend'), isNull);
    });

    test('treats an empty file as empty prefs', () {
      File(prefsPath)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('  ');

      saveProjectFolderId(prefsPath, 'hoopis-backend', 'folder123');

      expect(readProjectFolderId(prefsPath, 'hoopis-backend'), 'folder123');
    });

    test('throws and keeps a file that is not a JSON object', () {
      File(prefsPath)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('[]');

      expect(
        () => saveProjectFolderId(prefsPath, 'hoopis-backend', 'folder123'),
        throwsFormatException,
      );
      expect(
        () => readProjectFolderId(prefsPath, 'hoopis-backend'),
        throwsFormatException,
      );
      expect(File(prefsPath).readAsStringSync(), '[]');
    });
  });

  group('DriveUploadResult.fromJson', () {
    test('parses an uploaded result', () {
      final result = DriveUploadResult.fromJson(
        jsonEncode({
          'status': 'uploaded',
          'file_id': 'file1',
          'title': 'report.md',
          'mime_type': 'text/markdown',
          'file_size': 120,
          'parent_id': 'folder1',
          'existing_file_id': null,
          'error': null,
        }),
      );

      expect(result.status, DriveUploadStatus.uploaded);
      expect(result.fileId, 'file1');
      expect(result.title, 'report.md');
      expect(result.mimeType, 'text/markdown');
      expect(result.fileSize, 120);
      expect(result.parentId, 'folder1');
      expect(result.existingFileId, isNull);
      expect(result.error, isNull);
    });

    test('accepts the file size as a string', () {
      final result = DriveUploadResult.fromJson(
        jsonEncode({'status': 'uploaded', 'file_size': '150'}),
      );

      expect(result.fileSize, 150);
    });

    test('parses the other statuses', () {
      expect(
        DriveUploadResult.fromJson(
          jsonEncode({'status': 'exists', 'existing_file_id': 'old'}),
        ).existingFileId,
        'old',
      );
      expect(
        DriveUploadResult.fromJson(
          jsonEncode({'status': 'failed', 'error': 'boom'}),
        ).error,
        'boom',
      );
      expect(
        DriveUploadResult.fromJson(jsonEncode({'status': 'no_drive_mcp'}))
            .status,
        DriveUploadStatus.noDriveMcp,
      );
    });

    test('rejects an unknown status, a missing status and non-objects', () {
      expect(
        () => DriveUploadResult.fromJson(jsonEncode({'status': 'done'})),
        throwsFormatException,
      );
      expect(
        () => DriveUploadResult.fromJson(jsonEncode({})),
        throwsFormatException,
      );
      expect(
        () => DriveUploadResult.fromJson('[]'),
        throwsFormatException,
      );
    });
  });

  group('verifyDriveUpload', () {
    late String reportPath;
    late int size;

    setUp(() {
      reportPath = p.join(tmpDir.path, '2026-09-14-hoopis-backend-a.md');
      File(reportPath).writeAsStringSync('# Report\n\nÁcentos y ñ\n');
      size = File(reportPath).lengthSync();
    });

    DriveUploadResult uploaded({
      String? fileId = 'file1',
      String? title = '2026-09-14-hoopis-backend-a.md',
      String? mimeType = 'text/markdown',
      int? fileSize,
      String? parentId = 'folder1',
    }) =>
        DriveUploadResult(
          status: DriveUploadStatus.uploaded,
          fileId: fileId,
          title: title,
          mimeType: mimeType,
          fileSize: fileSize ?? size,
          parentId: parentId,
        );

    test('passes when everything matches the local report', () {
      expect(
        verifyDriveUpload(
          result: uploaded(),
          reportPath: reportPath,
          folderId: 'folder1',
        ),
        isEmpty,
      );
    });

    test('reports every mismatch', () {
      final problems = verifyDriveUpload(
        result: uploaded(
          fileId: null,
          title: 'renamed.md',
          mimeType: 'application/vnd.google-apps.document',
          fileSize: size + 1,
          parentId: 'other',
        ),
        reportPath: reportPath,
        folderId: 'folder1',
      );

      expect(problems, hasLength(5));
      expect(problems[0], contains('no file ID'));
      expect(problems[1], contains('renamed.md'));
      expect(problems[2], contains('Google Doc'));
      expect(problems[3], contains('other'));
      expect(problems[4], contains('content changed'));
    });

    test('flags an empty file ID', () {
      expect(
        verifyDriveUpload(
          result: uploaded(fileId: ''),
          reportPath: reportPath,
          folderId: 'folder1',
        ),
        [contains('no file ID')],
      );
    });
  });

  group('buildDriveUploadPrompt', () {
    test('passes the report, folder and result paths', () {
      final prompt = buildDriveUploadPrompt(
        readInstruction: 'Read /skills/drive-upload.md',
        reportPath: '/repo/reports/2026-09-14-hoopis-backend-a.md',
        folderId: 'folder1',
        resultPath: '/repo/reports/.artifacts/a/drive_upload.json',
        replace: false,
      );

      expect(prompt, contains('Read /skills/drive-upload.md'));
      expect(prompt, contains('CLI mode'));
      expect(prompt, contains('File name: 2026-09-14-hoopis-backend-a.md'));
      expect(prompt, contains('Drive folder ID: folder1'));
      expect(
        prompt,
        contains('Result file: /repo/reports/.artifacts/a/drive_upload.json'),
      );
      expect(prompt, contains('Replace: no'));
      expect(prompt, contains('status "exists"'));
    });

    test('asks to replace the existing file when replace is true', () {
      final prompt = buildDriveUploadPrompt(
        readInstruction: 'Read x',
        reportPath: '/r/report.md',
        folderId: 'f',
        resultPath: '/r/result.json',
        replace: true,
      );

      expect(prompt, contains('Replace: yes'));
      expect(prompt, contains('move the old one to the trash'));
    });
  });
}
