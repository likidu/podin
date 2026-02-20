import QtQuick 1.1
import com.nokia.symbian 1.1

Page {
    id: page
    orientationLock: PageOrientation.LockPortrait

    property int feedId: 0
    property string podcastTitle: ""
    property QtObject playback: null
    property bool hasLoaded: false
    property int lastRequestedFeedId: 0
    property string nowPlayingTitle: playback && playback.episodeTitle ? playback.episodeTitle : ""
    property string nowPlayingMeta: ""
    property url nowPlayingUrl: playback && playback.streamUrl ? playback.streamUrl : ""
    property string nowPlayingEnclosureType: playback && playback.enclosureType ? playback.enclosureType : ""
    property string nowPlayingEpisodeTitle: playback && playback.episodeTitle ? playback.episodeTitle : ""
    property string nowPlayingEpisodeId: playback && playback.episodeId ? playback.episodeId : ""

    function mediaLabelFor(url, enclosureType) {
        var type = enclosureType ? enclosureType.toString().toLowerCase() : "";
        if (type.indexOf("audio/mpeg") !== -1 || type.indexOf("audio/mp3") !== -1) {
            return "mp3";
        }
        if (type.indexOf("audio/mp4") !== -1 || type.indexOf("audio/m4a") !== -1 || type.indexOf("audio/aac") !== -1) {
            return "m4a";
        }
        var urlString = url ? (url.toString ? url.toString() : url) : "";
        var path = urlString.split("?")[0];
        var dot = path.lastIndexOf(".");
        if (dot !== -1) {
            var ext = path.slice(dot + 1).toLowerCase();
            if (ext === "mp3") {
                return "mp3";
            }
            if (ext === "m4a" || ext === "mp4" || ext === "aac") {
                return "m4a";
            }
            if (ext.length > 0 && ext.length <= 5) {
                return ext;
            }
        }
        return "unknown";
    }

    function formatDuration(seconds) {
        if (!seconds || seconds < 0) {
            return "0:00";
        }
        var minutes = Math.floor(seconds / 60);
        var remaining = Math.floor(seconds % 60);
        return minutes + ":" + (remaining < 10 ? "0" + remaining : remaining);
    }

    function formatDate(epoch) {
        if (!epoch || epoch <= 0) {
            return "";
        }
        var date = new Date(epoch * 1000);
        var month = date.getMonth() + 1;
        var day = date.getDate();
        return date.getFullYear() + "-" +
                (month < 10 ? "0" + month : month) + "-" +
                (day < 10 ? "0" + day : day);
    }

    function openPlayerForItem(url, title, enclosureType, datePublished, durationSeconds, episodeId, description) {
        var urlString = url ? (url.toString ? url.toString() : url) : "";
        if (urlString.length === 0) {
            return;
        }
        if (!pageStack) {
            return;
        }
        apiClient.clearEpisodes();
        var epId = episodeId ? episodeId.toString() : "";
        var epTitle = title || "";
        var encType = enclosureType || "";
        var metaParts = [];
        var metaDate = formatDate(datePublished);
        var metaDuration = formatDuration(durationSeconds);
        var metaType = mediaLabelFor(url, encType);
        if (metaDate.length > 0) {
            metaParts.push(metaDate);
        }
        if (metaDuration.length > 0) {
            metaParts.push(metaDuration);
        }
        if (metaType.length > 0) {
            metaParts.push(metaType);
        }
        page.nowPlayingMeta = metaParts.join(" • ");
        var params = {
            tools: page.tools,
            playback: page.playback,
            viewedUrl: urlString,
            viewedEpisodeId: epId,
            viewedFeedId: page.feedId,
            viewedTitle: epTitle,
            viewedPodcastTitle: page.podcastTitle,
            viewedEnclosureType: encType,
            viewedDescription: description || ""
        };
        pageStack.replace(Qt.resolvedUrl("PlayerPage.qml"), params, true);
    }

    function openNowPlaying() {
        if (!pageStack) {
            return;
        }
        if (!page.nowPlayingUrl || page.nowPlayingUrl.toString().length === 0) {
            return;
        }
        var params = {
            tools: page.tools,
            playback: page.playback
        };
        pageStack.push(Qt.resolvedUrl("PlayerPage.qml"), params);
    }

    function requestEpisodesIfReady() {
        if (page.feedId > 0 && page.feedId !== page.lastRequestedFeedId) {
            page.lastRequestedFeedId = page.feedId;
            apiClient.fetchEpisodes(page.feedId);
        }
    }

    Component.onCompleted: {
        page.hasLoaded = true;
        requestEpisodesIfReady();
    }


    onFeedIdChanged: {
        if (page.hasLoaded) {
            requestEpisodesIfReady();
        }
    }

    Timer {
        id: cleanupTimer
        interval: 300
        repeat: false
        onTriggered: {
            page.lastRequestedFeedId = 0;
            apiClient.clearEpisodes();
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Inactive) {
            cleanupTimer.restart();
        } else if (status === PageStatus.Active && page.hasLoaded) {
            cleanupTimer.stop();
            requestEpisodesIfReady();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#181f33"
    }

    Rectangle {
        id: headerBar
        z: 3
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: headerContent.height + 16
        color: "#141c2e"

        Column {
            id: headerContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 8
            spacing: 6

            Text {
                width: parent.width
                text: page.podcastTitle.length > 0 ? page.podcastTitle : qsTr("Episodes")
                font.pixelSize: 20
                color: platformStyle.colorNormalLight
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
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

    Rectangle {
        id: nowPlayingBanner
        z: 2
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 16
        anchors.bottomMargin: 0
        width: parent.width - 32
        height: page.nowPlayingTitle.length > 0 ? 70 : 0
        radius: 10
        border.width: 1
        border.color: "#2a3852"
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a2436" }
            GradientStop { position: 1.0; color: "#0f1526" }
        }
        visible: height > 0

        MouseArea {
            anchors.fill: parent
            onClicked: page.openNowPlaying()
        }

        Rectangle {
            width: 4
            height: parent.height - 16
            radius: 2
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            color: "#5a7cff"
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            anchors.leftMargin: 24
            spacing: 2

            Text {
                width: parent.width
                text: qsTr("Now playing")
                color: "#9fb0d3"
                font.pixelSize: 12
                font.capitalization: Font.AllUppercase
            }

            Text {
                width: parent.width
                text: page.nowPlayingTitle
                color: platformStyle.colorNormalLight
                font.pixelSize: 15
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: page.nowPlayingMeta
                color: "#93a3c4"
                font.pixelSize: 12
                elide: Text.ElideRight
                visible: page.nowPlayingMeta.length > 0
            }
        }
    }

    ListView {
        id: episodeList
        z: 1
        anchors.top: headerBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        anchors.bottomMargin: page.nowPlayingTitle.length > 0
                               ? nowPlayingBanner.height
                               : 0
        spacing: 8
        model: apiClient.episodes

        delegate: Rectangle {
            width: episodeList.width
            height: episodeContent.height + 16
            radius: 6
            color: index % 2 === 0 ? "#1b2335" : "#202a3f"
            opacity: modelData.enclosureUrl && modelData.enclosureUrl.length > 0 ? 1.0 : 0.6

            Column {
                id: episodeContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 4

                Text {
                    width: parent.width
                    text: modelData.title
                    color: platformStyle.colorNormalLight
                    font.pixelSize: 17
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: formatDate(modelData.datePublished) + "  " + formatDuration(modelData.duration) + "  " +
                          mediaLabelFor(modelData.enclosureUrl, modelData.enclosureType)
                    color: "#b7c4e0"
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: page.openPlayerForItem(modelData.enclosureUrl,
                                                  modelData.title,
                                                  modelData.enclosureType,
                                                  modelData.datePublished,
                                                  modelData.duration,
                                                  modelData.id,
                                                  modelData.description)
            }
        }
    }

    Text {
        anchors.centerIn: episodeList
        text: qsTr("No episodes.")
        color: platformStyle.colorNormalLight
        font.pixelSize: 18
        visible: page.hasLoaded && !apiClient.busy && apiClient.episodes.length === 0 && apiClient.errorMessage.length === 0
    }

}
