import QtQuick 1.1

Item {
    id: playback
    width: 0
    height: 0
    visible: false

    // Episode information
    property url streamUrl: ""
    property url originalUrl: ""
    property string episodeId: ""
    property int feedId: 0
    property string episodeTitle: ""
    property string podcastTitle: ""
    property string enclosureType: ""

    // Playback state
    property bool isPlaying: false
    property bool manualPaused: false
    property int pendingSeekMs: 0
    property bool resumeApplied: false
    property bool pauseAfterSeek: false
    property int seekTargetMs: -1
    property bool resumeAfterSeek: false

    // Fallback state (for handling playback errors)
    property bool isTryingFallback: false

    // Resolver state
    property bool isResolving: streamUrlResolver ? streamUrlResolver.resolving : false

    // Audio state (forwarded from AudioFacade)
    property int state: audio.state
    property int status: audio.status
    property int position: audio.position
    property int duration: audio.duration
    property real bufferProgress: audio.bufferProgress
    property bool seekable: audio.seekable
    property bool available: audio.available
    property string errorString: audio.errorString

    // Audio status constants
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

    // ========== Public API ==========

    function startEpisode(url, epId, feed, title, podcast, enclosure, autoPlay) {
        var urlString = url ? (url.toString ? url.toString() : url) : "";
        if (urlString.length === 0) {
            return;
        }

        // Stop current playback before switching episodes
        audio.stop();
        if (streamUrlResolver) {
            streamUrlResolver.abort();
        }
        resolverTimeoutTimer.stop();

        // Set episode info
        originalUrl = urlString;
        streamUrl = "";
        episodeId = epId ? epId.toString() : "";
        feedId = feed || 0;
        episodeTitle = title || "";
        podcastTitle = podcast || "";
        enclosureType = enclosure || "";

        // Reset playback state
        isPlaying = false;
        manualPaused = false;
        pendingSeekMs = 0;
        resumeApplied = false;
        pauseAfterSeek = false;
        resetFallbackState();

        // Load saved state if available
        if (storage && episodeId.length > 0) {
            var stateMap = storage.loadEpisodeState(episodeId);
            pendingSeekMs = stateMap.positionMs ? stateMap.positionMs : 0;
            var lastState = stateMap.playState ? stateMap.playState : 0;
            if (lastState === 2) {
                pauseAfterSeek = true;
                manualPaused = true;
            }
        }

        console.log("PlaybackController: Starting episode:", originalUrl);

        var shouldAutoPlay = (autoPlay === undefined) ? true : autoPlay;
        if (shouldAutoPlay) {
            resolveAndPlay();
        }
    }

    function play() {
        // Check memory before attempting playback
        if (memoryMonitor && memoryMonitor.isMemoryCritical) {
            console.log("PlaybackController: Memory critically low, refusing to play");
            audio.errorString = "Memory too low to play. Please close other apps.";
            audio.error();
            isPlaying = false;
            manualPaused = true;
            return;
        }

        // If streamUrl is empty, resolve first
        var streamUrlStr = streamUrl ? streamUrl.toString() : "";
        var originalUrlStr = originalUrl ? originalUrl.toString() : "";
        if (streamUrlStr.length === 0 && originalUrlStr.length > 0) {
            resolveAndPlay();
            return;
        }

        audio.ensureImpl();
        if (!audio.available) {
            isPlaying = false;
            manualPaused = true;
            return;
        }

        var resumeNow = manualPaused && pendingSeekMs > 0;
        if (resumeNow) {
            resumeApplied = false;
        }

        audio.play();
        isPlaying = true;
        manualPaused = false;

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
        var target = Math.max(0, positionMs);
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

    function seekBuffered(positionMs) {
        var limit = bufferedLimitMs();
        var target = (limit > 0 && positionMs > limit) ? limit : positionMs;
        seek(target);
    }

    function skipRelative(seconds) {
        var deltaMs = Math.round((seconds || 0) * 1000);
        seekBuffered(position + deltaMs);
    }

    // ========== Internal Functions ==========

    function resolveAndPlay() {
        var urlStr = originalUrl ? originalUrl.toString() : "";

        // For simple direct audio URLs, skip resolution entirely
        // Resolution can interfere with Symbian MMF
        if (urlStr.match(/\.(mp3|m4a|aac|ogg)(\?|$)/i)) {
            console.log("PlaybackController: Direct audio URL, skipping resolution");
            streamUrl = originalUrl;
            play();
            return;
        }

        if (!streamUrlResolver) {
            streamUrl = originalUrl;
            play();
            return;
        }
        resolverTimeoutTimer.restart();
        streamUrlResolver.resolve(originalUrl);
    }

    function resetFallbackState() {
        isTryingFallback = false;
        triedUrls = [];
    }

    function allFallbacksExhausted() {
        // Check if we've tried enough URLs (at minimum: original + alternate protocol)
        return triedUrls.length >= 2;
    }

    // Track which URLs we've actually tried to avoid loops
    property variant triedUrls: []

    function hasTriedUrl(url) {
        for (var i = 0; i < triedUrls.length; i++) {
            if (triedUrls[i] === url) return true;
        }
        return false;
    }

    function markUrlTried(url) {
        var arr = [];
        for (var i = 0; i < triedUrls.length; i++) {
            arr.push(triedUrls[i]);
        }
        arr.push(url);
        triedUrls = arr;
    }

    function tryFallback() {
        // Guard against re-entry (reset triggers status changes)
        if (isTryingFallback) {
            return true;
        }

        var current = streamUrl ? streamUrl.toString() : "";
        console.log("PlaybackController: tryFallback called, current URL:", current);
        console.log("PlaybackController: Already tried URLs:", triedUrls.length);

        // Get base URL without protocol for comparison
        var currentBase = current.replace(/^https?:\/\//, "");

        // Try alternate protocol (HTTP <-> HTTPS)
        var altProtocol = "";
        if (current.indexOf("https://") === 0) {
            altProtocol = "http://" + currentBase;
        } else if (current.indexOf("http://") === 0) {
            altProtocol = "https://" + currentBase;
        }

        if (altProtocol.length > 0 && !hasTriedUrl(altProtocol)) {
            return tryWithUrl(altProtocol, "alternate protocol");
        }

        // Try stripping query params (for both HTTP and HTTPS)
        var questionIdx = currentBase.indexOf("?");
        if (questionIdx !== -1) {
            var pathOnly = currentBase.substring(0, questionIdx);
            if (pathOnly.match(/\.(mp3|m4a|aac|ogg)$/i)) {
                var strippedHttps = "https://" + pathOnly;
                var strippedHttp = "http://" + pathOnly;
                if (!hasTriedUrl(strippedHttps)) {
                    return tryWithUrl(strippedHttps, "stripped query (HTTPS)");
                }
                if (!hasTriedUrl(strippedHttp)) {
                    return tryWithUrl(strippedHttp, "stripped query (HTTP)");
                }
            }
        }

        // Try original URL if different from resolved
        var originalStr = originalUrl ? originalUrl.toString() : "";
        if (originalStr.length > 0) {
            var originalBase = originalStr.replace(/^https?:\/\//, "");
            // Only try original if it's actually different
            if (originalBase !== currentBase && originalBase !== currentBase.split("?")[0]) {
                var originalHttps = "https://" + originalBase;
                var originalHttp = "http://" + originalBase;
                if (!hasTriedUrl(originalHttps)) {
                    return tryWithUrl(originalHttps, "original URL (HTTPS)");
                }
                if (!hasTriedUrl(originalHttp)) {
                    return tryWithUrl(originalHttp, "original URL (HTTP)");
                }
            }
        }

        console.log("PlaybackController: All fallbacks exhausted after trying", triedUrls.length, "URLs");
        return false;
    }

    function tryWithUrl(url, description) {
        isTryingFallback = true;
        markUrlTried(url);
        // Just stop and change source - don't reset/destroy
        audio.stop();
        streamUrl = url;
        console.log("PlaybackController: Trying " + description + ":", url);
        isTryingFallback = false;
        play();
        return true;
    }

    // Legacy function name for compatibility
    function tryHttpFallback() {
        return tryFallback();
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
        return (limit <= 0 || limit < audio.position) ? audio.duration : limit;
    }

    function saveProgress(playState) {
        if (!storage || episodeId.length === 0) {
            return;
        }
        var state = playState !== undefined ? playState : (isPlaying ? 1 : (manualPaused ? 2 : 0));
        storage.saveEpisodeProgress(episodeId, feedId, episodeTitle, streamUrl.toString(),
                                    Math.floor(duration / 1000), position, enclosureType, 0, state);
    }

    function handlePlaybackError() {
        var current = streamUrl ? streamUrl.toString() : "";
        console.log("PlaybackController: Playback error for:", current);

        // Mark current URL as tried
        if (current.length > 0 && !hasTriedUrl(current)) {
            markUrlTried(current);
        }

        // Try one fallback (alternate protocol) but don't be aggressive
        // Symbian MMF can get overwhelmed with rapid retries
        if (triedUrls.length < 2) {
            fallbackTimer.restart();
        } else {
            isPlaying = false;
            console.log("PlaybackController: Playback failed after", triedUrls.length, "attempts");
        }
    }

    Timer {
        id: fallbackTimer
        interval: 1500
        repeat: false
        onTriggered: {
            if (!playback.tryFallback()) {
                playback.isPlaying = false;
            }
        }
    }

    // ========== Timers ==========

    Timer {
        id: resolverTimeoutTimer
        interval: 15000
        repeat: false
        onTriggered: {
            if (streamUrlResolver && streamUrlResolver.resolving) {
                console.log("PlaybackController: Resolver timeout, using original URL");
                streamUrlResolver.abort();
                playback.streamUrl = playback.originalUrl;
                playback.play();
            }
        }
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

    // ========== Audio Backend ==========

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

            if (status === audio.invalidMedia) {
                playback.handlePlaybackError();
            }
        }
    }

    Connections {
        target: audio
        onError: playback.handlePlaybackError()
    }

    Connections {
        target: streamUrlResolver ? streamUrlResolver : null
        ignoreUnknownSignals: true
        onResolved: {
            resolverTimeoutTimer.stop();
            playback.streamUrl = finalUrl;
            playback.play();
        }
        onError: {
            resolverTimeoutTimer.stop();
            console.log("PlaybackController: URL resolution failed:", message);
            playback.streamUrl = playback.originalUrl;
            playback.play();
        }
    }
}
