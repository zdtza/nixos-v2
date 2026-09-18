// Theme picker: the same ImagePicker carousel the wallpaper picker uses, fed by the themes/ folder itself.
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import "../services"

ImagePicker {
    id: root

    ipcTarget: "theme"
    selectedValue: root.currentTheme
    // The value *is* the themes/ folder name, so the caption names the theme and typing filters on it.
    showCaption: true
    filterable: true
    // There are only a few dozen previews.
    preloadAll: true

    // Derive the themes directory from the active wallpaper path.
    readonly property var repoMatch:
        String(Theme.wallpaper).match(/^(?:file:\/\/)?(.*\/themes)\/([^/]+)\/wallpapers\//)
    readonly property string themesDir: root.repoMatch ? root.repoMatch[1] : ""
    readonly property string currentTheme: root.repoMatch ? root.repoMatch[2] : ""

    // FolderListModel is a list model, not an array; re-read it into ImagePicker's item shape whenever its count changes.
    items: {
        const entries = [];
        if (root.themesDir === "")
            return entries;
        const prefix = "file://" + root.themesDir + "/";
        for (let index = 0; index < folder.count; index++) {
            const name = String(folder.get(index, "fileName"));
            // Until Theme.wallpaper loads, themesDir is empty and an empty FolderListModel.folder means the process CWD ($HOME)
            if (!String(folder.get(index, "fileUrl")).startsWith(prefix))
                continue;
            entries.push({
                image: folder.get(index, "fileUrl") + "/preview.png",
                value: name
            });
        }
        return entries;
    }

    onAccepted: item => Quickshell.execDetached(["select-theme", "--background", item.value])

    FolderListModel {
        id: folder

        folder: root.themesDir === "" ? "" : "file://" + root.themesDir
        showDirs: true
        showFiles: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
    }
}
