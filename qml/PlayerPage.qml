import QtQuick 1.1
import QtMultimediaKit 1.1
import com.nokia.symbian 1.1

Page {
    id: page
    orientationLock: PageOrientation.LockPortrait

    property url streamUrl: ""
    property string statusMessage: qsTr("Ready to stream.")
    property bool isPlaying: false
    property bool pendingPlay: false
    property url mp3StreamUrl: "https://download.samplelib.com/mp3/sample-15s.mp3"
    property url m4aStreamUrl: "https://aod.cos.tx.xmcdn.com/storages/6c79-audiofreehighqps/EA/B0/GKwRIasMsJJ4AX5FHwQZjPaQ.m4a"
    property string selectedStreamId: "mp3"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1e2a48" }
            GradientStop { position: 1.0; color: "#101624" }
        }
    }

    function stateName(state) {
        switch (state) {
        case Audio.PlayingState:
            return qsTr("Playing");
        case Audio.PausedState:
            return qsTr("Paused");
        default:
            return qsTr("Stopped");
        }
    }

    function backendStatusName(status) {
        switch (status) {
        case Audio.NoMedia:
            return qsTr("No media");
        case Audio.Loading:
            return qsTr("Loading");
        case Audio.Loaded:
            return qsTr("Loaded");
        case Audio.Buffering:
            return qsTr("Buffering");
        case Audio.Stalled:
            return qsTr("Stalled");
        case Audio.Buffered:
            return qsTr("Buffered");
        case Audio.EndOfMedia:
            return qsTr("End of media");
        case Audio.InvalidMedia:
            return qsTr("Invalid media");
        default:
            return qsTr("Unknown");
        }
    }

    function streamUrlForSelection(selection) {
        return selection === "m4a" ? page.m4aStreamUrl : page.mp3StreamUrl;
    }

    function urlToString(value) {
        if (!value) {
            return "";
        }
        return value.toString ? value.toString() : value;
    }

    function urlsEqual(lhs, rhs) {
        return urlToString(lhs) === urlToString(rhs);
    }

    function updateSelectionFromUrl(url) {
        var desired = urlsEqual(url, page.m4aStreamUrl) ? "m4a" : "mp3";
        if (page.selectedStreamId !== desired) {
            page.selectedStreamId = desired;
        } else {
            page.updateRadioSelection();
        }
    }

    function updateRadioSelection() {
        var mp3Selected = page.selectedStreamId === "mp3";
        if (mp3Radio && mp3Radio.checked !== mp3Selected) {
            mp3Radio.checked = mp3Selected;
        }
        var m4aSelected = page.selectedStreamId === "m4a";
        if (m4aRadio && m4aRadio.checked !== m4aSelected) {
            m4aRadio.checked = m4aSelected;
        }
    }

    function updateStatus(extra) {
        var playback = stateName(audio.state);
        var backend = backendStatusName(audio.status);
        var seconds = (audio.position / 1000).toFixed(1);
        var stream = urlToString(page.streamUrl);
        var base = qsTr("Stream URL: %1\n").arg(stream);
        base = base + qsTr("Playback: %1\nStatus: %2\nPosition: %3 s").arg(playback).arg(backend).arg(seconds);
        if (extra && extra.length > 0) {
            base = base + "\n" + extra;
        }
        page.statusMessage = base;
    }

    function selectStream(streamId) {
        if (!streamId) {
            return;
        }
        if (page.selectedStreamId === streamId) {
            page.updateRadioSelection();
            updateStatus("");
            return;
        }
        page.selectedStreamId = streamId;
    }

    function startPlayback() {
        var desiredUrl = page.streamUrlForSelection(page.selectedStreamId);
        if (!urlsEqual(page.streamUrl, desiredUrl)) {
            page.streamUrl = desiredUrl;
        }
        var targetUrl = urlToString(page.streamUrl);
        if (targetUrl.length === 0) {
            updateStatus(qsTr("No stream URL configured."));
            return;
        }
        if (audio.status === Audio.Loaded || audio.status === Audio.Buffered) {
            audio.play();
            page.isPlaying = true;
            page.pendingPlay = false;
            updateStatus(qsTr("Starting playback..."));
        } else {
            page.pendingPlay = true;
            updateStatus(qsTr("Preparing stream..."));
        }
    }

    function togglePlayback() {
        if (page.isPlaying) {
            stopPlayback();
        } else {
            startPlayback();
        }
    }

    function stopPlayback(extra) {
        var wasActive = page.isPlaying || page.pendingPlay;
        if (wasActive) {
            audio.stop();
        }
        page.isPlaying = false;
        page.pendingPlay = false;
        var note = extra;
        if (note === undefined) {
            note = wasActive ? qsTr("Playback stopped.") : qsTr("Ready to stream.");
        }
        updateStatus(note);
    }

    onSelectedStreamIdChanged: {
        page.updateRadioSelection();
        var next = page.streamUrlForSelection(page.selectedStreamId);
        if (!urlsEqual(page.streamUrl, next)) {
            page.streamUrl = next;
        } else if (!page.isPlaying && !page.pendingPlay) {
            updateStatus("");
        }
    }

    onStreamUrlChanged: {
        var streamString = urlToString(page.streamUrl);
        if (streamString.length > 0 && !urlsEqual(page.streamUrl, page.m4aStreamUrl)) {
            page.mp3StreamUrl = page.streamUrl;
        }
        if (page.isPlaying || page.pendingPlay) {
            stopPlayback("");
        } else {
            page.isPlaying = false;
            page.pendingPlay = false;
            updateStatus("");
        }
        page.updateSelectionFromUrl(page.streamUrl);
    }

    onStatusChanged: {
        if (status === PageStatus.Inactive) {
            stopPlayback();
        }
    }

    Audio {
        id: audio
        source: page.streamUrl
        volume: 1.0
        muted: false
        onStatusChanged: {
            page.updateStatus("");
            if (status === Audio.EndOfMedia) {
                page.isPlaying = false;
                page.pendingPlay = false;
                page.updateStatus(qsTr("End of media."));
            } else if ((status === Audio.Loaded || status === Audio.Buffered) && page.pendingPlay) {
                audio.play();
                page.isPlaying = true;
                page.pendingPlay = false;
                page.updateStatus("");
            } else if (status === Audio.NoMedia) {
                page.isPlaying = false;
            }
        }
        onPositionChanged: page.updateStatus("")
        onError: {
            page.isPlaying = false;
            page.pendingPlay = false;
            page.updateStatus(qsTr("Error: %1").arg(errorString));
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 16
        width: parent.width - 64

        Column {
            id: streamSelector
            width: parent.width
            spacing: 8

            Text {
                width: parent.width
                text: qsTr("Stream format")
                font.pixelSize: 18
                color: platformStyle.colorNormalLight
            }

            Row {
                spacing: 24

                RadioButton {
                    id: mp3Radio
                    text: qsTr("MP3")
                    onClicked: page.selectStream("mp3")
                }

                RadioButton {
                    id: m4aRadio
                    text: qsTr("M4A")
                    onClicked: page.selectStream("m4a")
                }
            }
        }

        Button {
            id: playPauseButton
            width: parent.width
            text: page.isPlaying ? qsTr("Pause") : qsTr("Play")
            onClicked: page.togglePlayback()
        }

        Text {
            width: parent.width
            text: page.statusMessage
            font.pixelSize: 18
            color: platformStyle.colorNormalLight
            wrapMode: Text.WordWrap
        }
    }

    Component.onCompleted: {
        var currentUrl = urlToString(page.streamUrl);
        if (currentUrl.length === 0) {
            page.streamUrl = page.streamUrlForSelection(page.selectedStreamId);
        } else if (!urlsEqual(page.streamUrl, page.m4aStreamUrl)) {
            page.mp3StreamUrl = page.streamUrl;
        }
        page.updateSelectionFromUrl(page.streamUrl);
        updateStatus("");
    }
}
