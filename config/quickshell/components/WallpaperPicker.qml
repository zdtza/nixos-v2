// Wallpaper picker: an ImagePicker fed by the active theme's wallpaper folder.
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import "../services"

ImagePicker {
    id: root

    ipcTarget: "wallpaper"
    selectedValue: root.currentPath
    showCaption: true
    filterable: true

    // Theme.wallpaper is the shell's only pointer at the active theme's wallpaper folder.
    readonly property string currentPath:
        decodeURIComponent(String(Theme.wallpaper).replace(/^file:\/\//, ""))
    readonly property string wallpaperDir: {
        const dir = String(Theme.wallpaper).replace(/\/[^/]*$/, "");
        // A wallpaper still pointing into /nix/store means theme.json predates home/quickshell.nix writing repo paths.
        return dir.endsWith("/nix/store") ? "" : dir;
    }

    // FolderListModel is a plain list model, not an array; re-read it into ImagePicker's item shape whenever its count changes.
    items: {
        const entries = [];
        if (root.wallpaperDir === "")
            return entries;
        // wallpaperDir is already a file:// URL (Theme.wallpaper is), so it compares against fileUrl as-is.
        const prefix = root.wallpaperDir + "/";
        for (let index = 0; index < folder.count; index++) {
            // An empty FolderListModel.folder lists the process CWD ($HOME), and the model still serves those rows for a frame after folder changes.
            if (!String(folder.get(index, "fileUrl")).startsWith(prefix))
                continue;
            const fileName = String(folder.get(index, "fileName"));
            // Turn "01-cherry-blossom.jpg" into "cherry-blossom".
            const name = fileName.replace(/\.[^.]+$/, "")
                .replace(/^\d+[-_ ]+/, "")
                .replace(/[_ ]+/g, "-");
            entries.push({
                image: folder.get(index, "fileUrl"),
                value: String(folder.get(index, "filePath")),
                name: name
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
