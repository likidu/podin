import QtQuick 1.1
import com.nokia.symbian 1.1

PodinPageStackWindow {
    id: window
    showStatusBar: true
    showToolBar: true

    function handleBack() {
        var current = pageStack.currentPage;
        if (pageStack.depth <= 1) {
            Qt.quit();
        } else {
            if (current && typeof current.stopPlayback === "function") {
                current.stopPlayback();
            }
            pageStack.pop();
        }
    }

    function openSubscriptions() {
        var current = pageStack.currentPage;
        if (current && current.objectName === "SubscriptionsPage") {
            return;
        }
        pageStack.push(Qt.resolvedUrl("SubscriptionsPage.qml"), { tools: toolBarLayout, playback: playback });
    }

    function openPlayer() {
        var current = pageStack.currentPage;
        if (current && current.objectName === "PlayerPage") {
            return;
        }
        pageStack.push(Qt.resolvedUrl("PlayerPage.qml"), { tools: toolBarLayout, playback: playback });
    }

    ToolBarLayout {
        id: toolBarLayout
        ToolButton {
            flat: true
            iconSource: "toolbar-back"
            onClicked: window.handleBack()
        }
        ToolButton {
            flat: true
            iconSource: "toolbar-settings"
            onClicked: window.openSubscriptions()
        }
        ToolButton {
            flat: true
            iconSource: "toolbar-next"
            onClicked: window.openPlayer()
        }
    }

    PlaybackController {
        id: playback
    }

    initialPage: MainPage {
        id: mainPage
        tools: toolBarLayout
        playback: playback
    }

    Keys.onReleased: {
        if (event.key === Qt.Key_Escape) {
            window.handleBack();
            event.accepted = true;
        }
    }
}
