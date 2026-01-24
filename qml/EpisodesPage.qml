import QtQuick 1.1
import com.nokia.symbian 1.1

Page {
    id: page
    orientationLock: PageOrientation.LockPortrait

    property int feedId: 0
    property string podcastTitle: ""
    property string currentTitle: ""
    property string currentEnclosureType: ""
    property url streamUrl: ""
    property bool isPlaying: false
    property bool hasLoaded: false
    property int lastRequestedFeedId: 0
    property string statusMessage: qsTr("Select an episode to play.")

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

    function updateStatus(note) {
        var stateText = audio.state === audio.playingState ? qsTr("Playing")
                        : audio.state === audio.pausedState ? qsTr("Paused")
                        : qsTr("Stopped");
        var position = formatDuration(audio.position / 1000);
        var duration = formatDuration(audio.duration / 1000);
        var base = stateText + " " + position + " / " + duration;
        if (note && note.length > 0) {
            base = note + "\n" + base;
        }
        page.statusMessage = base;
    }

    function startPlayback(url, title, enclosureType) {
        var urlString = url ? (url.toString ? url.toString() : url) : "";
        if (urlString.length === 0) {
            updateStatus(qsTr("No audio URL available."));
            return;
        }
        audio.ensureImpl();
        if (!audio.available) {
            updateStatus(qsTr("Audio playback unavailable in this runtime."));
            return;
        }
        page.streamUrl = urlString;
        page.currentTitle = title || "";
        page.currentEnclosureType = enclosureType || "";
        audio.play();
        updateStatus(qsTr("Loading..."));
    }

    function togglePlayback() {
        audio.ensureImpl();
        if (!audio.available) {
            updateStatus(qsTr("Audio playback unavailable in this runtime."));
            return;
        }
        if (audio.state === audio.playingState) {
            audio.pause();
        } else if (page.streamUrl && page.streamUrl.toString().length > 0) {
            audio.play();
        } else {
            updateStatus(qsTr("Select an episode to play."));
        }
    }

    function stopPlayback() {
        audio.stop();
        updateStatus(qsTr("Stopped."));
    }

    function requestEpisodesIfReady() {
        if (page.feedId > 0 && page.feedId !== page.lastRequestedFeedId) {
            page.lastRequestedFeedId = page.feedId;
            apiClient.fetchEpisodes(page.feedId);
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Inactive) {
            stopPlayback();
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

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#202942" }
            GradientStop { position: 1.0; color: "#101624" }
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

    ListView {
        id: episodeList
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: playerPanel.top
        anchors.margins: 16
        spacing: 8
        model: apiClient.episodes

        delegate: Rectangle {
            width: episodeList.width
            height: 72
            radius: 6
            color: index % 2 === 0 ? "#1b2335" : "#202a3f"
            opacity: modelData.enclosureUrl && modelData.enclosureUrl.length > 0 ? 1.0 : 0.6

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Text {
                    text: modelData.title
                    color: platformStyle.colorNormalLight
                    font.pixelSize: 17
                    elide: Text.ElideRight
                }

                Text {
                    text: formatDate(modelData.datePublished) + "  " + formatDuration(modelData.duration) + "  " +
                          mediaLabelFor(modelData.enclosureUrl, modelData.enclosureType)
                    color: "#b7c4e0"
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: page.startPlayback(modelData.enclosureUrl, modelData.title, modelData.enclosureType)
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

    Rectangle {
        id: playerPanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 150
        color: "#0f1524"
        border.width: 1
        border.color: "#26314a"

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                width: parent.width
                text: page.currentTitle.length > 0 ? page.currentTitle : qsTr("No episode selected.")
                color: platformStyle.colorNormalLight
                font.pixelSize: 16
                elide: Text.ElideRight
            }

            Button {
                width: parent.width
                text: audio.state === audio.playingState ? qsTr("Pause") : qsTr("Play")
                onClicked: page.togglePlayback()
            }

            Text {
                width: parent.width
                text: page.statusMessage
                color: "#b7c4e0"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                text: page.streamUrl && page.streamUrl.toString().length > 0
                      ? qsTr("Source: %1").arg(mediaLabelFor(page.streamUrl, page.currentEnclosureType))
                      : ""
                color: "#93a3c4"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
    }

    AudioFacade {
        id: audio
        source: page.streamUrl
        volume: 1.0
        muted: false

        onStateChanged: {
            page.isPlaying = (state === audio.playingState);
            page.updateStatus("");
        }

        onStatusChanged: {
            page.updateStatus("");
            if (status === audio.endOfMedia) {
                page.updateStatus(qsTr("End of media."));
            }
        }

        onPositionChanged: page.updateStatus("")

        onError: {
            page.updateStatus(qsTr("Error: %1").arg(errorString));
        }
    }
}
