/// Pure, testable helpers for `somnio run --upload`: the project's Drive
/// folder prefs, the result file the upload step writes, and the CLI's own
/// check of that result against the local report.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Name of the shared reference every audit skill ships for the upload step.
const driveUploadRuleName = 'drive-upload';

/// MIME type a report must keep in Drive.
const reportMimeType = 'text/markdown';

final _folderUrlPattern = RegExp(r'/folders/([A-Za-z0-9_-]+)');
final _openUrlPattern = RegExp(r'[?&]id=([A-Za-z0-9_-]+)');
final _rawIdPattern = RegExp(r'^[A-Za-z0-9_-]{10,}$');

/// Extracts a Drive folder ID from a folder link
/// (`https://drive.google.com/drive/folders/<id>?usp=sharing`), an
/// `open?id=<id>` link, or a bare ID. Returns `null` when [input] is none of
/// those.
String? parseDriveFolderId(String input) {
  final value = input.trim();
  if (value.isEmpty) return null;
  final folder = _folderUrlPattern.firstMatch(value);
  if (folder != null) return folder.group(1);
  final open = _openUrlPattern.firstMatch(value);
  if (open != null) return open.group(1);
  return _rawIdPattern.hasMatch(value) ? value : null;
}

/// The folder link for a Drive folder ID.
String driveFolderUrl(String folderId) =>
    'https://drive.google.com/drive/folders/$folderId';

/// Path of the prefs file that remembers each project's Drive folder.
///
/// `SOMNIO_REPORTS_PREFS_PATH` overrides the default
/// `~/.somnio-reports-prefs.json`. The in-session upload reads the same file.
String reportPrefsPath({
  required String home,
  Map<String, String> environment = const {},
}) {
  final override = environment['SOMNIO_REPORTS_PREFS_PATH'];
  if (override != null && override.isNotEmpty) return override;
  return p.join(home, '.somnio-reports-prefs.json');
}

/// Reads the Drive folder ID saved for [project] in the prefs file at
/// [prefsPath], or `null` when there is none.
///
/// Throws a [FormatException] when the file is not a JSON object.
String? readProjectFolderId(String prefsPath, String project) {
  final folders = _readPrefs(prefsPath)['report_folders'];
  if (folders is! Map) return null;
  final entry = folders[project];
  if (entry is! Map) return null;
  final id = entry['folder_id'];
  return id is String && id.isNotEmpty ? id : null;
}

/// Saves [folderId] as [project]'s Drive folder in the prefs file at
/// [prefsPath], keeping every other key and project. Creates the file if
/// absent.
///
/// Throws a [FormatException] and leaves the file untouched when it is not a
/// JSON object.
void saveProjectFolderId(String prefsPath, String project, String folderId) {
  final prefs = _readPrefs(prefsPath);
  final folders = Map<String, dynamic>.from(
    prefs['report_folders'] is Map ? prefs['report_folders'] as Map : {},
  );
  folders[project] = {
    'folder_id': folderId,
    'folder_url': driveFolderUrl(folderId),
  };
  prefs['report_folders'] = folders;

  final file = File(prefsPath);
  file.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(prefs)}\n');
}

Map<String, dynamic> _readPrefs(String prefsPath) {
  final file = File(prefsPath);
  if (!file.existsSync()) return {};
  final contents = file.readAsStringSync();
  if (contents.trim().isEmpty) return {};
  final decoded = jsonDecode(contents);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('$prefsPath is not a JSON object');
  }
  return decoded;
}

/// Outcome the upload step reports in its result file.
enum DriveUploadStatus {
  /// The report was uploaded (the CLI still checks it).
  uploaded,

  /// A file with the report's name is already in the folder; nothing was
  /// uploaded.
  exists,

  /// The upload failed; see [DriveUploadResult.error].
  failed,

  /// The agent had no Google Drive MCP tools.
  noDriveMcp,
}

/// The JSON the upload step writes to its result file (see Step 5 of
/// `references/drive-upload.md`).
class DriveUploadResult {
  const DriveUploadResult({
    required this.status,
    this.fileId,
    this.title,
    this.mimeType,
    this.fileSize,
    this.parentId,
    this.existingFileId,
    this.error,
  });

  /// Parses the result JSON. Throws a [FormatException] when it is not a
  /// JSON object or its `status` is missing or unknown.
  factory DriveUploadResult.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('upload result is not a JSON object');
    }
    final status = switch (decoded['status']) {
      'uploaded' => DriveUploadStatus.uploaded,
      'exists' => DriveUploadStatus.exists,
      'failed' => DriveUploadStatus.failed,
      'no_drive_mcp' => DriveUploadStatus.noDriveMcp,
      final other => throw FormatException('unknown upload status: $other'),
    };
    final size = decoded['file_size'];
    return DriveUploadResult(
      status: status,
      fileId: decoded['file_id'] as String?,
      title: decoded['title'] as String?,
      mimeType: decoded['mime_type'] as String?,
      fileSize: size is int ? size : int.tryParse('${size ?? ''}'),
      parentId: decoded['parent_id'] as String?,
      existingFileId: decoded['existing_file_id'] as String?,
      error: decoded['error'] as String?,
    );
  }

  final DriveUploadStatus status;
  final String? fileId;
  final String? title;
  final String? mimeType;
  final int? fileSize;
  final String? parentId;
  final String? existingFileId;
  final String? error;
}

/// Checks an `uploaded` [result] against the local report at [reportPath]
/// and the expected [folderId], independently of what the upload step
/// concluded. Returns one line per failed check; empty when all pass.
List<String> verifyDriveUpload({
  required DriveUploadResult result,
  required String reportPath,
  required String folderId,
}) {
  final problems = <String>[];
  final name = p.basename(reportPath);
  final localSize = File(reportPath).lengthSync();

  if (result.fileId == null || result.fileId!.isEmpty) {
    problems.add('no file ID was reported');
  }
  if (result.title != name) {
    problems.add('name is "${result.title}", expected "$name"');
  }
  if (result.mimeType != reportMimeType) {
    problems.add(
      'type is "${result.mimeType}", expected "$reportMimeType" '
      '(it may have been converted to a Google Doc)',
    );
  }
  if (result.parentId != folderId) {
    problems.add('folder is "${result.parentId}", expected "$folderId"');
  }
  if (result.fileSize != localSize) {
    problems.add(
      'size is ${result.fileSize} bytes, expected $localSize '
      '(the content changed on the way)',
    );
  }
  return problems;
}

/// Builds the prompt for the upload step.
///
/// [readInstruction] is the agent's instruction to read
/// `references/drive-upload.md`. When [replace] is true, the existing file
/// with the report's name is replaced instead of reported as `exists`.
String buildDriveUploadPrompt({
  required String readInstruction,
  required String reportPath,
  required String folderId,
  required String resultPath,
  required bool replace,
}) {
  final name = p.basename(reportPath);
  return 'You are uploading an audit report to Google Drive in CLI mode.\n\n'
      '$readInstruction\n'
      'Follow every step for CLI mode. Never ask the user anything.\n\n'
      'Report: $reportPath\n'
      'File name: $name\n'
      'Drive folder ID: $folderId\n'
      'Result file: $resultPath\n'
      '${replace ? 'Replace: yes. A file named "$name" is already in the '
          'folder: upload the new one, verify it, then move the old one to '
          'the trash.\n' : 'Replace: no. If a file named "$name" is already in '
          'the folder, do not upload; report status "exists".\n'}'
      '\nIMPORTANT: You MUST write the result JSON to the result file above, '
      'even when the upload failed.';
}
