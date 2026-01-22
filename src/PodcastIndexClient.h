#ifndef PODCASTINDEXCLIENT_H
#define PODCASTINDEXCLIENT_H

#include <QtCore/QObject>
#include <QtCore/QTimer>
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

public:
    explicit PodcastIndexClient(QObject *parent = 0);

    bool busy() const;
    QString errorMessage() const;
    QVariantList podcasts() const;
    QVariantList episodes() const;

    Q_INVOKABLE void search(const QString &term);
    Q_INVOKABLE void fetchEpisodes(int feedId);

signals:
    void busyChanged();
    void errorMessageChanged();
    void podcastsChanged();
    void episodesChanged();

private slots:
    void onReplyFinished();
    void onTimeout();
    void onSslErrors(const QList<QSslError> &errors);

private:
    enum RequestType {
        NoneRequest,
        SearchRequest,
        EpisodesRequest
    };

    void startRequest(RequestType type, const QUrl &url);
    void abortActiveRequest();
    void setBusy(bool busy);
    void setErrorMessage(const QString &message);
    void setPodcasts(const QVariantList &podcasts);
    void setEpisodes(const QVariantList &episodes);

    QNetworkRequest buildRequest(const QUrl &url);
    QByteArray buildAuthorizationHeader(const QByteArray &apiKey,
                                        const QByteArray &apiSecret,
                                        const QByteArray &timestamp) const;

    QVariantList parseFeedList(const QVariant &root) const;
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
    RequestType m_requestType;
    bool m_loggedSslInfo;
};

#endif // PODCASTINDEXCLIENT_H
