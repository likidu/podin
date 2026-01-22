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
        onRequestEpisodes: {
            var params = { feedId: feedId, podcastTitle: title, tools: toolBarLayout };
            window.pageStack.push(Qt.resolvedUrl("EpisodesPage.qml"), params);
        }
    }

    Keys.onReleased: {
        if (event.key === Qt.Key_Escape) {
            window.handleBack();
            event.accepted = true;
        }
    }
}
