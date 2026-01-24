import QtQuick 1.1
import com.nokia.symbian 1.1

Page {
    id: page
    objectName: "PlayerPage"
    orientationLock: PageOrientation.LockPortrait

    property QtObject playback: null
    property string statusMessage: qsTr("Ready to play.")
    property bool updatingSlider: false

    function isPlaybackActive() {
        if (!playback) {
            return false;
        }
        if (playback.manualPaused) {
            return false;
        }
        if (playback.isPlaying) {
            return true;
        }
        if (playback.state === playback.playingState) {
            return true;
        }
        var st = playback.status;
        return (st === playback.loadingStatus ||
                st === playback.bufferingStatus ||
                st === playback.loadedStatus ||
                st === playback.bufferedStatus ||
                st === playback.stalledStatus);
    }

    function formatDuration(seconds) {
        if (!seconds || seconds < 0) {
            return "0:00";
        }
        var minutes = Math.floor(seconds / 60);
        var remaining = Math.floor(seconds % 60);
        return minutes + ":" + (remaining < 10 ? "0" + remaining : remaining);
    }

    function mediaLabelFor(url, enclosureTypeValue) {
        var type = enclosureTypeValue ? enclosureTypeValue.toString().toLowerCase() : "";
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

    function backendStatusName(status) {
        if (!playback) {
            return qsTr("Unknown");
        }
        if (status === playback.noMediaStatus) {
            return qsTr("No media");
        }
        if (status === playback.loadingStatus) {
            return qsTr("Loading");
        }
        if (status === playback.loadedStatus) {
            return qsTr("Loaded");
        }
        if (status === playback.bufferingStatus) {
            return qsTr("Buffering");
        }
        if (status === playback.stalledStatus) {
            return qsTr("Stalled");
        }
        if (status === playback.bufferedStatus) {
            return qsTr("Buffered");
        }
        if (status === playback.endOfMedia) {
            return qsTr("End of media");
        }
        if (status === playback.invalidMedia) {
            return qsTr("Invalid media");
        }
        return qsTr("Unknown");
    }

    function updateStatus(note) {
        if (!playback) {
            return;
        }
        var stateText = isPlaybackActive() ? qsTr("Playing")
                        : (playback.manualPaused || playback.state === playback.pausedState) ? qsTr("Paused")
                        : qsTr("Stopped");
        var statusText = backendStatusName(playback.status);
        var position = formatDuration(playback.position / 1000);
        var duration = formatDuration(playback.duration / 1000);
        var base = stateText + " • " + statusText + "\n" + position + " / " + duration;
        if (note && note.length > 0) {
            base = note + "\n" + base;
        }
        page.statusMessage = base;
    }

    function syncSeekSlider() {
        if (!playback || page.updatingSlider || seekSlider.pressed) {
            return;
        }
        page.updatingSlider = true;
        seekSlider.value = playback.position;
        page.updatingSlider = false;
    }

    function backToEpisodes() {
        if (pageStack) {
            pageStack.pop();
        } else {
            Qt.quit();
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1f2a43" }
            GradientStop { position: 1.0; color: "#0f1524" }
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 10

        Text {
            width: parent.width
            text: playback && playback.episodeTitle.length > 0 ? playback.episodeTitle : qsTr("Player")
            color: platformStyle.colorNormalLight
            font.pixelSize: 20
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: playback && playback.podcastTitle.length > 0 ? playback.podcastTitle : ""
            color: "#b7c4e0"
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            visible: playback ? (playback.podcastTitle.length > 0) : false
        }

        Text {
            width: parent.width
            text: playback && playback.streamUrl && playback.streamUrl.toString().length > 0
                  ? qsTr("Source: %1").arg(mediaLabelFor(playback.streamUrl, playback.enclosureType))
                  : ""
            color: "#93a3c4"
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            visible: playback
                     ? (playback.streamUrl && playback.streamUrl.toString().length > 0 ? true : false)
                     : false
        }

        Slider {
            id: seekSlider
            width: parent.width
            minimumValue: 0
            maximumValue: playback && playback.duration > 0 ? playback.duration : 1
            value: 0
            enabled: playback ? (playback.duration > 0 && playback.available) : false
            onValueChanged: {
                if (!playback || page.updatingSlider) {
                    return;
                }
                playback.seek(value);
            }
        }

        Text {
            width: parent.width
            text: qsTr("Buffering...")
            color: "#ffd6d9"
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            visible: playback
                     ? (isPlaybackActive() &&
                        (playback.status === playback.bufferingStatus ||
                         playback.status === playback.loadingStatus ||
                         playback.status === playback.stalledStatus))
                     : false
        }

        Button {
            width: parent.width
            text: isPlaybackActive() ? qsTr("Pause") : qsTr("Play")
            onClicked: {
                if (!playback) {
                    return;
                }
                if (isPlaybackActive()) {
                    playback.pause();
                } else {
                    playback.play();
                }
            }
        }

        Row {
            width: parent.width
            spacing: 8

            Button {
                width: (parent.width - 8) / 2
                text: qsTr("Stop")
                onClicked: {
                    if (playback) {
                        playback.stop();
                    }
                }
            }

            Button {
                width: (parent.width - 8) / 2
                text: qsTr("Back to list")
                onClicked: page.backToEpisodes()
            }
        }

        Text {
            width: parent.width
            text: page.statusMessage
            color: "#b7c4e0"
            font.pixelSize: 14
            wrapMode: Text.WordWrap
        }
    }

    Rectangle {
        id: debugOverlay
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 90
        color: "#00000088"
        visible: true

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            Text {
                width: parent.width
                text: playback ? ("state=" + playback.state +
                                  " status=" + playback.status +
                                  " pos=" + playback.position +
                                  " dur=" + playback.duration) : "state=N/A"
                color: "#ffffff"
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: playback ? ("playing=" + playback.isPlaying +
                                  " paused=" + playback.manualPaused +
                                  " pendingSeek=" + playback.pendingSeekMs +
                                  " resumeApplied=" + playback.resumeApplied) : "flags=N/A"
                color: "#d0d0d0"
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: playback ? ("url=" + (playback.streamUrl ? playback.streamUrl.toString() : "")) : "url=N/A"
                color: "#b0b0b0"
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }

    Connections {
        target: playback
        onPositionChanged: {
            page.syncSeekSlider();
            page.updateStatus("");
        }
        onDurationChanged: page.syncSeekSlider()
        onStateChanged: page.updateStatus("")
        onStatusChanged: page.updateStatus("")
    }

    Component.onCompleted: {
        page.updateStatus("");
    }
}
