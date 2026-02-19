import QtQuick 1.1
import com.nokia.symbian 1.1

Page {
    id: page
    objectName: "PlayerPage"
    orientationLock: PageOrientation.LockPortrait

    property QtObject playback: null
    property string statusMessage: qsTr("Ready to play.")
    property bool updatingSlider: false
    property bool userSeeking: false

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
        var detailNote = note;
        if ((!detailNote || detailNote.length === 0) &&
            playback.errorString && playback.errorString.length > 0) {
            detailNote = playback.errorString;
        }
        var stateText = isPlaybackActive() ? qsTr("Playing")
                        : (playback.manualPaused || playback.state === playback.pausedState) ? qsTr("Paused")
                        : qsTr("Stopped");
        var statusText = backendStatusName(playback.status);
        var position = formatDuration(playback.position / 1000);
        var duration = formatDuration(playback.duration / 1000);
        var base = stateText + " • " + statusText + "\n" + position + " / " + duration;
        if (detailNote && detailNote.length > 0) {
            base = detailNote + "\n" + base;
        }
        page.statusMessage = base;
    }

    function syncSeekSlider() {
        if (!playback || page.updatingSlider || page.userSeeking) {
            return;
        }
        page.updatingSlider = true;
        seekSlider.value = playback.position;
        page.updatingSlider = false;
    }

    function commitSeek() {
        if (!playback) {
            return;
        }
        playback.seekBuffered(seekSlider.value);
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1f2a43" }
            GradientStop { position: 1.0; color: "#0f1524" }
        }
    }

    Flickable {
        id: mainFlickable
        anchors.fill: parent
        anchors.margins: 16
        contentWidth: width
        contentHeight: mainColumn.height
        clip: true
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: mainColumn
            width: parent.width
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

            Text {
                width: parent.width
                text: playback && playback.episodeDescription ? playback.episodeDescription : ""
                color: "#b7c4e0"
                font.pixelSize: 18
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                visible: playback ? (playback.episodeDescription && playback.episodeDescription.length > 0) : false
            }

            Column {
                id: seekArea
                width: parent.width
                spacing: 6

                Item {
                    width: parent.width
                    height: seekSlider.height

                    Slider {
                        id: seekSlider
                        width: parent.width
                        minimumValue: 0
                        maximumValue: playback && playback.duration > 0 ? playback.duration : 1
                        value: 0
                        enabled: playback ? (playback.duration > 0 && playback.available && playback.seekable) : false
                        onPressedChanged: {
                            page.userSeeking = pressed;
                            if (!pressed) {
                                page.commitSeek();
                            }
                        }
                    }

                    Rectangle {
                        id: bufferFill
                        height: 6
                        radius: 3
                        color: "#3b4d6e"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        width: {
                            if (!playback) {
                                return 0;
                            }
                            var progress = playback.bufferProgress;
                            if (progress < 0) {
                                progress = 0;
                            } else if (progress > 1) {
                                progress = 1;
                            }
                            return Math.round(parent.width * progress);
                        }
                    }

                    Rectangle {
                        id: progressFill
                        height: 6
                        radius: 3
                        color: "#5a7cff"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        width: {
                            if (!playback || playback.duration <= 0) {
                                return 0;
                            }
                            var ratio = seekSlider.value / playback.duration;
                            if (ratio < 0) {
                                ratio = 0;
                            } else if (ratio > 1) {
                                ratio = 1;
                            }
                            return Math.round(parent.width * ratio);
                        }
                    }
                }

                Row {
                    width: parent.width

                    Text {
                        width: parent.width / 2
                        text: formatDuration(seekSlider.value / 1000)
                        color: "#9fb0d3"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignLeft
                    }

                    Text {
                        width: parent.width / 2
                        text: playback && playback.duration > 0 ? formatDuration(playback.duration / 1000) : "0:00"
                        color: "#9fb0d3"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            Text {
                width: parent.width
                property bool resolving: streamUrlResolver ? streamUrlResolver.resolving : false
                text: resolving ? qsTr("Resolving stream URL...") : qsTr("Buffering...")
                color: resolving ? "#ffffaa" : "#ffd6d9"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                visible: resolving || (playback
                         ? (isPlaybackActive() &&
                            (playback.status === playback.bufferingStatus ||
                             playback.status === playback.loadingStatus ||
                             playback.status === playback.stalledStatus))
                         : false)
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
                    text: qsTr("Back %1s").arg(storage ? storage.backwardSkipSeconds : 15)
                    enabled: playback ? (playback.available && playback.seekable) : false
                    onClicked: {
                        if (playback) {
                            playback.skipRelative(-(storage ? storage.backwardSkipSeconds : 15));
                        }
                    }
                }

                Button {
                    width: (parent.width - 8) / 2
                    text: qsTr("Forward %1s").arg(storage ? storage.forwardSkipSeconds : 30)
                    enabled: playback ? (playback.available && playback.seekable) : false
                    onClicked: {
                        if (playback) {
                            playback.skipRelative(storage ? storage.forwardSkipSeconds : 30);
                        }
                    }
                }
            }

            Button {
                width: parent.width
                text: qsTr("Stop")
                onClicked: {
                    if (playback) {
                        playback.stop();
                    }
                }
            }

            Text {
                width: parent.width
                text: page.statusMessage
                color: "#b7c4e0"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }

            // Debug section header
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

            // Debug info - all inline in the scrollable column
            Text {
                width: parent.width
                text: playback ? ("pos=" + playback.position +
                                  " / " + playback.duration +
                                  " status=" + playback.status + " (" + backendStatusName(playback.status) + ")" +
                                  " state=" + playback.state) : "player=N/A"
                color: "#ffffff"
                font.pixelSize: 14
                wrapMode: Text.WrapAnywhere
            }

            Text {
                width: parent.width
                text: playback ? ("seekable=" + playback.seekable +
                                  " buffer=" + playback.bufferProgress.toFixed(2) +
                                  " available=" + playback.available +
                                  " tried=" + playback.triedUrls.length) : "seek=N/A"
                color: "#ffd6d9"
                font.pixelSize: 14
                wrapMode: Text.WrapAnywhere
            }

            Text {
                width: parent.width
                property bool resolving: streamUrlResolver ? streamUrlResolver.resolving : false
                property string resolverError: streamUrlResolver ? streamUrlResolver.errorString : ""
                text: resolving ? "RESOLVER: Resolving redirects..."
                      : (resolverError.length > 0 ? ("RESOLVER ERROR: " + resolverError)
                      : "RESOLVER: Idle")
                color: resolving ? "#ffff00" : (resolverError.length > 0 ? "#ff8888" : "#88ff88")
                font.pixelSize: 14
                font.bold: resolving
                wrapMode: Text.WrapAnywhere
            }

            Text {
                width: parent.width
                property string urlStr: playback && playback.originalUrl ? playback.originalUrl.toString() : ""
                text: urlStr.length > 0 ? ("ORIGINAL: " + urlStr) : "ORIGINAL: (none)"
                color: "#ffcc88"
                font.pixelSize: 13
                wrapMode: Text.WrapAnywhere
            }

            Text {
                width: parent.width
                property string urlStr: playback && playback.streamUrl ? playback.streamUrl.toString() : ""
                property string origUrlStr: playback && playback.originalUrl ? playback.originalUrl.toString() : ""
                property string proto: urlStr.indexOf("https://") === 0 ? "HTTPS" : (urlStr.indexOf("http://") === 0 ? "HTTP" : "OTHER")
                property bool isResolved: urlStr.length > 0 && origUrlStr.length > 0 && origUrlStr !== urlStr
                text: urlStr.length > 0 ? ((isResolved ? "RESOLVED [" : "[") + proto + "] " + urlStr) : "PLAYING: (none)"
                color: isResolved ? "#88ffcc" : "#aaccff"
                font.pixelSize: 13
                wrapMode: Text.WrapAnywhere
            }

            Text {
                width: parent.width
                text: playback && playback.enclosureType ? ("Type: " + playback.enclosureType) : "Type: (unknown)"
                color: "#aaccff"
                font.pixelSize: 13
                wrapMode: Text.WrapAnywhere
            }

            Text {
                width: parent.width
                text: playback && playback.errorString && playback.errorString.length > 0
                      ? ("Error: " + playback.errorString)
                      : "Error: (none)"
                color: playback && playback.errorString && playback.errorString.length > 0 ? "#ff8888" : "#88ff88"
                font.pixelSize: 14
                wrapMode: Text.WrapAnywhere
            }

            Text {
                width: parent.width
                text: playback ? ("epId=" + (playback.episodeId ? playback.episodeId : "none") +
                                  " feedId=" + playback.feedId) : "episode=N/A"
                color: "#cccccc"
                font.pixelSize: 13
                wrapMode: Text.WrapAnywhere
            }

            // Add some padding at the bottom
            Item {
                width: parent.width
                height: 20
            }
        }
    }

    function logDebugInfo() {
        if (!playback) {
            console.log("[DEBUG] player=N/A");
            return;
        }
        console.log("[DEBUG] pos=" + playback.position +
                    " / " + playback.duration +
                    " status=" + playback.status + " (" + backendStatusName(playback.status) + ")" +
                    " state=" + playback.state);
        console.log("[DEBUG] seekable=" + playback.seekable +
                    " buffer=" + playback.bufferProgress.toFixed(2) +
                    " available=" + playback.available +
                    " tried=" + playback.triedUrls.length);

        var resolving = streamUrlResolver ? streamUrlResolver.resolving : false;
        var resolverError = streamUrlResolver ? streamUrlResolver.errorString : "";
        console.log("[DEBUG] RESOLVER: " + (resolving ? "Resolving..." : (resolverError.length > 0 ? "ERROR: " + resolverError : "Idle")));

        var origUrl = playback.originalUrl ? playback.originalUrl.toString() : "";
        console.log("[DEBUG] ORIGINAL: " + (origUrl.length > 0 ? origUrl : "(none)"));

        var streamUrl = playback.streamUrl ? playback.streamUrl.toString() : "";
        var isResolved = origUrl.length > 0 && streamUrl.length > 0 && origUrl !== streamUrl;
        console.log("[DEBUG] " + (isResolved ? "RESOLVED: " : "PLAYING: ") + (streamUrl.length > 0 ? streamUrl : "(none)"));

        if (playback.enclosureType) {
            console.log("[DEBUG] Type: " + playback.enclosureType);
        }
        if (playback.errorString && playback.errorString.length > 0) {
            console.log("[DEBUG] Error: " + playback.errorString);
        }
        console.log("[DEBUG] epId=" + (playback.episodeId ? playback.episodeId : "none") +
                    " feedId=" + playback.feedId);
    }

    Connections {
        target: playback
        onPositionChanged: {
            page.syncSeekSlider();
            page.updateStatus("");
        }
        onDurationChanged: {
            page.syncSeekSlider();
            page.logDebugInfo();
        }
        onStateChanged: {
            page.updateStatus("");
            page.logDebugInfo();
        }
        onStatusChanged: {
            page.updateStatus("");
            page.logDebugInfo();
        }
        onErrorStringChanged: {
            page.updateStatus("");
            page.logDebugInfo();
        }
    }

    Connections {
        target: streamUrlResolver ? streamUrlResolver : null
        ignoreUnknownSignals: true
        onResolvingChanged: page.logDebugInfo()
        onErrorStringChanged: page.logDebugInfo()
    }

    Component.onCompleted: {
        page.updateStatus("");
    }
}
