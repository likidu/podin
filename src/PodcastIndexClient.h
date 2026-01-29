#ifndef PODCASTINDEXCLIENT_H
#define PODCASTINDEXCLIENT_H

#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtCore/QVariantMap>
#include <QtCore/QVariantList>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QSslError>

class PodcastIndexClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(QVariantList podcasts READ podcasts NOTIFY podcastsChanged)
    Q_PROPERTY(QVariantList episodes READ episodes NOTIFY episodesChanged)
    Q_PROPERTY(QVariantMap podcastDetail READ podcastDetail NOTIFY podcastDetailChanged)

public:
    explicit PodcastIndexClient(QObject *parent = 0);

    bool busy() const;
    QString errorMessage() const;
    QVariantList podcasts() const;
    QVariantList episodes() const;
    QVariantMap podcastDetail() const;

    Q_INVOKABLE void search(const QString &term);
    Q_INVOKABLE void searchMore(const QString &term, int maxResults);
    Q_INVOKABLE void fetchPodcast(int feedId);
    Q_INVOKABLE void fetchPodcastByGuid(const QString &guid);
    Q_INVOKABLE void fetchEpisodes(int feedId);
    Q_INVOKABLE void clearPodcasts();
    Q_INVOKABLE void clearEpisodes();
    Q_INVOKABLE void clearPodcastDetail();
    Q_INVOKABLE void clearAll();

signals:
    void busyChanged();
    void errorMessageChanged();
    void podcastsChanged();
    void episodesChanged();
    void podcastDetailChanged();

private slots:
    void onReplyFinished();
    void onTimeout();
    void onSslErrors(const QList<QSslError> &errors);

private:
    enum RequestType {
        NoneRequest,
        SearchRequest,
        PodcastRequest,
        EpisodesRequest
    };

    void startRequest(RequestType type, const QUrl &url, bool appendResults);
    void startSearchRequest(const QString &term, int maxResults, bool appendResults);
    void abortActiveRequest();
    void setBusy(bool busy);
    void setErrorMessage(const QString &message);
    void setPodcasts(const QVariantList &podcasts);
    void setEpisodes(const QVariantList &episodes);
    void setPodcastDetail(const QVariantMap &podcastDetail);

    QNetworkRequest buildRequest(const QUrl &url);
    QByteArray buildAuthorizationHeader(const QByteArray &apiKey,
                                        const QByteArray &apiSecret,
                                        const QByteArray &timestamp) const;

    QVariantList parseFeedList(const QVariant &root) const;
    QVariantMap parsePodcastDetail(const QVariant &root) const;
    QVariantList parseEpisodeList(const QVariant &root) const;
    void logSslInfo();

    QByteArray apiKey() const;
    QByteArray apiSecret() const;

    QNetworkAccessManager *m_nam;
    QNetworkReply *m_reply;
    QTimer m_timeout;
    bool m_busy;
    QString m_errorMessage;
    QVariantList m_podcasts;
    QVariantList m_episodes;
    QVariantMap m_podcastDetail;
    RequestType m_requestType;
    bool m_loggedSslInfo;
};

#endif // PODCASTINDEXCLIENT_H
