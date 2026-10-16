# Drive Upload

Uploads this audit's report to the project's shared Google Drive folder through the Google Drive MCP. It runs **only when the user asked for the upload**: an `upload` argument, a request such as "and upload it to Drive", or `somnio run <audit> --upload`. Never upload a report the user did not ask to upload.

The report feeds an internal pipeline that parses it, so the file in Drive must be **byte-for-byte identical** to the local file.

> This file is shared by every audit skill. Edit the source in `shared/references/drive-upload.md` and copy it to each skill's `references/`; a test fails when a copy drifts.

---

## Rules

- Upload only the report this audit wrote: `reports/YYYY-MM-DD-<project>-<skill-name>.md`. Never upload `reports/.artifacts/`, `reports/.history/` or `.json` exports
- Upload the `.md` **exactly as written**: same file name, same content, nothing added, removed or reformatted. Never edit the Report Metadata block
- **Never** convert it to Google Docs or any other format
- Upload it **flat** into the project's folder: no subfolders, no dated folders
- Never report a file as uploaded unless it passed every check in Step 4

---

## Step 1: Check the Google Drive MCP

You need Google Drive MCP tools that create a file (with a parent folder, a content MIME type and an option to disable conversion to Google types, for example `create_file` with `parentId`, `contentMimeType` and `disableConversionToGoogleType`), search files, read file metadata and move a file to the trash. If they are deferred, load them first (for example with ToolSearch).

If they are not available, do not upload and do not try another method:
- **In session:** tell the user to connect the Google Drive connector (in Claude: Settings → Connectors → Google Drive) and ask again, or to upload the file by hand by dragging it into the project's Drive folder without opening or converting it.
- **CLI mode:** write the result file with `"status": "no_drive_mcp"` (see Step 5).

---

## Step 2: Resolve the project's Drive folder

Each project has one fixed reports folder, given by the EM.

- **CLI mode:** the prompt gives you the folder ID. Use it as is.
- **In session:** read the prefs file:
  ```bash
  cat "${SOMNIO_REPORTS_PREFS_PATH:-$HOME/.somnio-reports-prefs.json}" 2>/dev/null
  ```
  ```json
  {
    "report_folders": {
      "<project>": {
        "folder_id": "<folder_id>",
        "folder_url": "https://drive.google.com/drive/folders/<folder_id>"
      }
    }
  }
  ```
  `<project>` is the project slug in the report file name (`2026-09-14-hoopis-backend-security-audit.md` → `hoopis-backend`). If it has no entry, ask the user for the folder link, take the ID from `https://drive.google.com/drive/folders/<folder_id>`, confirm the folder exists with the metadata tool, and offer to save it. When saving, **merge** the entry into the file; never replace the whole file. `somnio run --upload` reads the same file.

---

## Step 3: Check for an existing file, then upload

1. Search the folder for a file with the exact same name:
   ```
   parentId = '<folder_id>' and title = '<file name>'
   ```
   A match means the audit already ran and was uploaded today.
   - **In session:** ask the user whether to replace it or skip it.
   - **CLI mode:** if the prompt does not say to replace, do not upload; write the result with `"status": "exists"` and the existing file's ID. If it says to replace, continue.
2. Get the local file's exact size in bytes:
   ```bash
   wc -c < "<report path>"
   ```
3. Create the file with:
   - `title`: the file name, unchanged
   - `parentId`: the folder ID
   - `contentMimeType`: `text/markdown`
   - `disableConversionToGoogleType`: `true` (**required**: without it Drive converts the report to a Google Doc)
   - `textContent`: the report, **verbatim**, from the first byte to the last, including the Report Metadata block and the trailing newline

---

## Step 4: Verify

Read the uploaded file's metadata and check all of these:

- `title` equals the local file name
- `mimeType` is `text/markdown` (not `application/vnd.google-apps.document`)
- `parentId` is the folder ID
- `fileSize` equals the local byte count from Step 3

If any check fails, move the uploaded file to the trash, upload it **once** more, and verify again. If it fails a second time, move it to the trash and report which check failed.

When replacing, move the old file to the trash **only after** the new one passed every check.

---

## Step 5: Report the result

- **In session:** reply with one line, then the folder link:
  ```
  ✓ Uploaded 2026-09-14-hoopis-backend-security-audit.md (23,753 bytes)
  Folder: https://drive.google.com/drive/folders/<folder_id>
  ```
- **CLI mode:** write this JSON to the result path the prompt gives you, and nothing else:
  ```json
  {
    "status": "uploaded",
    "file_id": "<id of the uploaded file>",
    "title": "<title from the metadata>",
    "mime_type": "<mimeType from the metadata>",
    "file_size": 23753,
    "parent_id": "<parentId from the metadata>",
    "existing_file_id": null,
    "error": null
  }
  ```
  `status` is one of `uploaded`, `exists`, `failed` or `no_drive_mcp`. Copy `title`, `mime_type`, `file_size` and `parent_id` from the Drive metadata, not from the local file: the CLI compares them with the local file itself. On `exists`, set `existing_file_id`. On `failed` or `no_drive_mcp`, explain why in `error`.
