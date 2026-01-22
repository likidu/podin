import QtQuick 1.1
import com.nokia.symbian 1.1

Page {
    id: page
    orientationLock: PageOrientation.LockPortrait

    property bool hasSearched: false
    property string tlsStatus: qsTr("TLS check idle.")
    property bool tlsOk: true

    signal requestEpisodes(int feedId, string title)

    Rectangle {
        id: background
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#2f3f6d" }
            GradientStop { position: 1.0; color: "#12192b" }
        }
    }

    function startSearch() {
        page.hasSearched = true;
        apiClient.search(searchField.text);
    }

    Column {
        id: header
        z: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 16
        spacing: 12
        width: parent.width - 32

        Text {
            width: parent.width
            text: qsTr("Podcast Index")
            font.pixelSize: 22
            color: platformStyle.colorNormalLight
            horizontalAlignment: Text.AlignHCenter
        }

        TextField {
            id: searchField
            width: parent.width
            text: qsTr("news")
            placeholderText: qsTr("Search podcasts")
            inputMethodHints: Qt.ImhNoPredictiveText
            Keys.onReturnPressed: page.startSearch()
        }

        Button {
            id: searchButton
            width: parent.width
            text: apiClient.busy ? qsTr("Searching...") : qsTr("Search")
            enabled: !apiClient.busy
            onClicked: page.startSearch()
        }

        Button {
            id: tlsButton
            width: parent.width
            text: tlsChecker.running ? qsTr("Testing TLS...") : qsTr("Test TLS 1.2")
            enabled: !tlsChecker.running
            onClicked: {
                page.tlsOk = true;
                page.tlsStatus = qsTr("Running TLS check...");
                tlsChecker.startCheck();
            }
        }

        BusyIndicator {
            running: apiClient.busy
            visible: apiClient.busy
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            width: parent.width
            text: apiClient.errorMessage
            visible: apiClient.errorMessage.length > 0
            color: "#ffd6d9"
            font.pixelSize: 16
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            width: parent.width
            text: page.tlsStatus
            color: page.tlsOk ? platformStyle.colorNormalLight : "#ffd6d9"
            font.pixelSize: 16
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    ListView {
        id: podcastList
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        spacing: 8
        model: apiClient.podcasts

        delegate: Rectangle {
            width: podcastList.width
            height: 72
            radius: 6
            color: index % 2 === 0 ? "#1a2233" : "#1f2a3d"

            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 12

                Rectangle {
                    width: 48
                    height: 48
                    radius: 4
                    color: "#2b354a"
                    border.width: 1
                    border.color: "#3b4660"

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: modelData.image
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                }

                Column {
                    width: parent.width - 70
                    spacing: 4

                    Text {
                        text: modelData.title
                        color: platformStyle.colorNormalLight
                        font.pixelSize: 18
                        elide: Text.ElideRight
                    }

                    Text {
                        text: modelData.description ? modelData.description : ""
                        color: "#b7c4e0"
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: page.requestEpisodes(modelData.feedId, modelData.title)
            }
        }
    }

    Text {
        anchors.centerIn: podcastList
        text: qsTr("No results.")
        color: platformStyle.colorNormalLight
        font.pixelSize: 18
        visible: page.hasSearched && !apiClient.busy && apiClient.podcasts.length === 0 && apiClient.errorMessage.length === 0
    }

    Connections {
        target: tlsChecker
        onFinished: {
            page.tlsOk = ok;
            page.tlsStatus = message;
        }
        onRunningChanged: {
            if (tlsChecker.running) {
                page.tlsOk = true;
                page.tlsStatus = qsTr("Running TLS check...");
            }
        }
    }
}
