import QtQuick 1.1
import com.nokia.symbian 1.1

PodinPageStackWindow {
    id: window
    showStatusBar: true
    showToolBar: true

    property string tlsStatus: qsTr("TLS check idle.")
    property bool tlsOk: true

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

    function openSearch() {
        var current = pageStack.currentPage;
        if (current && current.objectName === "SearchPage") {
            return;
        }
        pageStack.push(Qt.resolvedUrl("SearchPage.qml"), { tools: toolBarLayout, playback: playback });
    }

    function openSettings() {
        var current = pageStack.currentPage;
        if (current && current.objectName === "SettingsPage") {
            return;
        }
        pageStack.push(Qt.resolvedUrl("SettingsPage.qml"), { tools: toolBarLayout, playback: playback });
    }

    function openPlayer() {
        var current = pageStack.currentPage;
        if (current && current.objectName === "PlayerPage") {
            return;
        }
        pageStack.push(Qt.resolvedUrl("PlayerPage.qml"), { tools: toolBarLayout, playback: playback });
    }

    function showAbout() {
        aboutDialog.visible = true;
    }

    function hideAbout() {
        aboutDialog.visible = false;
    }

    function runTlsCheck() {
        tlsOk = true;
        tlsStatus = qsTr("Running TLS check...");
        tlsChecker.startCheck();
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
            iconSource: "qrc:/qml/gfx/icon-podcast.svg"
            onClicked: window.openSubscriptions()
        }
        ToolButton {
            flat: true
            iconSource: "qrc:/qml/gfx/icon-gramophone.svg"
            onClicked: window.openPlayer()
        }
        ToolButton {
            flat: true
            iconSource: "toolbar-menu"
            onClicked: appMenu.open()
        }
    }

    Menu {
        id: appMenu
        visualParent: window

        MenuLayout {
            MenuItem {
                text: qsTr("Search Podcast")
                onClicked: {
                    appMenu.close();
                    window.openSearch();
                }
            }
            MenuItem {
                text: qsTr("Settings")
                onClicked: {
                    appMenu.close();
                    window.openSettings();
                }
            }
            MenuItem {
                text: qsTr("About")
                onClicked: {
                    appMenu.close();
                    window.showAbout();
                }
            }
        }
    }

    Item {
        id: aboutDialog
        visible: false
        anchors.fill: parent
        z: 1000

        Rectangle {
            id: aboutScrim
            anchors.fill: parent
            color: "#99000000"
        }

        MouseArea {
            anchors.fill: aboutScrim
            onClicked: window.hideAbout()
        }

        Rectangle {
            id: aboutCard
            width: parent.width - 48
            height: 320
            radius: 10
            color: "#2b2b2b"
            border.color: "#4b4b4b"
            border.width: 1
            anchors.centerIn: parent
            z: 1

            MouseArea {
                anchors.fill: parent
            }

            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                spacing: 8

                Text {
                    width: parent.width
                    text: qsTr("Podin")
                    font.pixelSize: 20
                    color: platformStyle.colorNormalLight
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: "v" + appVersion
                    font.pixelSize: 16
                    color: "#cdd6ea"
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: qsTr("Copyright 2026, Liya Design.")
                    font.pixelSize: 14
                    color: "#aeb9d4"
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Button {
                    id: tlsButton
                    width: parent.width
                    text: tlsChecker.running ? qsTr("   Testing TLS...") : qsTr("   Test TLS 1.2")
                    enabled: !tlsChecker.running
                    onClicked: window.runTlsCheck()

                    Image {
                        source: "qrc:/qml/gfx/icon-link.svg"
                        width: 20
                        height: 20
                        smooth: true
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: (parent.width - 150) / 2
                        opacity: 0.8
                    }
                }

                Text {
                    width: parent.width
                    text: window.tlsStatus
                    color: window.tlsOk ? platformStyle.colorNormalLight : "#ffd6d9"
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Button {
                width: parent.width - 32
                text: qsTr("Close")
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                onClicked: window.hideAbout()
            }
        }
    }

    Connections {
        target: tlsChecker
        onFinished: {
            window.tlsOk = ok;
            window.tlsStatus = message;
        }
        onRunningChanged: {
            if (tlsChecker.running) {
                window.tlsOk = true;
                window.tlsStatus = qsTr("Running TLS check...");
            }
        }
    }

    PlaybackController {
        id: playback
    }

    initialPage: SubscriptionsPage {
        id: subscriptionsPage
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
