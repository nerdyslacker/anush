import QtQuick
import ".."

EwmhBackend {
    name: "openbox"
    profile: "openbox"

    function reloadWindowManager() {
        if (capabilities.reload !== true)
            return unsupported("reloadWindowManager")
        return runAction(["reload"])
    }

    function quitWindowManager() {
        if (capabilities.sessionControl !== true)
            return unsupported("quitWindowManager")
        return runAction(["quit"])
    }
}
