import QtQuick 1.1
import com.nokia.symbian 1.1

PageStackWindow {
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

    ToolBarLayout {
        id: toolBarLayout
        ToolButton {
            flat: true
            iconSource: "toolbar-back"
            onClicked: window.handleBack()
        }
    }

    initialPage: MainPage {
        id: mainPage
        tools: toolBarLayout
        onRequestPlayer: {
            var params = { tools: toolBarLayout };
            window.pageStack.push(Qt.resolvedUrl("PlayerPage.qml"), params);
        }
    }

    Keys.onReleased: {
        if (event.key === Qt.Key_Escape) {
            window.handleBack();
            event.accepted = true;
        }
    }
}
