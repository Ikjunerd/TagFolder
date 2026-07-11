# Tag Folder (Multi-Select Edition)

A lightweight Windows context-menu tool for tagging folders. Right-click one or more folders in File Explorer, choose **Tag Folder**, type a tag, and it is written into each folder's `desktop.ini` — visible in Explorer's **Tags** column.

This is an improved fork of the original **Tag_Folder.bat v1.1** by **Pinjoy** (pinjoy99@gmail.com):
- Original demo video: https://youtu.be/vyFhSdm4gD8

## What's improved over the original

| | Original (Pinjoy) | This version |
|---|---|---|
| How it's invoked | Open the folder, then right-click the folder **background** | Right-click the **selected folder(s)** directly |
| Multiple folders | Not supported | ✅ Select many folders, tag them all in **one dialog** |
| Existing tag | Not shown | ✅ Pre-filled in the textbox |
| Removing a tag | Manual | ✅ **Clear** button |
| Folder names with spaces / non-ASCII (e.g. Korean) | ⚠️ Unreliable | ✅ Fully supported (quoted `%1`, `-LiteralPath` throughout) |
| Implementation | Batch/PowerShell hybrid + VBScript | Pure PowerShell (`.ps1`) |

When multiple folders are selected, Explorer launches one script instance per folder. This version uses a **named mutex + shared temp file** so that all instances hand their paths to a single "master" instance, which shows one dialog and applies the tag to every selected folder.

## Files

| File | Description |
|---|---|
| `TagFolder.ps1` | Main script (GUI dialog, tag read/write, multi-select aggregation) |
| `TagFolder.reg` | Registers the **Tag Folder** context-menu entry |

## Installation

1. Copy `TagFolder.ps1` to `C:\user_data\` (or edit the path inside `TagFolder.reg` to match your location).
2. Double-click `TagFolder.reg` and confirm (administrator rights required — it writes to HKLM).
3. Restart Explorer (or sign out/in) so the multi-select settings take effect.

The `.reg` file registers:

- `Directory\shell\Tag Folder` — the context-menu verb for selected folders
- `"MultiSelectModel"="Document"` — invokes the verb for every selected item
- `MultipleInvokePromptMinimum` (HKCU, `100`) — raises Windows' default 15-item limit so the menu still appears with large selections

## Usage

1. Select one or more folders in File Explorer.
2. Right-click → **Tag Folder**.
3. A single dialog appears (showing the folder count when multiple are selected):
   - Type a tag and press **OK** → the tag is applied to all selected folders.
   - Press **Clear** (shown when any selected folder already has a tag) → tags are removed from all selected folders.
   - Press **Esc** or close the dialog → nothing is changed.
4. To see tags in Explorer, right-click the column header and enable the **Tags** column.

### Example

<img width="1556" height="676" alt="img1" src="https://github.com/user-attachments/assets/1e3a5c9a-f4c5-470c-8725-66b59ff6e312" />
<img width="1556" height="676" alt="img2" src="https://github.com/user-attachments/assets/e34db496-ede7-4aff-b831-66afc302f2d4" />
<img width="1556" height="676" alt="img3" src="https://github.com/user-attachments/assets/5a00ad99-f279-414e-bc64-b59c5bad1a09" />


## How it works

- The tag is stored in each folder's hidden `desktop.ini` under the property-store key:

  ```ini
  [{F29F85E0-4FF9-1068-AB91-08002B27B3D9}]
  Prop5=31,your-tag-here
  ```

  `Prop5` corresponds to `System.Keywords` (Tags), and the folder gets the *System* attribute so Explorer reads the `desktop.ini`.

- The updated `desktop.ini` is delivered via `Shell.Application.MoveHere`, which makes Explorer refresh the tag immediately without restarting.

- Multi-select handling: each launched instance appends its folder path to a temp list file; the first instance to acquire a named mutex becomes the master, waits until the list stops growing, then shows the dialog once and applies the result to all collected folders.

- Path robustness: the folder path is passed quoted (`"%1"`) from the registry and handled with `-LiteralPath` inside the script, so folder names containing **spaces, Korean/Unicode characters, or special characters** (e.g. `[brackets]`) work correctly — a common failure point of the original batch version, which relied on the current working directory.

## Uninstall

Delete these registry keys/values (via `regedit` or a removal `.reg`):

```
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Directory\shell\Tag Folder
HKEY_CLASSES_ROOT\Directory\Background\shell\Tag Folder
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer → MultipleInvokePromptMinimum
```

Tags already written remain in each folder's `desktop.ini`; use the **Clear** button beforehand if you want them removed.

## Notes & limitations

- Tested on Windows 10 / Windows 11 with Windows PowerShell 5.1.
- Save `TagFolder.ps1` as **UTF-8 with BOM** if you localize the strings (prevents garbled non-ASCII text in PowerShell 5.1).
- Tags in `desktop.ini` are folder metadata read by Explorer; they are not embedded in files and are not indexed the same way as file tags.

## Credits

- Original concept and v1.1 implementation: **Pinjoy** (2019) — https://youtu.be/vyFhSdm4gD8
- Multi-select support, existing-tag display, Clear button, pure-PowerShell rewrite: this fork

## License

MIT License (see `LICENSE`). The original author's credit above must be retained.
