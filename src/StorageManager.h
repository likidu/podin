#ifndef STORAGEMANAGER_H
#define STORAGEMANAGER_H

#include <QtCore/QObject>
#include <QtCore/QVariantList>
#include <QtCore/QVariantMap>

class StorageManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList subscriptions READ subscriptions NOTIFY subscriptionsChanged)
    Q_PROPERTY(int forwardSkipSeconds READ forwardSkipSeconds WRITE setForwardSkipSeconds NOTIFY forwardSkipSecondsChanged)
    Q_PROPERTY(int backwardSkipSeconds READ backwardSkipSeconds WRITE setBackwardSkipSeconds NOTIFY backwardSkipSecondsChanged)

public:
    explicit StorageManager(QObject *parent = 0);

    QVariantList subscriptions() const;
    int forwardSkipSeconds() const;
    int backwardSkipSeconds() const;

    void setForwardSkipSeconds(int seconds);
    void setBackwardSkipSeconds(int seconds);

    Q_INVOKABLE void refreshSubscriptions();
    Q_INVOKABLE bool isSubscribed(int feedId) const;
    Q_INVOKABLE void subscribe(int feedId, const QString &title, const QString &image);
    Q_INVOKABLE void unsubscribe(int feedId);

    Q_INVOKABLE int loadEpisodePosition(const QString &episodeId) const;
    Q_INVOKABLE QVariantMap loadEpisodeState(const QString &episodeId) const;
    Q_INVOKABLE void saveEpisodeProgress(const QString &episodeId,
                                         int feedId,
                                         const QString &title,
                                         const QString &audioUrl,
                                         int durationSeconds,
                                         int positionMs,
                                         const QString &enclosureType,
                                         int publishedAt,
                                         int playState);

signals:
    void subscriptionsChanged();
    void forwardSkipSecondsChanged();
    void backwardSkipSecondsChanged();

private:
    QString dbPath() const;
    bool ensureOpen() const;
    void initDb();
    void loadSettings();
    void saveSetting(const QString &key, int value);
    int readSetting(const QString &key, int defaultValue) const;
    void setSubscriptions(const QVariantList &list);

    QVariantList m_subscriptions;
    int m_forwardSkipSeconds;
    int m_backwardSkipSeconds;
};

#endif // STORAGEMANAGER_H
