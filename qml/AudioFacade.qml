import QtQuick 1.1

Item {
    id: root
    width: 0
    height: 0
    visible: false

    property url source: ""
    property real volume: 1.0
    property bool muted: false
    property int state: stoppedState
    property int status: unknownStatus
    property int position: 0
    property int duration: 0
    property string errorString: ""
    property bool available: false

    property int stoppedState: 0
    property int playingState: 1
    property int pausedState: 2
    property int unknownStatus: 0
    property int endOfMedia: 6
    property int invalidMedia: 7

    signal error()

    property QtObject _impl: null
    property bool _creating: false

    function ensureImpl() {
        if (_impl || _creating) {
            return;
        }
        if (!Qt.createQmlObject) {
            available = false;
            errorString = "Dynamic QML creation not available.";
            status = invalidMedia;
            error();
            return;
        }
        _creating = true;
        var qml = "import QtMultimediaKit 1.1; Audio { }";
        try {
            _impl = Qt.createQmlObject(qml, root, "AudioImpl");
            available = true;
            _impl.source = root.source;
            _impl.volume = root.volume;
            _impl.muted = root.muted;
        } catch (e) {
            available = false;
            errorString = "QtMultimediaKit plugin unavailable.";
            status = invalidMedia;
            error();
        }
        _creating = false;
    }

    function play() {
        ensureImpl();
        if (_impl) {
            _impl.play();
        } else {
            errorString = "Audio playback unavailable.";
            error();
        }
    }

    function pause() {
        if (_impl) {
            _impl.pause();
        }
    }

    function stop() {
        if (_impl) {
            _impl.stop();
        } else {
            state = stoppedState;
        }
    }

    onSourceChanged: {
        if (_impl) {
            _impl.source = source;
        }
    }

    onVolumeChanged: {
        if (_impl) {
            _impl.volume = volume;
        }
    }

    onMutedChanged: {
        if (_impl) {
            _impl.muted = muted;
        }
    }

    Connections {
        id: implConnections
        target: _impl
        ignoreUnknownSignals: true
        onStateChanged: root.state = _impl.state
        onStatusChanged: root.status = _impl.status
        onPositionChanged: root.position = _impl.position
        onDurationChanged: root.duration = _impl.duration
        onError: {
            root.errorString = _impl.errorString;
            root.error();
        }
    }
}
