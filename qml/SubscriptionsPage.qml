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

    Item {
        id: header
        z: 1
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: headerTitle.height + 24

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

        Text {
            id: headerTitle
            width: parent.width
            anchors.top: parent.top
            anchors.topMargin: 12
            text: qsTr("Subscriptions")
            font.pixelSize: 20
            color: platformStyle.colorNormalLight
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
    }

    ListView {
        id: subscriptionList
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 8
        anchors.bottomMargin: 16
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
                            width: parent.width
                            text: modelData.title
                            color: platformStyle.colorNormalLight
                            font.pixelSize: 18
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: modelData.feedId ? qsTr("Feed ID: %1").arg(modelData.feedId) : ""
                            color: "#93a3c4"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            visible: modelData.feedId
                        }
                    }
                }
            }

            Item {
                id: removeButton
                width: 32
                height: 32
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    width: 16
                    height: 16
                    anchors.centerIn: parent
                    source: "qrc:/qml/gfx/icon-trash.svg"
                    sourceSize.width: 16
                    sourceSize.height: 16
                    smooth: true
                    opacity: 0.7
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: storage.unsubscribe(modelData.feedId)
                }
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
