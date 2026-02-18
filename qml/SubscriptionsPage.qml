import QtQuick 1.1
import com.nokia.symbian 1.1

Page {
    id: page
    objectName: "SubscriptionsPage"
    orientationLock: PageOrientation.LockPortrait

    property bool hasLoaded: false
    property QtObject playback: null

    function proxyImageUrl(item) {
        if (item.guid && item.imageUrlHash) {
            return "https://podcastimage.liya.design/hash/"
                + item.imageUrlHash + "/feed/" + item.guid + "/32";
        }
        return item.image ? item.image : "";
    }

    function openPodcastDetail(feedId, title, image, guid, imageUrlHash) {
        if (!pageStack) {
            return;
        }
        var params = {
            feedId: feedId,
            podcastTitle: title,
            podcastImage: image ? image : "",
            podcastGuid: guid ? guid : "",
            imageUrlHash: imageUrlHash ? imageUrlHash : "",
            tools: page.tools,
            playback: page.playback
        };
        pageStack.push(Qt.resolvedUrl("PodcastDetailPage.qml"), params);
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1f2a43" }
            GradientStop { position: 1.0; color: "#0f1524" }
        }
    }

    Column {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 12
        spacing: 8

        Text {
            width: parent.width
            text: qsTr("Subscriptions")
            font.pixelSize: 20
            color: platformStyle.colorNormalLight
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }

        MemoryBar {
            width: parent.width
            monitor: memoryMonitor
        }
    }

    ListView {
        id: subscriptionList
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        spacing: 8
        model: storage.subscriptions

        delegate: Rectangle {
            width: subscriptionList.width
            height: 72
            radius: 6
            color: index % 2 === 0 ? "#1b2335" : "#202a3f"

            Item {
                id: contentArea
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: removeButton.left
                anchors.margins: 8

                Row {
                    anchors.fill: parent
                    spacing: 8

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
                            source: storage && storage.enableArtworkLoading ? page.proxyImageUrl(modelData) : ""
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                            cache: false
                            sourceSize.width: 44
                            sourceSize.height: 44
                            visible: storage && storage.enableArtworkLoading && source.toString().length > 0
                        }
                    }

                    Column {
                        width: parent.width - 60
                        spacing: 4

                        Text {
                            text: modelData.title
                            color: platformStyle.colorNormalLight
                            font.pixelSize: 18
                            elide: Text.ElideRight
                        }

                        Text {
                            text: modelData.feedId ? qsTr("Feed ID: %1").arg(modelData.feedId) : ""
                            color: "#93a3c4"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            visible: modelData.feedId
                        }
                    }
                }
            }

            Button {
                id: removeButton
                width: 70
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Remove")
                onClicked: storage.unsubscribe(modelData.feedId)
            }

            MouseArea {
                anchors.fill: contentArea
                onClicked: page.openPodcastDetail(modelData.feedId, modelData.title, modelData.image, modelData.guid, modelData.imageUrlHash)
            }
        }
    }

    Text {
        anchors.centerIn: subscriptionList
        text: qsTr("No subscriptions yet.")
        color: platformStyle.colorNormalLight
        font.pixelSize: 18
        visible: storage.subscriptions.length === 0
    }

    Component.onCompleted: {
        page.hasLoaded = true;
        storage.refreshSubscriptions();
    }

    onStatusChanged: {
        if (status === PageStatus.Active && page.hasLoaded) {
            storage.refreshSubscriptions();
        }
    }
}
