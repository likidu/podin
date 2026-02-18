#ifndef ARTWORKCACHEMANAGER_H
#define ARTWORKCACHEMANAGER_H

#include <QtCore/QObject>
#include <QtCore/QHash>
#include <QtCore/QSet>
#include <QtCore/QString>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>

class QFile;
class QFileInfo;
class QUrl;

class ArtworkCacheManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString lastDebugInfo READ lastDebugInfo NOTIFY lastDebugInfoChanged)

public:
    explicit ArtworkCacheManager(QObject *parent = 0);

    Q_INVOKABLE QString cachedArtworkPath(int feedId, const QString &title);
    Q_INVOKABLE void requestArtwork(int feedId, const QString &title, const QString &remoteUrl);

    QString lastDebugInfo() const { return m_lastDebugInfo; }

signals:
    void artworkCached(int feedId, const QString &path);
    void artworkFailed(int feedId, const QString &message);
    void lastDebugInfoChanged();

private slots:
    void onReplyReadyRead();
    void onReplyFinished();
private:
    struct DownloadJob {
        int feedId;
        QString finalPath;
        QString tempPath;
        QFile *file;
    };

    QString baseCacheDir() const;
    QString sanitizeTitle(const QString &title) const;
    QString podcastFolder(int feedId, const QString &title);
    QString findCachedFile(const QString &folderPath) const;
    QString extensionFromUrl(const QUrl &url) const;
    bool isExpired(const QFileInfo &info) const;
    void purgeExpired();
    QString markerPath(const QString &folderPath) const;
    bool readMarker(const QString &folderPath, int *feedIdOut) const;
    void writeMarker(const QString &folderPath, int feedId) const;

    QNetworkAccessManager *m_nam;
    QHash<QNetworkReply*, DownloadJob> m_jobs;
    QSet<int> m_inFlight;
    QString m_lastDebugInfo;
};

#endif // ARTWORKCACHEMANAGER_H
