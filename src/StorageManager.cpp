#include "StorageManager.h"

#include "AppConfig.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QTextStream>
#include <QtCore/QDebug>
#include <QtGui/QDesktopServices>
#include <QtSql/QSqlDatabase>
#include <QtSql/QSqlError>
#include <QtSql/QSqlQuery>
#include <QtCore/qglobal.h>

namespace {
const char *const kConnectionName = "podin";

void logError(const QString &context, const QSqlError &error)
{
    if (error.type() == QSqlError::NoError) {
        return;
    }
    qWarning("Storage error (%s): %s",
             qPrintable(context),
             qPrintable(error.text()));
}
}

StorageManager::StorageManager(QObject *parent)
    : QObject(parent)
    , m_forwardSkipSeconds(30)
    , m_backwardSkipSeconds(15)
    , m_enableArtworkLoading(false)
    , m_volumePercent(50)
    , m_sleepTimerMinutes(0)
    , m_dbStatus(QLatin1String("not initialized"))
{
    initDb();
    loadSettings();
    refreshSubscriptions();
    refreshSearchHistory();
}

QVariantList StorageManager::subscriptions() const
{
    return m_subscriptions;
}

QVariantList StorageManager::searchHistory() const
{
    return m_searchHistory;
}

int StorageManager::forwardSkipSeconds() const
{
    return m_forwardSkipSeconds;
}

int StorageManager::backwardSkipSeconds() const
{
    return m_backwardSkipSeconds;
}

bool StorageManager::enableArtworkLoading() const
{
    return m_enableArtworkLoading;
}

int StorageManager::volumePercent() const
{
    return m_volumePercent;
}

void StorageManager::setForwardSkipSeconds(int seconds)
{
    int clamped = qBound(5, seconds, 60);
    if (clamped == m_forwardSkipSeconds) {
        return;
    }
    m_forwardSkipSeconds = clamped;
    saveSetting(QString::fromLatin1("forward_skip_seconds"), m_forwardSkipSeconds);
    emit forwardSkipSecondsChanged();
}

void StorageManager::setBackwardSkipSeconds(int seconds)
{
    int clamped = qBound(2, seconds, 30);
    if (clamped == m_backwardSkipSeconds) {
        return;
    }
    m_backwardSkipSeconds = clamped;
    saveSetting(QString::fromLatin1("backward_skip_seconds"), m_backwardSkipSeconds);
    emit backwardSkipSecondsChanged();
}

void StorageManager::setEnableArtworkLoading(bool enabled)
{
    if (enabled == m_enableArtworkLoading) {
        return;
    }
    m_enableArtworkLoading = enabled;
    saveSetting(QString::fromLatin1("enable_artwork_loading"), m_enableArtworkLoading ? 1 : 0);
    emit enableArtworkLoadingChanged();
}

void StorageManager::setVolumePercent(int percent)
{
    int clamped = qBound(0, percent, 100);
    if (clamped == m_volumePercent) {
        return;
    }
    m_volumePercent = clamped;
    saveSetting(QString::fromLatin1("volume_percent"), m_volumePercent);
    emit volumePercentChanged();
}

int StorageManager::sleepTimerMinutes() const
{
    return m_sleepTimerMinutes;
}

void StorageManager::setSleepTimerMinutes(int minutes)
{
    // Only allow valid presets: 0 (off), 15, 30, 60, 90, 120
    if (minutes != 0 && minutes != 15 && minutes != 30 &&
        minutes != 60 && minutes != 90 && minutes != 120) {
        return;
    }
    if (minutes == m_sleepTimerMinutes) {
        return;
    }
    m_sleepTimerMinutes = minutes;
    saveSetting(QString::fromLatin1("sleep_timer_minutes"), m_sleepTimerMinutes);
    emit sleepTimerMinutesChanged();
}

void StorageManager::refreshSubscriptions()
{
    if (!ensureOpen()) {
        return;
    }

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kConnectionName));
    QSqlQuery query(db);
    if (!query.exec(QLatin1String("SELECT feed_id, title, image, last_updated, guid, image_url_hash FROM subscriptions ORDER BY title ASC"))) {
        logError("load subscriptions", query.lastError());
        return;
    }

    QVariantList results;
    while (query.next()) {
        QVariantMap entry;
        entry.insert(QString::fromLatin1("feedId"), query.value(0));
        entry.insert(QString::fromLatin1("title"), query.value(1));
        entry.insert(QString::fromLatin1("image"), query.value(2));
        entry.insert(QString::fromLatin1("lastUpdated"), query.value(3));
        entry.insert(QString::fromLatin1("guid"), query.value(4));
        entry.insert(QString::fromLatin1("imageUrlHash"), query.value(5));
        results.append(entry);
    }

    setSubscriptions(results);
}

bool StorageManager::isSubscribed(int feedId) const
{
    for (int i = 0; i < m_subscriptions.size(); ++i) {
        const QVariantMap entry = m_subscriptions.at(i).toMap();
        if (entry.value(QString::fromLatin1("feedId")).toInt() == feedId) {
            return true;
        }
    }
    return false;
}

void StorageManager::subscribe(int feedId, const QString &title, const QString &image,
                               const QString &guid, const QString &imageUrlHash)
{
    setLastError(QString());
    if (feedId <= 0) {
        setLastError(QString::fromLatin1("Subscribe failed: invalid feed ID (%1)").arg(feedId));
        return;
    }
    if (!ensureOpen()) {
        setLastError(QString::fromLatin1("Subscribe failed: database not open"));
        return;
    }

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kConnectionName));
    QSqlQuery query(db);
    query.prepare(QLatin1String("INSERT OR REPLACE INTO subscriptions (feed_id, title, image, last_updated, guid, image_url_hash) "
                                "VALUES (?, ?, ?, ?, ?, ?)"));
    query.addBindValue(feedId);
    query.addBindValue(title);
    query.addBindValue(image);
    query.addBindValue(static_cast<int>(QDateTime::currentDateTimeUtc().toTime_t()));
    query.addBindValue(guid);
    query.addBindValue(imageUrlHash);

    if (!query.exec()) {
        logError("subscribe", query.lastError());
        setLastError(QString::fromLatin1("Subscribe failed: %1").arg(query.lastError().text()));
        return;
    }

    refreshSubscriptions();
}

void StorageManager::unsubscribe(int feedId)
{
    setLastError(QString());
    if (feedId <= 0) {
        setLastError(QString::fromLatin1("Unsubscribe failed: invalid feed ID (%1)").arg(feedId));
        return;
    }
    if (!ensureOpen()) {
        setLastError(QString::fromLatin1("Unsubscribe failed: database not open"));
        return;
    }

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kConnectionName));
    QSqlQuery query(db);
    query.prepare(QLatin1String("DELETE FROM subscriptions WHERE feed_id = ?"));
    query.addBindValue(feedId);

    if (!query.exec()) {
        logError("unsubscribe", query.lastError());
        setLastError(QString::fromLatin1("Unsubscribe failed: %1").arg(query.lastError().text()));
        return;
    }

    refreshSubscriptions();
}

int StorageManager::loadEpisodePosition(const QString &episodeId) const
{
    if (episodeId.isEmpty()) {
        return 0;
    }
    if (!ensureOpen()) {
        return 0;
    }

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kConnectionName));
    QSqlQuery query(db);
    query.prepare(QLatin1String("SELECT played_position_ms FROM episodes WHERE episode_id = ?"));
    query.addBindValue(episodeId);
    if (!query.exec()) {
        logError("load episode position", query.lastError());
        return 0;
    }
    if (query.next()) {
        return query.value(0).toInt();
    }
    return 0;
}

void StorageManager::saveEpisodeProgress(const QString &episodeId,
                                         int feedId,
                                         const QString &title,
                                         const QString &audioUrl,
                                         int durationSeconds,
                                         int positionMs,
                                         const QString &enclosureType,
                                         int publishedAt,
                                         int playState)
{
    if (episodeId.isEmpty()) {
        return;
    }

    // Skip redundant writes — no position or state change since last save.
    const QPair<int,int> current(positionMs, playState);
    if (m_lastSavedProgress.value(episodeId) == current) {
        return;
    }

    if (!ensureOpen()) {
        return;
    }

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kConnectionName));
    QSqlQuery query(db);
    query.prepare(QLatin1String("INSERT OR REPLACE INTO episodes "
                                "(episode_id, feed_id, title, audio_url, duration_seconds, "
                                "played_position_ms, last_played_at, enclosure_type, published_at, play_state) "
                                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"));
    query.addBindValue(episodeId);
    query.addBindValue(feedId);
    query.addBindValue(title);
    query.addBindValue(audioUrl);
    query.addBindValue(durationSeconds);
    query.addBindValue(positionMs);
    query.addBindValue(static_cast<int>(QDateTime::currentDateTimeUtc().toTime_t()));
    query.addBindValue(enclosureType);
    query.addBindValue(publishedAt);
    query.addBindValue(playState);

    if (!query.exec()) {
        logError("save episode progress", query.lastError());
    } else {
        m_lastSavedProgress.insert(episodeId, current);
    }
}

QVariantMap StorageManager::loadEpisodeState(const QString &episodeId) const
{
    QVariantMap state;
    state.insert(QString::fromLatin1("positionMs"), 0);
    state.insert(QString::fromLatin1("playState"), 0);
    if (episodeId.isEmpty()) {
        return state;
    }
    if (!ensureOpen()) {
        return state;
    }

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kConnectionName));
    QSqlQuery query(db);
    query.prepare(QLatin1String("SELECT played_position_ms, play_state FROM episodes WHERE episode_id = ?"));
    query.addBindValue(episodeId);
    if (!query.exec()) {
        logError("load episode state", query.lastError());
        return state;
    }
    if (query.next()) {
        state.insert(QString::fromLatin1("positionMs"), query.value(0).toInt());
        state.insert(QString::fromLatin1("playState"), query.value(1).toInt());
    }
    return state;
}

QString StorageManager::dbPath()
{
    QString base;
    m_dbPathLog.clear();
#ifdef Q_OS_SYMBIAN
    // Try multiple locations on Symbian
    // For self-signed apps, only the private directory is writable
    QStringList candidates;

    // 1. App's private directory from QDesktopServices (works for self-signed)
    QString dataPath = QDesktopServices::storageLocation(QDesktopServices::DataLocation);
    if (!dataPath.isEmpty()) {
        candidates << dataPath;
    }
    m_dbPathLog += QString::fromLatin1("DataLocation: %1\n").arg(dataPath.isEmpty() ? QLatin1String("(empty)") : dataPath);

    // 2. Try app's private directory using QCoreApplication path
    QString appPrivate = QCoreApplication::applicationDirPath();
    if (!appPrivate.isEmpty() && !candidates.contains(appPrivate)) {
        candidates << appPrivate;
    }
    m_dbPathLog += QString::fromLatin1("AppDirPath: %1\n").arg(appPrivate.isEmpty() ? QLatin1String("(empty)") : appPrivate);

    // 3. Try C:\Data\Podin (requires WriteUserData capability - won't work self-signed)
    candidates << QLatin1String(AppConfig::kPhoneBase);

    // 4. Try E:\Podin (memory card - might work)
    candidates << QLatin1String(AppConfig::kMemoryCardBase);

    // 5. Try temp location as last resort
    QString tempPath = QDir::tempPath();
    if (!tempPath.isEmpty() && !candidates.contains(tempPath)) {
        candidates << tempPath;
    }
    m_dbPathLog += QString::fromLatin1("TempPath: %1\n").arg(tempPath.isEmpty() ? QLatin1String("(empty)") : tempPath);
    m_dbPathLog += QString::fromLatin1("Candidates: %1\n").arg(candidates.join(QLatin1String(", ")));
    
    // Determine which driver will actually be used
    QString testDriver = QLatin1String("QSQLITE");
    if (QSqlDatabase::isDriverAvailable(QLatin1String("QSYMSQL"))) {
        testDriver = QLatin1String("QSYMSQL");
    }
    m_dbPathLog += QString::fromLatin1("TestDriver: %1\n").arg(testDriver);

    // Try each candidate - test with actual SQLite open
    for (int i = 0; i < candidates.size(); ++i) {
        QString candidatePath = candidates.at(i);
        QDir dir(candidatePath);

        // On Symbian, paths under /private/ are data-caged:
        // QDir::exists() returns false even though the directory exists,
        // and mkpath() fails because the /private/ parent is system-owned.
        // Skip the exists/mkdir check for these paths and go straight to
        // the SQLite write test.
        bool isPrivatePath = candidatePath.contains(QLatin1String("/private/"),
                                                     Qt::CaseInsensitive);
        if (!isPrivatePath) {
            if (!dir.exists()) {
                if (!dir.mkpath(QLatin1String("."))) {
                    m_dbPathLog += QString::fromLatin1("mkdir FAIL: %1\n").arg(candidatePath);
                    qDebug() << "StorageManager: mkdir failed for" << candidatePath;
                    continue;
                }
                m_dbPathLog += QString::fromLatin1("mkdir OK: %1\n").arg(candidatePath);
            } else {
                m_dbPathLog += QString::fromLatin1("exists: %1\n").arg(candidatePath);
            }
        } else {
            m_dbPathLog += QString::fromLatin1("private (skip mkdir): %1\n").arg(candidatePath);
        }

        // Test by actually opening SQLite database with the same driver
        // that initDb() will use
        QString testDbPath = QDir::toNativeSeparators(
            dir.filePath(QLatin1String("test.db")));
        if (QSqlDatabase::contains(QLatin1String("path_test"))) {
            QSqlDatabase::removeDatabase(QLatin1String("path_test"));
        }

        QSqlDatabase testDb = QSqlDatabase::addDatabase(testDriver, QLatin1String("path_test"));
        testDb.setDatabaseName(testDbPath);
        if (testDb.open()) {
            QSqlQuery q(testDb);
            if (q.exec(QLatin1String("CREATE TABLE IF NOT EXISTS test(id INTEGER)"))) {
                testDb.close();
                QSqlDatabase::removeDatabase(QLatin1String("path_test"));
                QFile::remove(testDbPath);
                base = candidatePath;
                m_dbPathLog += QString::fromLatin1("SQLite OK: %1\n").arg(candidatePath);
                qDebug() << "StorageManager: Using db path:" << base;
                break;
            }
            m_dbPathLog += QString::fromLatin1("SQLite CREATE FAIL: %1\n").arg(candidatePath);
        } else {
            m_dbPathLog += QString::fromLatin1("SQLite open FAIL: %1 - %2\n").arg(candidatePath, testDb.lastError().text());
        }
        testDb.close();
        QSqlDatabase::removeDatabase(QLatin1String("path_test"));
        QFile::remove(testDbPath);
        qDebug() << "StorageManager: SQLite test failed for" << candidatePath;
    }

    // Last resort: in-memory database (data won't persist)
    if (base.isEmpty()) {
        qWarning() << "StorageManager: No writable path found, using in-memory database";
        m_dbPathLog += QLatin1String("FALLBACK: in-memory\n");
        m_dbPath = QLatin1String(":memory:");
        return m_dbPath;
    }
#else
    base = QDesktopServices::storageLocation(QDesktopServices::DataLocation);
    m_dbPathLog += QString::fromLatin1("DataLocation: %1\n").arg(base.isEmpty() ? QLatin1String("(empty)") : base);
    if (base.isEmpty()) {
        base = QDir::homePath() + QLatin1String("/.podin");
        m_dbPathLog += QString::fromLatin1("Using home fallback: %1\n").arg(base);
    }
#endif
    QDir dir(base);
    bool baseIsPrivate = base.contains(QLatin1String("/private/"), Qt::CaseInsensitive);
    if (!baseIsPrivate && !dir.exists()) {
        if (dir.mkpath(QLatin1String("."))) {
            m_dbPathLog += QString::fromLatin1("Created dir: %1\n").arg(base);
        } else {
            m_dbPathLog += QString::fromLatin1("mkdir FAIL: %1\n").arg(base);
        }
    }
    m_dbPath = QDir::toNativeSeparators(dir.filePath(QLatin1String("podin.db")));
    return m_dbPath;
}

bool StorageManager::ensureOpen() const
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kConnectionName), false);
    if (db.isValid() && db.isOpen()) {
        return true;
    }

    if (!db.isValid()) {
        return false;
    }
    if (!db.open()) {
        logError("open db", db.lastError());
        return false;
    }
    return true;
}

void StorageManager::initDb()
{
    QStringList drivers = QSqlDatabase::drivers();
    qDebug() << "StorageManager: Available SQL drivers:" << drivers;
    m_dbPathLog += QString::fromLatin1("Drivers: %1\n").arg(drivers.join(QLatin1String(", ")));

    if (QSqlDatabase::contains(QLatin1String(kConnectionName))) {
        m_dbStatus = QLatin1String("already exists");
        return;
    }

    QString path = dbPath();
    qDebug() << "StorageManager: Opening database at:" << path;

    // On Symbian, prefer QSYMSQL (native Symbian SQL) over QSQLITE if available
    QString driverName;
#ifdef Q_OS_SYMBIAN
    if (QSqlDatabase::isDriverAvailable(QLatin1String("QSYMSQL"))) {
        driverName = QLatin1String("QSYMSQL");
        qDebug() << "StorageManager: Using QSYMSQL driver";
    } else
#endif
    if (QSqlDatabase::isDriverAvailable(QLatin1String("QSQLITE"))) {
        driverName = QLatin1String("QSQLITE");
        qDebug() << "StorageManager: Using QSQLITE driver";
    } else {
        m_dbStatus = QString::fromLatin1("no driver available: %1").arg(drivers.join(QLatin1String(", ")));
        qWarning("Storage error (init db): No SQLite driver available. Drivers: %s",
                 qPrintable(drivers.join(QLatin1String(", "))));
        return;
    }
    m_dbPathLog += QString::fromLatin1("Using driver: %1\n").arg(driverName);

    QSqlDatabase db = QSqlDatabase::addDatabase(driverName, QLatin1String(kConnectionName));
    db.setDatabaseName(path);

    if (!db.open()) {
        m_dbStatus = QString::fromLatin1("open failed: %1").arg(db.lastError().text());
        qWarning("Storage error (init db): Failed to open database at %s - %s",
                 qPrintable(path),
                 qPrintable(db.lastError().text()));
        return;
    }

    m_dbStatus = QLatin1String("open");
    qDebug() << "StorageManager: Database opened successfully";

    // Use WAL journal mode for non-blocking writes (avoids fsync stalls during playback)
    QSqlQuery journalQuery(db);
    if (!journalQuery.exec(QLatin1String("PRAGMA journal_mode=WAL"))) {
        qDebug() << "StorageManager: Could not set journal_mode";
    }

    QSqlQuery query(db);
    if (!query.exec(QLatin1String("CREATE TABLE IF NOT EXISTS subscriptions ("
                                  "feed_id INTEGER PRIMARY KEY, "
                                  "title TEXT NOT NULL, "
                                  "image TEXT, "
                                  "last_updated INTEGER, "
                                  "guid TEXT, "
                                  "image_url_hash TEXT)"))) {
        logError("create subscriptions table", query.lastError());
    }

    // Migration: add guid and image_url_hash columns if missing
    query.exec(QLatin1String("ALTER TABLE subscriptions ADD COLUMN guid TEXT"));
    query.exec(QLatin1String("ALTER TABLE subscriptions ADD COLUMN image_url_hash TEXT"));

    if (!query.exec(QLatin1String("CREATE TABLE IF NOT EXISTS episodes ("
                                  "episode_id TEXT PRIMARY KEY, "
                                  "feed_id INTEGER NOT NULL, "
                                  "title TEXT NOT NULL, "
                                  "audio_url TEXT NOT NULL, "
                                  "duration_seconds INTEGER, "
                                  "played_position_ms INTEGER DEFAULT 0, "
                                  "last_played_at INTEGER, "
                                  "published_at INTEGER, "
                                  "enclosure_type TEXT, "
                                  "play_state INTEGER DEFAULT 0, "
                                  "image TEXT, "
                                  "FOREIGN KEY(feed_id) REFERENCES subscriptions(feed_id))"))) {
        logError("create episodes table", query.lastError());
    }

    if (!query.exec(QLatin1String("CREATE TABLE IF NOT EXISTS settings ("
                                  "key TEXT PRIMARY KEY, "
                                  "value INTEGER)"))) {
        logError("create settings table", query.lastError());
    }

    if (!query.exec(QLatin1String("CREATE TABLE IF NOT EXISTS search_history ("
                                  "term TEXT PRIMARY KEY COLLATE NOCASE, "
                                  "searched_at INTEGER)"))) {
        logError("create search_history table", query.lastError());
    }

    if (!query.exec(QLatin1String("INSERT OR IGNORE INTO settings (key, value) "
                                  "VALUES ('forward_skip_seconds', 30)"))) {
        logError("seed forward skip setting", query.lastError());
    }

    if (!query.exec(QLatin1String("INSERT OR IGNORE INTO settings (key, value) "
                                  "VALUES ('backward_skip_seconds', 15)"))) {
        logError("seed backward skip setting", query.lastError());
    }
    if (!query.exec(QLatin1String("INSERT OR IGNORE INTO settings (key, value) "
                                  "VALUES ('enable_artwork_loading', 0)"))) {
        logError("seed artwork loading setting", query.lastError());
    }
    if (!query.exec(QLatin1String("INSERT OR IGNORE INTO settings (key, value) "
                                  "VALUES ('volume_percent', 50)"))) {
        logError("seed volume percent setting", query.lastError());
    }

    QSqlQuery pragma(db);
    bool havePlayState = false;
    if (pragma.exec(QLatin1String("PRAGMA table_info(episodes)"))) {
        while (pragma.next()) {
            if (pragma.value(1).toString() == QLatin1String("play_state")) {
                havePlayState = true;
                break;
            }
        }
    }
    if (!havePlayState) {
        QSqlQuery alter(db);
        if (!alter.exec(QLatin1String("ALTER TABLE episodes ADD COLUMN play_state INTEGER DEFAULT 0"))) {
            logError("alter episodes add play_state", alter.lastError());
        }
    }

    if (!query.exec(QLatin1String("CREATE INDEX IF NOT EXISTS idx_episodes_feed_id ON episodes(feed_id)"))) {
        logError("create idx_episodes_feed_id", query.lastError());
    }

    if (!query.exec(QLatin1String("CREATE INDEX IF NOT EXISTS idx_episodes_last_played ON episodes(last_played_at)"))) {
        logError("create idx_episodes_last_played", query.lastError());
    }
}

void StorageManager::loadSettings()
{
    if (!ensureOpen()) {
        return;
    }
    m_forwardSkipSeconds = readSetting(QString::fromLatin1("forward_skip_seconds"), 30);
    m_backwardSkipSeconds = readSetting(QString::fromLatin1("backward_skip_seconds"), 15);
    m_enableArtworkLoading = readSetting(QString::fromLatin1("enable_artwork_loading"), 1) != 0;
    m_volumePercent = qBound(0, readSetting(QString::fromLatin1("volume_percent"), 50), 100);
    m_sleepTimerMinutes = readSetting(QString::fromLatin1("sleep_timer_minutes"), 0);
}

void StorageManager::saveSetting(const QString &key, int value)
{
    if (!ensureOpen()) {
        return;
    }
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kConnectionName));
    QSqlQuery query(db);
    query.prepare(QLatin1String("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)"));
    query.addBindValue(key);
    query.addBindValue(value);
    if (!query.exec()) {
        logError("save setting", query.lastError());
    }
}

int StorageManager::readSetting(const QString &key, int defaultValue) const
{
    if (!ensureOpen()) {
        return defaultValue;
    }
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kConnectionName));
    QSqlQuery query(db);
    query.prepare(QLatin1String("SELECT value FROM settings WHERE key = ?"));
    query.addBindValue(key);
    if (!query.exec()) {
        logError("load setting", query.lastError());
        return defaultValue;
    }
    if (query.next()) {
        return query.value(0).toInt();
    }
    return defaultValue;
}

void StorageManager::setSubscriptions(const QVariantList &list)
{
    m_subscriptions = list;
    emit subscriptionsChanged();
}

QString StorageManager::lastError() const
{
    return m_lastError;
}

void StorageManager::setLastError(const QString &error)
{
    if (m_lastError == error) {
        return;
    }
    m_lastError = error;
    emit lastErrorChanged();
}

void StorageManager::addSearchHistory(const QString &term)
{
    QString trimmed = term.trimmed();
    if (trimmed.isEmpty()) {
        return;
    }
    if (!ensureOpen()) {
        return;
    }

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kConnectionName));
    QSqlQuery query(db);
    query.prepare(QLatin1String("INSERT OR REPLACE INTO search_history (term, searched_at) VALUES (?, ?)"));
    query.addBindValue(trimmed);
    query.addBindValue(static_cast<int>(QDateTime::currentDateTimeUtc().toTime_t()));
    if (!query.exec()) {
        logError("add search history", query.lastError());
        return;
    }

    // Prune to newest 20 entries
    QSqlQuery prune(db);
    if (!prune.exec(QLatin1String("DELETE FROM search_history WHERE rowid NOT IN "
                                  "(SELECT rowid FROM search_history ORDER BY searched_at DESC LIMIT 20)"))) {
        logError("prune search history", prune.lastError());
    }

    refreshSearchHistory();
}

void StorageManager::removeSearchHistory(const QString &term)
{
    if (term.isEmpty()) {
        return;
    }
    if (!ensureOpen()) {
        return;
    }

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kConnectionName));
    QSqlQuery query(db);
    query.prepare(QLatin1String("DELETE FROM search_history WHERE term = ?"));
    query.addBindValue(term);
    if (!query.exec()) {
        logError("remove search history", query.lastError());
        return;
    }

    refreshSearchHistory();
}

void StorageManager::refreshSearchHistory()
{
    if (!ensureOpen()) {
        return;
    }

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kConnectionName));
    QSqlQuery query(db);
    if (!query.exec(QLatin1String("SELECT term FROM search_history ORDER BY searched_at DESC"))) {
        logError("load search history", query.lastError());
        return;
    }

    QVariantList results;
    while (query.next()) {
        QVariantMap entry;
        entry.insert(QString::fromLatin1("term"), query.value(0));
        results.append(entry);
    }

    m_searchHistory = results;
    emit searchHistoryChanged();
}

void StorageManager::clearLastError()
{
    setLastError(QString());
}

QString StorageManager::dbPathForQml() const
{
    return m_dbPath;
}

QString StorageManager::dbStatus() const
{
    return m_dbStatus;
}

QString StorageManager::dbPathLog() const
{
    return m_dbPathLog;
}
