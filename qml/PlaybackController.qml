import QtQuick 1.1

Item {
    id: playback
    width: 0
    height: 0
    visible: false

    property url streamUrl: ""
    property string episodeId: ""
    property int feedId: 0
    property string episodeTitle: ""
    property string podcastTitle: ""
    property string enclosureType: ""
    property bool isPlaying: false
    property bool manualPaused: false
    property int pendingSeekMs: 0
    property bool resumeApplied: false
    property bool pauseAfterSeek: false
    property int seekTargetMs: -1
    property bool resumeAfterSeek: false

    property int state: audio.state
    property int status: audio.status
    property int position: audio.position
    property int duration: audio.duration
    property real bufferProgress: audio.bufferProgress
    property bool seekable: audio.seekable
    property bool available: audio.available
    property string errorString: audio.errorString
    property int stoppedState: audio.stoppedState
    property int playingState: audio.playingState
    property int pausedState: audio.pausedState
    property int noMediaStatus: audio.noMediaStatus
    property int loadingStatus: audio.loadingStatus
    property int loadedStatus: audio.loadedStatus
    property int bufferingStatus: audio.bufferingStatus
    property int bufferedStatus: audio.bufferedStatus
    property int stalledStatus: audio.stalledStatus
    property int endOfMedia: audio.endOfMedia
    property int invalidMedia: audio.invalidMedia

    function startEpisode(url, epId, feed, title, podcast, enclosure, autoPlay) {
        var urlString = url ? (url.toString ? url.toString() : url) : "";
        if (urlString.length === 0) {
            return;
        }
        streamUrl = urlString;
        console.log("Podin playing URL:", streamUrl);
        episodeId = epId ? epId.toString() : "";
        feedId = feed || 0;
        episodeTitle = title || "";
        podcastTitle = podcast || "";
        enclosureType = enclosure || "";
        pendingSeekMs = 0;
        resumeApplied = false;
        pauseAfterSeek = false;
        manualPaused = false;

        if (storage && episodeId.length > 0) {
            var stateMap = storage.loadEpisodeState(episodeId);
            pendingSeekMs = stateMap.positionMs ? stateMap.positionMs : 0;
            var lastState = stateMap.playState ? stateMap.playState : 0;
            if (lastState === 2) {
                pauseAfterSeek = true;
                manualPaused = true;
            }
        }

        var shouldAutoPlay = (autoPlay === undefined) ? true : autoPlay;
        if (shouldAutoPlay) {
            play();
        }
    }

    function play() {
        audio.ensureImpl();
        if (!audio.available) {
            return;
        }
        var resumeNow = manualPaused && pendingSeekMs > 0;
        if (resumeNow) {
            resumeApplied = false;
        }
        audio.play();
        isPlaying = true;
        manualPaused = false;
        if (!resumeApplied) {
            pauseAfterSeek = pauseAfterSeek;
        }
        if (resumeNow) {
            audio.seek(pendingSeekMs);
            resumeApplied = true;
        }
    }

    function pause() {
        audio.ensureImpl();
        if (!audio.available) {
            return;
        }
        if (!(pendingSeekMs > 0 && !resumeApplied)) {
            pendingSeekMs = audio.position;
        }
        resumeApplied = false;
        manualPaused = true;
        isPlaying = false;
        audio.pause();
        saveProgress(2);
    }

    function stop() {
        manualPaused = false;
        isPlaying = false;
        saveProgress(0);
        audio.stop();
    }

    function seek(positionMs) {
        audio.ensureImpl();
        if (!audio.available) {
            return;
        }
        var target = positionMs;
        if (target < 0) {
            target = 0;
        }
        if (audio.duration > 0 && target > audio.duration) {
            target = audio.duration;
        }
        var shouldResume = isPlaying && !manualPaused;
        if (shouldResume) {
            audio.pause();
        }
        seekTargetMs = target;
        resumeAfterSeek = shouldResume;
        audio.seek(target);
        if (resumeAfterSeek) {
            seekResumeTimer.restart();
        }
        pendingSeekMs = target;
        resumeApplied = false;
    }

    function bufferedLimitMs() {
        if (audio.duration <= 0) {
            return 0;
        }
        var progress = audio.bufferProgress;
        if (progress <= 0 || progress > 1) {
            return audio.duration;
        }
        var limit = Math.floor(audio.duration * progress);
        if (limit <= 0) {
            return 0;
        }
        if (limit < audio.position) {
            return audio.duration;
        }
        return limit;
    }

    function seekBuffered(positionMs) {
        var target = positionMs;
        var limit = bufferedLimitMs();
        if (limit > 0 && target > limit) {
            target = limit;
        }
        seek(target);
    }

    function skipRelative(seconds) {
        var deltaSeconds = (seconds === undefined || seconds === null) ? 0 : seconds;
        var target = position + Math.round(deltaSeconds * 1000);
        seekBuffered(target);
    }

    function saveProgress(playState) {
        if (!storage || episodeId.length === 0) {
            return;
        }
        var state = playState !== undefined ? playState : (isPlaying ? 1 : (manualPaused ? 2 : 0));
        storage.saveEpisodeProgress(episodeId,
                                    feedId,
                                    episodeTitle,
                                    streamUrl.toString(),
                                    Math.floor(duration / 1000),
                                    position,
                                    enclosureType,
                                    0,
                                    state);
    }

    Timer {
        interval: 5000
        running: playback.isPlaying
        repeat: true
        onTriggered: playback.saveProgress(1)
    }

    Timer {
        id: seekResumeTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (playback.resumeAfterSeek) {
                audio.play();
                playback.isPlaying = true;
                playback.resumeAfterSeek = false;
            }
        }
    }

    AudioFacade {
        id: audio
        source: playback.streamUrl
        volume: 1.0
        muted: false

        onStatusChanged: {
            if (!playback.manualPaused &&
                (status === audio.loadingStatus ||
                 status === audio.bufferingStatus ||
                 status === audio.loadedStatus ||
                 status === audio.bufferedStatus ||
                 status === audio.stalledStatus)) {
                playback.isPlaying = true;
            }
            if (!playback.resumeApplied &&
                playback.pendingSeekMs > 0 &&
                (status === audio.loadedStatus ||
                 status === audio.bufferingStatus ||
                 status === audio.bufferedStatus ||
                 status === audio.stalledStatus)) {
                audio.seek(playback.pendingSeekMs);
                playback.resumeApplied = true;
                if (playback.pauseAfterSeek) {
                    audio.pause();
                    playback.isPlaying = false;
                    playback.manualPaused = true;
                    playback.pauseAfterSeek = false;
                }
            }
            if (status === audio.endOfMedia) {
                playback.isPlaying = false;
                playback.pendingSeekMs = 0;
                playback.resumeApplied = true;
                playback.saveProgress(0);
            }
        }
    }
}
