#ifndef AUDIOENGINE_H
#define AUDIOENGINE_H

#include <QObject>
#include <QUrl>

class QMediaPlayer;
class QMediaContent;

class AudioEngine : public QObject
{
    Q_OBJECT

    // Playback properties
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ muted WRITE setMuted NOTIFY mutedChanged)

    // State properties (read-only from QML)
    Q_PROPERTY(int state READ state NOTIFY stateChanged)
    Q_PROPERTY(int status READ status NOTIFY statusChanged)
    Q_PROPERTY(int position READ position NOTIFY positionChanged)
    Q_PROPERTY(int duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(qreal bufferProgress READ bufferProgress NOTIFY bufferProgressChanged)
    Q_PROPERTY(bool seekable READ seekable NOTIFY seekableChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)

    // Constants matching AudioFacade's enum values for QML compatibility
    Q_PROPERTY(int stoppedState READ stoppedState CONSTANT)
    Q_PROPERTY(int playingState READ playingState CONSTANT)
    Q_PROPERTY(int pausedState READ pausedState CONSTANT)
    Q_PROPERTY(int unknownStatus READ unknownStatus CONSTANT)
    Q_PROPERTY(int noMediaStatus READ noMediaStatus CONSTANT)
    Q_PROPERTY(int loadingStatus READ loadingStatus CONSTANT)
    Q_PROPERTY(int loadedStatus READ loadedStatus CONSTANT)
    Q_PROPERTY(int stalledStatus READ stalledStatus CONSTANT)
    Q_PROPERTY(int bufferingStatus READ bufferingStatus CONSTANT)
    Q_PROPERTY(int bufferedStatus READ bufferedStatus CONSTANT)
    Q_PROPERTY(int endOfMedia READ endOfMedia CONSTANT)
    Q_PROPERTY(int invalidMedia READ invalidMedia CONSTANT)

public:
    explicit AudioEngine(QObject *parent = 0);
    ~AudioEngine();

    // Property accessors
    QUrl source() const;
    void setSource(const QUrl &url);

    qreal volume() const;
    void setVolume(qreal vol);

    bool muted() const;
    void setMuted(bool m);

    int state() const;
    int status() const;
    int position() const;
    int duration() const;
    qreal bufferProgress() const;
    bool seekable() const;
    bool available() const;
    QString errorString() const;

    // Enum constants (matching AudioFacade numbering)
    int stoppedState() const { return 0; }
    int playingState() const { return 1; }
    int pausedState() const { return 2; }
    int unknownStatus() const { return 0; }
    int noMediaStatus() const { return 1; }
    int loadingStatus() const { return 2; }
    int loadedStatus() const { return 3; }
    int stalledStatus() const { return 4; }
    int bufferingStatus() const { return 5; }
    int bufferedStatus() const { return 6; }
    int endOfMedia() const { return 7; }
    int invalidMedia() const { return 8; }

    // Q_INVOKABLE methods for QML
    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(int positionMs);
    Q_INVOKABLE void reset();
    Q_INVOKABLE void prepareForNewSource();
    Q_INVOKABLE void ensureImpl(); // no-op, for PlaybackController compat

signals:
    void sourceChanged();
    void volumeChanged();
    void mutedChanged();
    void stateChanged();
    void statusChanged();
    void positionChanged();
    void durationChanged();
    void bufferProgressChanged();
    void seekableChanged();
    void availableChanged();
    void errorStringChanged();
    void error();

private slots:
    void onPlayerStateChanged();
    void onPlayerMediaStatusChanged();
    void onPlayerPositionChanged(qint64 pos);
    void onPlayerDurationChanged(qint64 dur);
    void onPlayerBufferStatusChanged(int percent);
    void onPlayerSeekableChanged(bool s);
    void onPlayerError();

private:
    int mapState() const;
    int mapStatus() const;
    void applyPendingSeek();

    QMediaPlayer *m_player;
    QUrl m_source;
    qreal m_volume;
    bool m_muted;
    int m_state;
    int m_status;
    int m_position;
    int m_duration;
    qreal m_bufferProgress;
    bool m_seekable;
    bool m_available;
    QString m_errorString;
    int m_pendingSeek;          // -1 = none
    int m_lastEmittedPosition;  // -1 = never emitted; used to throttle positionChanged
};

#endif // AUDIOENGINE_H
