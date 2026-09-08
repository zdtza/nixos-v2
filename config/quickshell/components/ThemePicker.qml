// Theme picker: the same ImagePicker carousel the wallpaper picker uses, fed
// by the themes/ folder itself (one subfolder per theme, each with a
// preview.png -- see themes/default.nix). Accepting one shells out to
// scripts/select-theme.sh with the theme name, which owns the whole switch:
// rewriting theme.name in the host file, running `sw`, and the "Switching
// to ..." / failure notifications.
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import "../services"

ImagePicker {
    id: root

    ipcTarget: "theme"
    selectedValue: root.currentTheme

    // Theme.wallpaper is .../themes/<theme>/wallpapers/<file>, the shell's
    // only pointer into the repo, so both the theme list's folder and the
    // active theme come out of it -- no second hardcoded path. A wallpaper
    // still in /nix/store (theme.json predating home/quickshell.nix writing
    // repo paths) matches nothing, and the picker shows empty until `sw`.
    readonly property var repoMatch:
        String(Theme.wallpaper).match(/^(?:file:\/\/)?(.*\/themes)\/([^/]+)\/wallpapers\//)
    readonly property string themesDir: root.repoMatch ? root.repoMatch[1] : ""
    readonly property string currentTheme: root.repoMatch ? root.repoMatch[2] : ""

    // FolderListModel is a list model, not an array; re-read it into
    // ImagePicker's item shape whenever its count changes.
    items: {
        const entries = [];
        if (root.themesDir === "")
            return entries;
        const prefix = "file://" + root.themesDir + "/";
        for (let index = 0; index < folder.count; index++) {
            const name = String(folder.get(index, "fileName"));
            // Until Theme.wallpaper loads, themesDir is empty and an empty
            // FolderListModel.folder means the process CWD ($HOME) -- and the
            // model keeps serving those rows for a frame after folder changes.
            // Anything outside themesDir is that stale listing.
            if (!String(folder.get(index, "fileUrl")).startsWith(prefix))
                continue;
            entries.push({
                image: folder.get(index, "fileUrl") + "/preview.png",
                value: name
            });
        }
        return entries;
    }

    onAccepted: item => Quickshell.execDetached(["select-theme", item.value])

    FolderListModel {
        id: folder

        folder: root.themesDir === "" ? "" : "file://" + root.themesDir
        showDirs: true
        showFiles: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
    }
}
