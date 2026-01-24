import QtQuick 1.1
import com.nokia.symbian 1.1

Page {
    id: page
    orientationLock: PageOrientation.LockPortrait

    property QtObject playback: null
    property int feedId: 0
    property string podcastGuid: ""
    property string podcastTitle: ""
    property string podcastDescription: ""
    property url podcastImage: ""
    property string podcastAuthor: ""
    property string podcastUrl: ""
    property bool hasLoaded: false
    property int lastRequestedFeedId: 0
    property string lastRequestedGuid: ""
    property bool subscribed: false

    property bool hasArtwork: podcastImage && podcastImage.toString().length > 0

    function requestPodcastIfReady() {
        if (page.feedId > 0) {
            if (page.feedId !== page.lastRequestedFeedId) {
                page.lastRequestedFeedId = page.feedId;
                page.lastRequestedGuid = "";
                apiClient.fetchPodcast(page.feedId);
            }
            return;
        }

        if (page.podcastGuid.length > 0 && page.podcastGuid !== page.lastRequestedGuid) {
            page.lastRequestedGuid = page.podcastGuid;
            page.lastRequestedFeedId = 0;
            apiClient.fetchPodcastByGuid(page.podcastGuid);
        }
    }

    function applyPodcastDetail(detail) {
        if (!detail) {
            return;
        }
        if (page.feedId > 0 && detail.feedId && detail.feedId !== page.feedId) {
            return;
        }
        if (page.podcastGuid.length > 0 && detail.guid && detail.guid !== page.podcastGuid) {
            return;
        }
        if (page.feedId <= 0 && detail.feedId) {
            page.lastRequestedFeedId = detail.feedId;
            page.feedId = detail.feedId;
        }
        if (page.podcastGuid.length === 0 && detail.guid) {
            page.podcastGuid = detail.guid;
        }
        page.podcastTitle = detail.title ? detail.title : page.podcastTitle;
        page.podcastDescription = detail.description ? detail.description : page.podcastDescription;
        page.podcastImage = detail.image ? detail.image : page.podcastImage;
        page.podcastAuthor = detail.author ? detail.author : page.podcastAuthor;
        page.podcastUrl = detail.url ? detail.url : page.podcastUrl;
    }

    function refreshSubscriptionState() {
        page.subscribed = storage && page.feedId > 0 ? storage.isSubscribed(page.feedId) : false;
    }

    function openEpisodes() {
        if (!pageStack || page.feedId <= 0) {
            return;
        }
        var params = {
            feedId: page.feedId,
            podcastTitle: page.podcastTitle,
            tools: page.tools,
            playback: page.playback
        };
        pageStack.push(Qt.resolvedUrl("EpisodesPage.qml"), params);
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#22304e" }
            GradientStop { position: 1.0; color: "#0f1524" }
        }
    }

    Flickable {
        id: body
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.height + 24
        clip: true

        Column {
            id: contentColumn
            x: 16
            y: 16
            width: body.width - 32
            spacing: 12

            Text {
                width: parent.width
                text: page.podcastTitle.length > 0 ? page.podcastTitle : qsTr("Podcast")
                color: platformStyle.colorNormalLight
                font.pixelSize: 22
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Rectangle {
                width: 140
                height: 140
                radius: 8
                color: "#1b2335"
                border.width: 1
                border.color: "#2f3a54"
                anchors.horizontalCenter: parent.horizontalCenter

                Image {
                    anchors.fill: parent
                    anchors.margins: 6
                    source: page.podcastImage
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: page.hasArtwork
                }

                Text {
                    anchors.centerIn: parent
                    text: qsTr("No artwork")
                    color: "#93a3c4"
                    font.pixelSize: 14
                    visible: !page.hasArtwork
                }
            }

            Text {
                width: parent.width
                text: page.podcastAuthor.length > 0 ? qsTr("By %1").arg(page.podcastAuthor) : ""
                color: "#b7c4e0"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                visible: page.podcastAuthor.length > 0
            }

            Text {
                width: parent.width
                text: page.feedId > 0 ? qsTr("Feed ID: %1").arg(page.feedId) : ""
                color: "#93a3c4"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                visible: page.feedId > 0
            }

            Text {
                width: parent.width
                text: page.podcastDescription.length > 0
                      ? page.podcastDescription
                      : qsTr("No description available.")
                color: "#b7c4e0"
                font.pixelSize: 15
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
            }

            Text {
                width: parent.width
                text: page.podcastUrl.length > 0 ? page.podcastUrl : ""
                color: "#93a3c4"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                visible: page.podcastUrl.length > 0
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
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }

            Button {
                width: parent.width
                text: qsTr("View Episodes")
                enabled: page.feedId > 0
                onClicked: page.openEpisodes()
            }

            Button {
                width: parent.width
                text: page.subscribed ? qsTr("Unsubscribe") : qsTr("Subscribe")
                enabled: page.feedId > 0
                onClicked: {
                    if (!storage || page.feedId <= 0) {
                        return;
                    }
                    if (page.subscribed) {
                        storage.unsubscribe(page.feedId);
                    } else {
                        storage.subscribe(page.feedId, page.podcastTitle, page.podcastImage.toString());
                    }
                    page.refreshSubscriptionState();
                }
            }
        }
    }

    Component.onCompleted: {
        page.hasLoaded = true;
        requestPodcastIfReady();
        applyPodcastDetail(apiClient.podcastDetail);
        refreshSubscriptionState();
    }

    onFeedIdChanged: {
        if (page.hasLoaded) {
            requestPodcastIfReady();
        }
        refreshSubscriptionState();
    }

    onPodcastGuidChanged: {
        if (page.hasLoaded) {
            requestPodcastIfReady();
        }
    }

    Connections {
        target: apiClient
        onPodcastDetailChanged: {
            page.applyPodcastDetail(apiClient.podcastDetail);
            page.refreshSubscriptionState();
        }
    }

    Connections {
        target: storage
        onSubscriptionsChanged: page.refreshSubscriptionState()
    }
}
