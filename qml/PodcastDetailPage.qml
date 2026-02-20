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
    property string cachedArtworkPath: ""

    property string imageUrlHash: ""
    property bool hasArtwork: storage && storage.enableArtworkLoading &&
                              cachedArtworkPath && cachedArtworkPath.length > 0
    property string storageError: ""

    function stripHtml(html) {
        if (!html) return "";
        var s = html;
        s = s.replace(/<br\s*\/?>/gi, "\n");
        s = s.replace(/<\/p>/gi, "\n\n");
        s = s.replace(/<[^>]*>/g, "");
        s = s.replace(/&nbsp;/gi, " ");
        s = s.replace(/&amp;/gi, "&");
        s = s.replace(/&lt;/gi, "<");
        s = s.replace(/&gt;/gi, ">");
        s = s.replace(/&quot;/gi, '"');
        s = s.replace(/&#39;/gi, "'");
        s = s.replace(/\n{3,}/g, "\n\n");
        return s.replace(/^\s+|\s+$/g, "");
    }

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
        page.imageUrlHash = (detail.imageUrlHash && detail.imageUrlHash.length > 0)
            ? detail.imageUrlHash : page.imageUrlHash;
        page.podcastAuthor = detail.author ? detail.author : page.podcastAuthor;
        page.podcastUrl = detail.url ? detail.url : page.podcastUrl;
        page.resolveArtwork();
    }

    function resolveArtwork() {
        if (!storage || !storage.enableArtworkLoading) {
            page.cachedArtworkPath = "";
            return;
        }
        if (!artworkCache || page.feedId <= 0) {
            return;
        }
        var cached = artworkCache.cachedArtworkPath(page.feedId, page.podcastTitle);
        if (cached && cached.length > 0) {
            page.cachedArtworkPath = cached;
            return;
        }
        page.cachedArtworkPath = "";
        var artworkUrl = "";
        if (page.podcastGuid.length > 0 && page.imageUrlHash.length > 0) {
            artworkUrl = "https://podcastimage.liya.design/hash/"
                + page.imageUrlHash + "/feed/" + page.podcastGuid + "/128";
        } else if (page.podcastImage && page.podcastImage.toString().length > 0) {
            artworkUrl = page.podcastImage.toString();
        }
        if (artworkUrl.length > 0) {
            artworkCache.requestArtwork(page.feedId, page.podcastTitle, artworkUrl);
        }
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
        color: "#182239"
    }

    Rectangle {
        id: headerBar
        z: 3
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: headerTitle.height + 16
        color: "#141c2e"

        Text {
            id: headerTitle
            width: parent.width - 32
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            text: page.podcastTitle.length > 0 ? page.podcastTitle : qsTr("Podcast")
            color: platformStyle.colorNormalLight
            font.pixelSize: 22
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    Flickable {
        id: body
        anchors.top: headerBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: contentColumn.height + 24
        clip: true

        Column {
            id: contentColumn
            x: 16
            y: 16
            width: body.width - 32
            spacing: 12

            Rectangle {
                width: 140
                height: 140
                radius: 8
                color: "#1b2335"
                border.width: 1
                border.color: "#2f3a54"
                anchors.horizontalCenter: parent.horizontalCenter

                Image {
                    id: artworkImage
                    anchors.fill: parent
                    anchors.margins: 6
                    source: page.cachedArtworkPath.length > 0 ? page.cachedArtworkPath : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    cache: true
                    visible: page.hasArtwork
                    sourceSize.width: 128
                    sourceSize.height: 128
                    onStatusChanged: {
                        if (debugMode) {
                            console.log("Image status: " + status
                                + " (0=Null,1=Ready,2=Loading,3=Error)"
                                + " source=" + source);
                        }
                    }
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
                      ? page.stripHtml(page.podcastDescription)
                      : qsTr("No description available.")
                color: "#b7c4e0"
                font.pixelSize: 18
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

            Text {
                width: parent.width
                text: page.storageError
                visible: page.storageError.length > 0
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
                        page.storageError = "Storage not available or invalid feed ID";
                        return;
                    }
                    page.storageError = "";
                    if (page.subscribed) {
                        storage.unsubscribe(page.feedId);
                    } else {
                        storage.subscribe(page.feedId, page.podcastTitle, page.podcastImage.toString(),
                                          page.podcastGuid, page.imageUrlHash);
                    }
                    page.storageError = storage.lastError ? storage.lastError : "";
                    page.refreshSubscriptionState();
                }
            }

            // Debug section (hidden in release builds)
            Column {
                width: parent.width
                spacing: parent.spacing
                visible: debugMode
                height: debugMode ? childrenRect.height : 0

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#4b5f86"
                }

                Text {
                    width: parent.width
                    text: "Debug Info"
                    color: "#8899bb"
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    width: parent.width
                    text: "Storage: " + (storage ? "available" : "NOT AVAILABLE")
                    color: storage ? "#88ff88" : "#ff8888"
                    font.pixelSize: 14
                }

                Text {
                    width: parent.width
                    text: "DB Path: " + (storage ? storage.dbPath : "N/A")
                    color: "#b7c4e0"
                    font.pixelSize: 14
                    wrapMode: Text.WrapAnywhere
                }

                Text {
                    width: parent.width
                    text: "DB Status: " + (storage ? storage.dbStatus : "N/A")
                    color: "#b7c4e0"
                    font.pixelSize: 14
                    wrapMode: Text.WrapAnywhere
                }

                Text {
                    width: parent.width
                    text: "Path Log:\n" + (storage ? storage.dbPathLog : "N/A")
                    color: "#aabbcc"
                    font.pixelSize: 14
                    wrapMode: Text.WrapAnywhere
                }

                Text {
                    width: parent.width
                    text: "Subscriptions count: " + (storage && storage.subscriptions ? storage.subscriptions.length : 0)
                    color: "#b7c4e0"
                    font.pixelSize: 14
                }

                Text {
                    width: parent.width
                    text: "Feed ID: " + page.feedId + " | Subscribed: " + (page.subscribed ? "YES" : "NO")
                    color: "#b7c4e0"
                    font.pixelSize: 14
                }

                Text {
                    width: parent.width
                    text: "GUID: " + (page.podcastGuid ? page.podcastGuid : "(empty)")
                    color: "#b7c4e0"
                    font.pixelSize: 14
                    wrapMode: Text.WrapAnywhere
                }

                Text {
                    width: parent.width
                    text: "ImgHash: " + (page.imageUrlHash ? page.imageUrlHash : "(empty)")
                    color: "#b7c4e0"
                    font.pixelSize: 14
                }

                Text {
                    width: parent.width
                    text: "Artwork: " + (page.cachedArtworkPath ? page.cachedArtworkPath : "(none)")
                          + "\nImg status: " + artworkImage.status
                          + " | size: " + artworkImage.implicitWidth + "x" + artworkImage.implicitHeight
                          + " | painted: " + artworkImage.paintedWidth + "x" + artworkImage.paintedHeight
                          + "\nFile: " + (artworkCache.lastDebugInfo ? artworkCache.lastDebugInfo : "(no download yet)")
                    color: "#b7c4e0"
                    font.pixelSize: 14
                    wrapMode: Text.WrapAnywhere
                }

                Text {
                    width: parent.width
                    property string errText: storage && storage.lastError ? storage.lastError : ""
                    text: "Last Error: " + (errText.length > 0 ? errText : "(none)")
                    color: errText.length > 0 ? "#ff8888" : "#88ff88"
                    font.pixelSize: 14
                    wrapMode: Text.WrapAnywhere
                }
            }

            Item {
                width: parent.width
                height: 20
            }
        }
    }

    Component.onCompleted: {
        page.hasLoaded = true;
        requestPodcastIfReady();
        applyPodcastDetail(apiClient.podcastDetail);
        refreshSubscriptionState();
        page.resolveArtwork();
    }

    onFeedIdChanged: {
        if (page.hasLoaded) {
            requestPodcastIfReady();
        }
        refreshSubscriptionState();
        page.resolveArtwork();
    }

    onPodcastGuidChanged: {
        if (page.hasLoaded) {
            requestPodcastIfReady();
        }
    }

    onPodcastImageChanged: {
        if (page.hasLoaded) {
            page.resolveArtwork();
        }
    }

    Timer {
        id: cleanupTimer
        interval: 300
        repeat: false
        onTriggered: {
            page.podcastTitle = "";
            page.podcastDescription = "";
            page.podcastImage = "";
            page.podcastAuthor = "";
            page.podcastUrl = "";
            page.cachedArtworkPath = "";
            apiClient.clearPodcastDetail();
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Inactive) {
            cleanupTimer.restart();
        } else if (status === PageStatus.Active && page.hasLoaded) {
            cleanupTimer.stop();
            requestPodcastIfReady();
            refreshSubscriptionState();
            page.resolveArtwork();
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

    Connections {
        target: artworkCache
        onArtworkCached: {
            if (feedId === page.feedId) {
                page.cachedArtworkPath = path;
            }
        }
        onArtworkFailed: {
            if (feedId === page.feedId) {
                console.log("Artwork FAILED for feedId=" + feedId + ": " + message);
                page.storageError = "Artwork: " + message;
            }
        }
    }

    Connections {
        target: storage
        onEnableArtworkLoadingChanged: {
            page.resolveArtwork();
        }
        onLastErrorChanged: {
            page.storageError = storage.lastError ? storage.lastError : "";
        }
    }
}
