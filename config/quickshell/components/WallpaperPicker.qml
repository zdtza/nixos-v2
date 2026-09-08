// Wallpaper picker: an ImagePicker fed by the active theme's wallpaper
// folder. Accepting one shells out to scripts/select-wallpaper.sh, which
// already owns both halves of a wallpaper switch -- persisting it into
// themes/<theme>/default.nix so it survives `sw`, and pushing it live into
// ~/.cache/quickshell/theme.json (watched by services/Theme.qml). Nothing
// about that flow is duplicated here.
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import "../services"

ImagePicker {
    id: root

    ipcTarget: "wallpaper"
    selectedValue: root.currentPath

    // Theme.wallpaper is the shell's only pointer at the active theme's
    // wallpaper folder (themes/<theme>/wallpapers) -- its own directory is
    // that folder, so the picker follows theme switches for free.
    readonly property string currentPath:
        decodeURIComponent(String(Theme.wallpaper).replace(/^file:\/\//, ""))
    readonly property string wallpaperDir: {
        const dir = String(Theme.wallpaper).replace(/\/[^/]*$/, "");
        // A wallpaper still pointing into /nix/store means theme.json predates
        // home/quickshell.nix writing repo paths -- listing the store's
        // contents would drag every image in it into the carousel, so show
        // nothing until the next `sw` rewrites the file.
        return dir.endsWith("/nix/store") ? "" : dir;
    }

    // FolderListModel is a plain list model, not an array; re-read it into
    // ImagePicker's item shape whenever its count changes.
    items: {
        const entries = [];
        if (root.wallpaperDir === "")
            return entries;
        // wallpaperDir is already a file:// URL (Theme.wallpaper is), so it
        // compares against fileUrl as-is.
        const prefix = root.wallpaperDir + "/";
        for (let index = 0; index < folder.count; index++) {
            // An empty FolderListModel.folder lists the process CWD ($HOME),
            // and the model still serves those rows for a frame after folder
            // changes -- drop anything outside the theme's wallpaper folder.
            if (!String(folder.get(index, "fileUrl")).startsWith(prefix))
                continue;
            entries.push({
                image: folder.get(index, "fileUrl"),
                value: String(folder.get(index, "filePath"))
            });
        }
        return entries;
    }

    onAccepted: item => Quickshell.execDetached(["select-wallpaper", item.value])

    FolderListModel {
        id: folder

        folder: root.wallpaperDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        showDirs: false
        sortField: FolderListModel.Name
    }
}
