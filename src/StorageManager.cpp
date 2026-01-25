#include "StorageManager.h"

#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QTextStream>
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
    QTextStream ts(stdout);
    ts << "Storage error (" << context << "): " << error.text() << '\n';
    ts.flush();
}
}

StorageManager::StorageManager(QObject *parent)
    : QObject(parent)
    , m_forwardSkipSeconds(30)
    , m_backwardSkipSeconds(15)
{
    initDb();
    loadSettings();
    refreshSubscriptions();
}

QVariantList StorageManager::subscriptions() const
{
    return m_subscriptions;
}

int StorageManager::forwardSkipSeconds() const
{
    return m_forwardSkipSeconds;
}

int StorageManager::backwardSkipSeconds() const
{
    return m_backwardSkipSeconds;
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

void StorageManager::refreshSubscriptions()
{
    if (!ensureOpen()) {
        return;
    }

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kConnectionName));
    QSqlQuery query(db);
    if (!query.exec(QLatin1String("SELECT feed_id, title, image, last_updated FROM subscriptions ORDER BY title ASC"))) {
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

void StorageManager::subscribe(int feedId, const QString &title, const QString &image)
{
    if (feedId <= 0) {
        return;
    }
    if (!ensureOpen()) {
        return;
    }

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kConnectionName));
    QSqlQuery query(db);
    query.prepare(QLatin1String("INSERT OR REPLACE INTO subscriptions (feed_id, title, image, last_updated) "
                                "VALUES (?, ?, ?, ?)"));
    query.addBindValue(feedId);
    query.addBindValue(title);
    query.addBindValue(image);
    query.addBindValue(static_cast<int>(QDateTime::currentDateTimeUtc().toTime_t()));

    if (!query.exec()) {
        logError("subscribe", query.lastError());
        return;
    }

    refreshSubscriptions();
}

void StorageManager::unsubscribe(int feedId)
{
    if (feedId <= 0) {
        return;
    }
    if (!ensureOpen()) {
        return;
    }

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kConnectionName));
    QSqlQuery query(db);
    query.prepare(QLatin1String("DELETE FROM subscriptions WHERE feed_id = ?"));
    query.addBindValue(feedId);

    if (!query.exec()) {
        logError("unsubscribe", query.lastError());
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

QString StorageManager::dbPath() const
{
    QString base = QDesktopServices::storageLocation(QDesktopServices::DataLocation);
    if (base.isEmpty()) {
        base = QDir::homePath() + QLatin1String("/.podin");
    }
    QDir dir(base);
    if (!dir.exists()) {
        dir.mkpath(QLatin1String("."));
    }
    return dir.filePath(QLatin1String("podin.db"));
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
    if (QSqlDatabase::contains(QLatin1String(kConnectionName))) {
        return;
    }

    QSqlDatabase db = QSqlDatabase::addDatabase(QLatin1String("QSQLITE"), QLatin1String(kConnectionName));
    db.setDatabaseName(dbPath());
    if (!db.open()) {
        logError("init db", db.lastError());
        return;
    }

    QSqlQuery query(db);
    if (!query.exec(QLatin1String("CREATE TABLE IF NOT EXISTS subscriptions ("
                                  "feed_id INTEGER PRIMARY KEY, "
                                  "title TEXT NOT NULL, "
                                  "image TEXT, "
                                  "last_updated INTEGER)"))) {
        logError("create subscriptions table", query.lastError());
    }

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

    if (!query.exec(QLatin1String("INSERT OR IGNORE INTO settings (key, value) "
                                  "VALUES ('forward_skip_seconds', 30)"))) {
        logError("seed forward skip setting", query.lastError());
    }

    if (!query.exec(QLatin1String("INSERT OR IGNORE INTO settings (key, value) "
                                  "VALUES ('backward_skip_seconds', 15)"))) {
        logError("seed backward skip setting", query.lastError());
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
