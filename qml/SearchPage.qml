import QtQuick 1.1
import com.nokia.symbian 1.1

Page {
    id: page
    objectName: "SearchPage"
    orientationLock: PageOrientation.LockPortrait

    property QtObject playback: null
    property bool hasSearched: false

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

    function openPodcastDetails(podcast) {
        if (!pageStack || !podcast) {
            return;
        }
        var params = {
            feedId: podcast.feedId,
            podcastGuid: podcast.guid ? podcast.guid : "",
            podcastTitle: podcast.title ? podcast.title : "",
            podcastDescription: podcast.description ? podcast.description : "",
            podcastImage: podcast.image ? podcast.image : "",
            tools: page.tools,
            playback: page.playback
        };
        pageStack.push(Qt.resolvedUrl("PodcastDetailPage.qml"), params);
    }

    Item {
        id: headerBar
        z: 1
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: headerContent.height + 24

        Rectangle {
            anchors.fill: parent
            color: "#1a2236"
            opacity: 0.95
        }

        Rectangle {
            width: parent.width
            height: 1
            anchors.bottom: parent.bottom
            color: "#2d3a57"
        }

        Column {
            id: headerContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 10

            Text {
                width: parent.width
                text: qsTr("Podcast Index")
                font.pixelSize: 22
                color: platformStyle.colorNormalLight
                horizontalAlignment: Text.AlignHCenter
            }

            Row {
                width: parent.width
                spacing: 6

                TextField {
                    id: searchField
                    width: parent.width - clearButton.width - 6
                    text: qsTr("news")
                    placeholderText: qsTr("Search podcasts")
                    inputMethodHints: Qt.ImhNoPredictiveText
                    Keys.onReturnPressed: page.startSearch()
                }

                Button {
                    id: clearButton
                    width: 32
                    height: searchField.height
                    text: qsTr("x")
                    enabled: searchField.text.length > 0
                    onClicked: searchField.text = ""
                }
            }

            Button {
                id: searchButton
                width: parent.width
                text: apiClient.busy ? qsTr("Searching...") : qsTr("Search")
                enabled: !apiClient.busy
                onClicked: page.startSearch()
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
        }
    }

    ListView {
        id: podcastList
        anchors.top: headerBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 8
        anchors.bottomMargin: 16
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
                onClicked: page.openPodcastDetails(modelData)
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
}
