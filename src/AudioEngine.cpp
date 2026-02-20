#include "AudioEngine.h"
#include <QMediaPlayer>
#include <QMediaContent>
#include <QDebug>

AudioEngine::AudioEngine(QObject *parent)
    : QObject(parent)
    , m_player(0)
    , m_volume(1.0)
    , m_muted(false)
    , m_state(0)
    , m_status(0)
    , m_position(0)
    , m_duration(0)
    , m_bufferProgress(0)
    , m_seekable(false)
    , m_available(false)
    , m_pendingSeek(-1)
    , m_lastEmittedPosition(-1)
{
    m_player = new QMediaPlayer(this);
    if (m_player) {
        m_available = true;
        connect(m_player, SIGNAL(stateChanged(QMediaPlayer::State)),
                this, SLOT(onPlayerStateChanged()));
        connect(m_player, SIGNAL(mediaStatusChanged(QMediaPlayer::MediaStatus)),
                this, SLOT(onPlayerMediaStatusChanged()));
        connect(m_player, SIGNAL(positionChanged(qint64)),
                this, SLOT(onPlayerPositionChanged(qint64)));
        connect(m_player, SIGNAL(durationChanged(qint64)),
                this, SLOT(onPlayerDurationChanged(qint64)));
        connect(m_player, SIGNAL(bufferStatusChanged(int)),
                this, SLOT(onPlayerBufferStatusChanged(int)));
        connect(m_player, SIGNAL(seekableChanged(bool)),
                this, SLOT(onPlayerSeekableChanged(bool)));
        connect(m_player, SIGNAL(error(QMediaPlayer::Error)),
                this, SLOT(onPlayerError()));
        qDebug() << "AudioEngine: QMediaPlayer created successfully";
    } else {
        qDebug() << "AudioEngine: Failed to create QMediaPlayer";
    }
    emit availableChanged();
}

AudioEngine::~AudioEngine()
{
}

// --- Property accessors ---

QUrl AudioEngine::source() const
{
    return m_source;
}

void AudioEngine::setSource(const QUrl &url)
{
    if (m_source == url)
        return;
    m_source = url;
    emit sourceChanged();
    if (m_player && url.isValid() && !url.isEmpty()) {
        m_player->setMedia(QMediaContent(url));
    } else if (m_player) {
        m_player->setMedia(QMediaContent());
    }
}

qreal AudioEngine::volume() const
{
    return m_volume;
}

void AudioEngine::setVolume(qreal vol)
{
    if (qFuzzyCompare(m_volume, vol))
        return;
    m_volume = vol;
    if (m_player) {
        // QMediaPlayer volume is 0-100, QML AudioFacade uses 0.0-1.0
        m_player->setVolume(qRound(vol * 100.0));
    }
    emit volumeChanged();
}

bool AudioEngine::muted() const
{
    return m_muted;
}

void AudioEngine::setMuted(bool m)
{
    if (m_muted == m)
        return;
    m_muted = m;
    if (m_player) {
        m_player->setMuted(m);
    }
    emit mutedChanged();
}

int AudioEngine::state() const
{
    return m_state;
}

int AudioEngine::status() const
{
    return m_status;
}

int AudioEngine::position() const
{
    return m_position;
}

int AudioEngine::duration() const
{
    return m_duration;
}

qreal AudioEngine::bufferProgress() const
{
    return m_bufferProgress;
}

bool AudioEngine::seekable() const
{
    return m_seekable;
}

bool AudioEngine::available() const
{
    return m_available;
}

QString AudioEngine::errorString() const
{
    return m_errorString;
}

// --- Playback control ---

void AudioEngine::play()
{
    if (!m_player) {
        m_errorString = QLatin1String("Audio playback unavailable.");
        emit errorStringChanged();
        emit error();
        return;
    }
    qDebug() << "AudioEngine: play() source=" << m_source.toString();
    m_player->play();
}

void AudioEngine::pause()
{
    if (m_player) {
        m_player->pause();
    }
}

void AudioEngine::stop()
{
    if (m_player) {
        m_player->stop();
    } else {
        if (m_state != 0) {
            m_state = 0;
            emit stateChanged();
        }
    }
}

void AudioEngine::seek(int positionMs)
{
    if (!m_player)
        return;

    QMediaPlayer::State s = m_player->state();
    if (s == QMediaPlayer::PlayingState || s == QMediaPlayer::PausedState) {
        qDebug() << "AudioEngine: seek to" << positionMs << "ms (state=" << s << ")";
        m_player->setPosition(static_cast<qint64>(positionMs));
        m_pendingSeek = -1;
    } else {
        qDebug() << "AudioEngine: deferring seek to" << positionMs << "ms (state=" << s << ")";
        m_pendingSeek = positionMs;
    }
}

void AudioEngine::reset()
{
    if (m_player) {
        m_player->stop();
        m_player->setMedia(QMediaContent());
    }
    m_source = QUrl();
    emit sourceChanged();

    m_pendingSeek = -1;
    m_lastEmittedPosition = -1;

    if (m_state != 0) { m_state = 0; emit stateChanged(); }
    if (m_status != 0) { m_status = 0; emit statusChanged(); }
    if (m_position != 0) { m_position = 0; emit positionChanged(); }
    if (m_duration != 0) { m_duration = 0; emit durationChanged(); }
    if (m_bufferProgress != 0) { m_bufferProgress = 0; emit bufferProgressChanged(); }
    if (!m_errorString.isEmpty()) { m_errorString.clear(); emit errorStringChanged(); }
}

void AudioEngine::prepareForNewSource()
{
    if (m_player) {
        m_player->stop();
        m_player->setMedia(QMediaContent());
    }
    m_pendingSeek = -1;
    m_lastEmittedPosition = -1;

    if (m_state != 0) { m_state = 0; emit stateChanged(); }
    if (m_status != 0) { m_status = 0; emit statusChanged(); }
    if (m_position != 0) { m_position = 0; emit positionChanged(); }
    if (m_duration != 0) { m_duration = 0; emit durationChanged(); }
    if (m_bufferProgress != 0) { m_bufferProgress = 0; emit bufferProgressChanged(); }
    if (!m_errorString.isEmpty()) { m_errorString.clear(); emit errorStringChanged(); }
}

void AudioEngine::ensureImpl()
{
    // No-op — QMediaPlayer is created in constructor.
    // Kept for PlaybackController.qml compatibility.
}

// --- State mapping ---

int AudioEngine::mapState() const
{
    if (!m_player)
        return 0;
    switch (m_player->state()) {
    case QMediaPlayer::StoppedState: return 0;
    case QMediaPlayer::PlayingState: return 1;
    case QMediaPlayer::PausedState:  return 2;
    default: return 0;
    }
}

int AudioEngine::mapStatus() const
{
    if (!m_player)
        return 0;
    switch (m_player->mediaStatus()) {
    case QMediaPlayer::UnknownMediaStatus: return 0;
    case QMediaPlayer::NoMedia:            return 1;
    case QMediaPlayer::LoadingMedia:       return 2;
    case QMediaPlayer::LoadedMedia:        return 3;
    case QMediaPlayer::StalledMedia:       return 4;
    case QMediaPlayer::BufferingMedia:     return 5;
    case QMediaPlayer::BufferedMedia:      return 6;
    case QMediaPlayer::EndOfMedia:         return 7;
    case QMediaPlayer::InvalidMedia:       return 8;
    default: return 0;
    }
}

void AudioEngine::applyPendingSeek()
{
    if (m_pendingSeek < 0 || !m_player)
        return;
    QMediaPlayer::State s = m_player->state();
    if (s == QMediaPlayer::PlayingState || s == QMediaPlayer::PausedState) {
        qDebug() << "AudioEngine: applying deferred seek to" << m_pendingSeek << "ms";
        m_player->setPosition(static_cast<qint64>(m_pendingSeek));
        m_pendingSeek = -1;
    }
}

// --- Slots ---

void AudioEngine::onPlayerStateChanged()
{
    int newState = mapState();
    if (m_state != newState) {
        m_state = newState;
        qDebug() << "AudioEngine: state ->" << newState;
        // Force an immediate position update so the slider snaps to the correct
        // position on play/pause/stop, bypassing the 500 ms throttle.
        m_lastEmittedPosition = -1;
        emit stateChanged();
    }
    applyPendingSeek();
}

void AudioEngine::onPlayerMediaStatusChanged()
{
    int newStatus = mapStatus();
    if (m_status != newStatus) {
        m_status = newStatus;
        qDebug() << "AudioEngine: status ->" << newStatus
                 << "error=" << (m_player ? m_player->errorString() : QString());
        emit statusChanged();
    }

    // Update seekable when status changes
    if (m_player) {
        bool s = m_player->isSeekable();
        if (m_seekable != s) {
            m_seekable = s;
            emit seekableChanged();
        }
    }

    if (newStatus == 8 && m_player) { // invalidMedia
        QString err = m_player->errorString();
        if (!err.isEmpty() && m_errorString != err) {
            m_errorString = err;
            emit errorStringChanged();
            qDebug() << "AudioEngine: InvalidMedia error:" << err;
        }
    }
}

void AudioEngine::onPlayerPositionChanged(qint64 pos)
{
    int newPos = static_cast<int>(pos);
    if (m_position == newPos)
        return;
    m_position = newPos;
    // Throttle: only notify QML when position has moved >=500 ms from the last
    // emitted value. This keeps the seek slider responsive without flooding the
    // QML event loop at the full QMediaPlayer tick rate (~20-50 Hz).
    if (m_lastEmittedPosition < 0 || qAbs(m_position - m_lastEmittedPosition) >= 500) {
        m_lastEmittedPosition = m_position;
        emit positionChanged();
    }
}

void AudioEngine::onPlayerDurationChanged(qint64 dur)
{
    int newDur = static_cast<int>(dur);
    if (m_duration != newDur) {
        m_duration = newDur;
        emit durationChanged();
    }
}

void AudioEngine::onPlayerBufferStatusChanged(int percent)
{
    // QMediaPlayer reports 0-100, AudioFacade used 0.0-1.0
    qreal newProgress = percent / 100.0;
    // Only emit on 2%+ change to avoid flooding the QML event loop during long playback
    if (qAbs(m_bufferProgress - newProgress) >= 0.02) {
        m_bufferProgress = newProgress;
        emit bufferProgressChanged();
    }
}

void AudioEngine::onPlayerSeekableChanged(bool s)
{
    if (m_seekable != s) {
        m_seekable = s;
        emit seekableChanged();
    }
}

void AudioEngine::onPlayerError()
{
    if (!m_player)
        return;
    QString err = m_player->errorString();
    qDebug() << "AudioEngine: Error:" << err;
    if (m_errorString != err) {
        m_errorString = err;
        emit errorStringChanged();
    }
    emit error();
}
