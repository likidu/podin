#include "ArtworkCacheManager.h"

#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QUrl>
#include <QtGui/QDesktopServices>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QSslError>

#include "AppConfig.h"
#include "PodcastIndexConfig.h"

namespace {
const int kArtworkCacheTtlDays = 60;
const char *const kCoverBaseName = "cover";
const char *const kMarkerName = "podin.cache";
}

ArtworkCacheManager::ArtworkCacheManager(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
    purgeExpired();
}

QString ArtworkCacheManager::cachedArtworkPath(int feedId, const QString &title)
{
    if (feedId <= 0 && title.trimmed().isEmpty()) {
        return QString();
    }

    const QString folder = podcastFolder(feedId, title);
    if (folder.isEmpty()) {
        return QString();
    }

    const QString cached = findCachedFile(folder);
    if (cached.isEmpty()) {
        return QString();
    }

    QFileInfo info(cached);
    if (!info.exists() || isExpired(info)) {
        QFile::remove(cached);
        return QString();
    }

    return QUrl::fromLocalFile(cached).toString();
}

void ArtworkCacheManager::requestArtwork(int feedId, const QString &title, const QString &remoteUrl)
{
    if (feedId <= 0 || remoteUrl.trimmed().isEmpty()) {
        return;
    }

    const QString cached = cachedArtworkPath(feedId, title);
    if (!cached.isEmpty()) {
        emit artworkCached(feedId, cached);
        return;
    }

    if (m_inFlight.contains(feedId)) {
        return;
    }

    QUrl url(remoteUrl);
    if (!url.isValid() || (url.scheme() != QLatin1String("http") && url.scheme() != QLatin1String("https"))) {
        emit artworkFailed(feedId, QString::fromLatin1("Invalid artwork URL."));
        return;
    }

    const QString folder = podcastFolder(feedId, title);
    if (folder.isEmpty()) {
        emit artworkFailed(feedId, QString::fromLatin1("Artwork cache folder unavailable."));
        return;
    }

    const QString ext = extensionFromUrl(url);
    QString fileName = QString::fromLatin1(kCoverBaseName);
    if (!ext.isEmpty()) {
        fileName += QString::fromLatin1(".") + ext;
    }

    QDir dir(folder);
    const QString finalPath = dir.filePath(fileName);
    const QString tempPath = finalPath + QString::fromLatin1(".part");

    QFile *file = new QFile(tempPath, this);
    if (!file->open(QIODevice::WriteOnly)) {
        file->deleteLater();
        emit artworkFailed(feedId, QString::fromLatin1("Failed to open artwork cache file."));
        return;
    }

    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", QByteArray(PodcastIndexConfig::kUserAgent));
    request.setRawHeader("Accept", "image/*");

    QNetworkReply *reply = m_nam->get(request);
    // Auto-ignore SSL errors (Symbian TLS compatibility)
    connect(reply, SIGNAL(sslErrors(const QList<QSslError> &)),
            reply, SLOT(ignoreSslErrors()));

    DownloadJob job;
    job.feedId = feedId;
    job.finalPath = finalPath;
    job.tempPath = tempPath;
    job.file = file;
    m_jobs.insert(reply, job);
    m_inFlight.insert(feedId);

    connect(reply, SIGNAL(readyRead()), this, SLOT(onReplyReadyRead()));
    connect(reply, SIGNAL(finished()), this, SLOT(onReplyFinished()));
}

void ArtworkCacheManager::onReplyReadyRead()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply || !m_jobs.contains(reply)) {
        return;
    }
    // Get reference to avoid copy - file pointer stays in sync with m_jobs
    const DownloadJob &job = m_jobs[reply];
    if (!job.file || !job.file->isOpen()) {
        return;
    }
    const QByteArray data = reply->readAll();
    if (!data.isEmpty()) {
        job.file->write(data);
    }
}

void ArtworkCacheManager::onReplyFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply) {
        return;
    }

    // Check if this reply is still tracked (could have been removed on error)
    if (!m_jobs.contains(reply)) {
        reply->deleteLater();
        return;
    }

    DownloadJob job = m_jobs.take(reply);
    m_inFlight.remove(job.feedId);

    if (job.file && job.file->isOpen()) {
        const QByteArray remainder = reply->readAll();
        if (!remainder.isEmpty()) {
            job.file->write(remainder);
        }
        job.file->flush();
        job.file->close();
    }

    const bool success = (reply->error() == QNetworkReply::NoError);
    if (success) {
        // Determine correct extension from Content-Type header
        const QString contentType = reply->header(QNetworkRequest::ContentTypeHeader).toString().toLower();
        QString correctExt;
        if (contentType.contains(QLatin1String("png"))) {
            correctExt = QLatin1String("png");
        } else if (contentType.contains(QLatin1String("gif"))) {
            correctExt = QLatin1String("gif");
        } else {
            correctExt = QLatin1String("jpg");
        }

        // Rebuild final path with correct extension
        QString finalPath = job.finalPath;
        int dot = finalPath.lastIndexOf(QLatin1Char('.'));
        if (dot != -1) {
            finalPath = finalPath.left(dot + 1) + correctExt;
        }

        // Remove any old cover files with different extensions, but keep the .part temp file
        QDir folder(QFileInfo(finalPath).absolutePath());
        const QString tempName = QFileInfo(job.tempPath).fileName();
        const QStringList oldCovers = folder.entryList(QDir::Files);
        for (int i = 0; i < oldCovers.size(); ++i) {
            if (oldCovers.at(i).startsWith(QLatin1String(kCoverBaseName))
                && oldCovers.at(i) != tempName) {
                folder.remove(oldCovers.at(i));
            }
        }

        if (!QFile::rename(job.tempPath, finalPath)) {
            QFile::remove(job.tempPath);
            emit artworkFailed(job.feedId, QString::fromLatin1("Failed to save artwork."));
        } else {
            m_lastDebugInfo = QString::fromLatin1("saved=%1 size=%2")
                .arg(QFileInfo(finalPath).fileName())
                .arg(QFileInfo(finalPath).size());
            emit lastDebugInfoChanged();
            emit artworkCached(job.feedId, QUrl::fromLocalFile(finalPath).toString());
        }
    } else {
        QFile::remove(job.tempPath);
        emit artworkFailed(job.feedId, reply->errorString());
    }

    if (job.file) {
        job.file->deleteLater();
    }
    reply->deleteLater();
}

QString ArtworkCacheManager::baseCacheDir() const
{
    QString base;
    if (QDir(QString::fromLatin1("E:/")).exists()) {
        base = QString::fromLatin1(AppConfig::kMemoryCardBase);
    } else {
        QString fallback = QDesktopServices::storageLocation(QDesktopServices::DataLocation);
        if (fallback.isEmpty()) {
            fallback = QDir::homePath() + QLatin1String("/.podin");
        }
        base = fallback + QLatin1String("/Podcast");
    }

    QDir dir(base);
    if (!dir.exists()) {
        dir.mkpath(QLatin1String("."));
    }
    return dir.absolutePath();
}

QString ArtworkCacheManager::sanitizeTitle(const QString &title) const
{
    QString trimmed = title.trimmed();
    if (trimmed.isEmpty()) {
        return QString();
    }
    QString result;
    result.reserve(trimmed.size());
    for (int i = 0; i < trimmed.size(); ++i) {
        const QChar c = trimmed.at(i);
        if (c.isLetterOrNumber() || c == QLatin1Char(' ') || c == QLatin1Char('-') || c == QLatin1Char('_')) {
            result.append(c);
        } else {
            result.append(QLatin1Char('_'));
        }
    }
    result = result.trimmed();
    if (result.size() > 60) {
        result = result.left(60).trimmed();
    }
    return result;
}

QString ArtworkCacheManager::podcastFolder(int feedId, const QString &title)
{
    const QString base = baseCacheDir();
    if (base.isEmpty()) {
        return QString();
    }

    const QString safeTitle = sanitizeTitle(title);
    QString folderName = safeTitle.isEmpty() ? QString::fromLatin1("feed-%1").arg(feedId) : safeTitle;

    QDir baseDir(base);
    QString candidate = folderName;
    QString candidatePath = baseDir.filePath(candidate);
    if (!baseDir.exists(candidate)) {
        if (baseDir.mkpath(candidate)) {
            writeMarker(candidatePath, feedId);
            return candidatePath;
        }
        return QString();
    }

    int markerFeedId = 0;
    if (readMarker(candidatePath, &markerFeedId)) {
        if (markerFeedId == feedId || feedId <= 0) {
            return candidatePath;
        }
        candidate = folderName + QString::fromLatin1(" (%1)").arg(feedId);
        candidatePath = baseDir.filePath(candidate);
        if (!baseDir.exists(candidate) && !baseDir.mkpath(candidate)) {
            return QString();
        }
        writeMarker(candidatePath, feedId);
        return candidatePath;
    }

    if (!safeTitle.isEmpty()) {
        candidate = folderName + QString::fromLatin1(" (%1)").arg(feedId);
        candidatePath = baseDir.filePath(candidate);
        if (!baseDir.exists(candidate) && !baseDir.mkpath(candidate)) {
            return QString();
        }
        writeMarker(candidatePath, feedId);
        return candidatePath;
    }

    return candidatePath;
}

QString ArtworkCacheManager::findCachedFile(const QString &folderPath) const
{
    QDir dir(folderPath);
    if (!dir.exists()) {
        return QString();
    }
    const QStringList entries = dir.entryList(QDir::Files | QDir::NoDotAndDotDot);
    QString bestPath;
    QDateTime bestTime;
    for (int i = 0; i < entries.size(); ++i) {
        const QString name = entries.at(i);
        if (!name.startsWith(QLatin1String(kCoverBaseName))
            || name.endsWith(QLatin1String(".part"))) {
            continue;
        }
        const QString fullPath = dir.filePath(name);
        QFileInfo info(fullPath);
        if (!info.exists()) {
            continue;
        }
        if (bestPath.isEmpty() || info.lastModified() > bestTime) {
            bestPath = fullPath;
            bestTime = info.lastModified();
        }
    }
    return bestPath;
}

QString ArtworkCacheManager::extensionFromUrl(const QUrl &url) const
{
    QString path = url.path();
    int dot = path.lastIndexOf(QLatin1Char('.'));
    if (dot == -1) {
        return QLatin1String("jpg");
    }
    QString ext = path.mid(dot + 1).toLower();
    if (ext.size() > 5) {
        ext = ext.left(5);
    }
    return ext;
}

bool ArtworkCacheManager::isExpired(const QFileInfo &info) const
{
    if (!info.exists()) {
        return true;
    }
    const QDateTime cutoff = QDateTime::currentDateTimeUtc().addDays(-kArtworkCacheTtlDays);
    return info.lastModified().toUTC() < cutoff;
}

void ArtworkCacheManager::purgeExpired()
{
    const QString base = baseCacheDir();
    QDir baseDir(base);
    if (!baseDir.exists()) {
        return;
    }

    const QStringList dirs = baseDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (int i = 0; i < dirs.size(); ++i) {
        const QString folderName = dirs.at(i);
        const QString folderPath = baseDir.filePath(folderName);
        int markerFeedId = 0;
        if (!readMarker(folderPath, &markerFeedId)) {
            continue;
        }

        QDir folder(folderPath);
        const QStringList files = folder.entryList(QDir::Files | QDir::NoDotAndDotDot);
        for (int j = 0; j < files.size(); ++j) {
            const QString fileName = files.at(j);
            if (!fileName.startsWith(QLatin1String(kCoverBaseName))) {
                continue;
            }
            const QString filePath = folder.filePath(fileName);
            QFileInfo info(filePath);
            if (isExpired(info)) {
                QFile::remove(filePath);
            }
        }

        const QStringList remaining = folder.entryList(QDir::Files | QDir::NoDotAndDotDot);
        if (remaining.isEmpty()) {
            baseDir.rmdir(folderName);
        }
    }
}

QString ArtworkCacheManager::markerPath(const QString &folderPath) const
{
    return QDir(folderPath).filePath(QLatin1String(kMarkerName));
}

bool ArtworkCacheManager::readMarker(const QString &folderPath, int *feedIdOut) const
{
    QFile marker(markerPath(folderPath));
    if (!marker.exists()) {
        return false;
    }
    if (!marker.open(QIODevice::ReadOnly)) {
        return false;
    }
    const QByteArray data = marker.readAll().trimmed();
    marker.close();
    bool ok = false;
    int id = data.toInt(&ok);
    if (ok && feedIdOut) {
        *feedIdOut = id;
    }
    return ok;
}

void ArtworkCacheManager::writeMarker(const QString &folderPath, int feedId) const
{
    QFile marker(markerPath(folderPath));
    if (!marker.open(QIODevice::WriteOnly)) {
        return;
    }
    marker.write(QByteArray::number(feedId));
    marker.close();
}
