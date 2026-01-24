#include "PodcastIndexClient.h"

#include <QtCore/QByteArray>
#include <QtCore/QDateTime>
#include <QtCore/QStringList>
#include <QtCore/QTextStream>
#include <QtCore/QUrl>
#include <QtCore/QVariant>
#include <QtCore/QVariantMap>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QSslError>
#include <QtNetwork/QSslSocket>
#include <QtCore/QCryptographicHash>

#include "PodcastIndexConfig.h"
#include "parser.h"

namespace {
QString pickString(const QVariantMap &map, const char *primary, const char *fallback = 0)
{
    QString value = map.value(QLatin1String(primary)).toString();
    if (value.isEmpty() && fallback) {
        value = map.value(QLatin1String(fallback)).toString();
    }
    return value;
}

QVariant pickValue(const QVariantMap &map, const char *primary, const char *fallback = 0)
{
    QVariant value = map.value(QLatin1String(primary));
    if ((!value.isValid() || value.isNull()) && fallback) {
        value = map.value(QLatin1String(fallback));
    }
    return value;
}
}

PodcastIndexClient::PodcastIndexClient(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
    , m_reply(0)
    , m_busy(false)
    , m_requestType(NoneRequest)
    , m_loggedSslInfo(false)
{
    m_timeout.setSingleShot(true);
    connect(&m_timeout, SIGNAL(timeout()), this, SLOT(onTimeout()));
}

bool PodcastIndexClient::busy() const
{
    return m_busy;
}

QString PodcastIndexClient::errorMessage() const
{
    return m_errorMessage;
}

QVariantList PodcastIndexClient::podcasts() const
{
    return m_podcasts;
}

QVariantList PodcastIndexClient::episodes() const
{
    return m_episodes;
}

QVariantMap PodcastIndexClient::podcastDetail() const
{
    return m_podcastDetail;
}

void PodcastIndexClient::search(const QString &term)
{
    const QString trimmed = term.trimmed();
    if (trimmed.isEmpty()) {
        setErrorMessage(QString::fromLatin1("Enter a search term."));
        return;
    }

    if (apiKey().isEmpty() || apiSecret().isEmpty()) {
        setErrorMessage(QString::fromLatin1("Missing API credentials. Set PODIN_API_KEY/PODIN_API_SECRET or defaults in PodcastIndexConfig.h."));
        return;
    }

    QUrl url = PodcastIndexConfig::buildUrl(QString::fromLatin1("search/byterm"));
    url.addQueryItem(QString::fromLatin1("q"), trimmed);
    url.addQueryItem(QString::fromLatin1("max"), QString::fromLatin1("10"));

    startRequest(SearchRequest, url);
}

void PodcastIndexClient::fetchPodcast(int feedId)
{
    if (feedId <= 0) {
        setErrorMessage(QString::fromLatin1("Invalid feed id."));
        return;
    }

    if (apiKey().isEmpty() || apiSecret().isEmpty()) {
        setErrorMessage(QString::fromLatin1("Missing API credentials. Set PODIN_API_KEY/PODIN_API_SECRET or defaults in PodcastIndexConfig.h."));
        return;
    }

    QUrl url = PodcastIndexConfig::buildUrl(QString::fromLatin1("podcasts/byfeedid"));
    url.addQueryItem(QString::fromLatin1("id"), QString::number(feedId));

    startRequest(PodcastRequest, url);
}

void PodcastIndexClient::fetchPodcastByGuid(const QString &guid)
{
    const QString trimmed = guid.trimmed();
    if (trimmed.isEmpty()) {
        setErrorMessage(QString::fromLatin1("Missing podcast GUID."));
        return;
    }

    if (apiKey().isEmpty() || apiSecret().isEmpty()) {
        setErrorMessage(QString::fromLatin1("Missing API credentials. Set PODIN_API_KEY/PODIN_API_SECRET or defaults in PodcastIndexConfig.h."));
        return;
    }

    QUrl url = PodcastIndexConfig::buildUrl(QString::fromLatin1("podcasts/byguid"));
    url.addQueryItem(QString::fromLatin1("guid"), trimmed);

    startRequest(PodcastRequest, url);
}

void PodcastIndexClient::fetchEpisodes(int feedId)
{
    if (feedId <= 0) {
        setErrorMessage(QString::fromLatin1("Invalid feed id."));
        return;
    }

    if (apiKey().isEmpty() || apiSecret().isEmpty()) {
        setErrorMessage(QString::fromLatin1("Missing API credentials. Set PODIN_API_KEY/PODIN_API_SECRET or defaults in PodcastIndexConfig.h."));
        return;
    }

    QUrl url = PodcastIndexConfig::buildUrl(QString::fromLatin1("episodes/byfeedid"));
    url.addQueryItem(QString::fromLatin1("id"), QString::number(feedId));
    url.addQueryItem(QString::fromLatin1("max"), QString::fromLatin1("10"));

    startRequest(EpisodesRequest, url);
}

void PodcastIndexClient::startRequest(RequestType type, const QUrl &url)
{
    abortActiveRequest();
    setErrorMessage(QString());
    setBusy(true);
    m_requestType = type;
    logSslInfo();
    if (!QSslSocket::supportsSsl()) {
        setErrorMessage(QString::fromLatin1("SSL not supported at runtime."));
        setBusy(false);
        return;
    }
    if (type == SearchRequest) {
        setPodcasts(QVariantList());
    } else if (type == PodcastRequest) {
        setPodcastDetail(QVariantMap());
    } else if (type == EpisodesRequest) {
        setEpisodes(QVariantList());
    }

    QNetworkRequest request = buildRequest(url);
    m_reply = m_nam->get(request);
    connect(m_reply, SIGNAL(finished()), this, SLOT(onReplyFinished()));
    connect(m_reply, SIGNAL(sslErrors(const QList<QSslError> &)),
            this, SLOT(onSslErrors(const QList<QSslError> &)));
    m_timeout.start(15000);
}

void PodcastIndexClient::abortActiveRequest()
{
    if (!m_reply) {
        return;
    }
    disconnect(m_reply, 0, this, 0);
    m_reply->abort();
    m_reply->deleteLater();
    m_reply = 0;
    m_timeout.stop();
    m_requestType = NoneRequest;
}

void PodcastIndexClient::setBusy(bool busy)
{
    if (m_busy == busy) {
        return;
    }
    m_busy = busy;
    emit busyChanged();
}

void PodcastIndexClient::setErrorMessage(const QString &message)
{
    if (m_errorMessage == message) {
        return;
    }
    m_errorMessage = message;
    emit errorMessageChanged();
}

void PodcastIndexClient::setPodcasts(const QVariantList &podcasts)
{
    m_podcasts = podcasts;
    emit podcastsChanged();
}

void PodcastIndexClient::setEpisodes(const QVariantList &episodes)
{
    m_episodes = episodes;
    emit episodesChanged();
}

void PodcastIndexClient::setPodcastDetail(const QVariantMap &podcastDetail)
{
    m_podcastDetail = podcastDetail;
    emit podcastDetailChanged();
}

QNetworkRequest PodcastIndexClient::buildRequest(const QUrl &url)
{
    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", QByteArray(PodcastIndexConfig::kUserAgent));
    request.setRawHeader("Accept", "application/json");

    const QByteArray key = apiKey();
    const QByteArray secret = apiSecret();
    if (!key.isEmpty() && !secret.isEmpty()) {
        const QByteArray timestamp = QByteArray::number(QDateTime::currentDateTimeUtc().toTime_t());
        request.setRawHeader("X-Auth-Key", key);
        request.setRawHeader("X-Auth-Date", timestamp);
        request.setRawHeader("Authorization", buildAuthorizationHeader(key, secret, timestamp));
    }

    return request;
}

QByteArray PodcastIndexClient::buildAuthorizationHeader(const QByteArray &apiKey,
                                                        const QByteArray &apiSecret,
                                                        const QByteArray &timestamp) const
{
    const QByteArray message = apiKey + apiSecret + timestamp;
    const QByteArray digest = QCryptographicHash::hash(message, QCryptographicHash::Sha1);
    return digest.toHex();
}

QVariantList PodcastIndexClient::parseFeedList(const QVariant &root) const
{
    const QVariantMap map = root.toMap();
    const QVariantList feeds = map.value(QString::fromLatin1("feeds")).toList();

    QVariantList results;
    results.reserve(feeds.size());

    for (int i = 0; i < feeds.size(); ++i) {
        const QVariantMap feed = feeds.at(i).toMap();
        const int feedId = pickValue(feed, "id", "feedId").toInt();
        const QString guid = pickString(feed, "podcastGuid", "guid");
        const QString title = pickString(feed, "title");
        const QString image = pickString(feed, "image", "artwork");
        const QString description = pickString(feed, "description");

        QVariantMap entry;
        entry.insert(QString::fromLatin1("feedId"), feedId);
        entry.insert(QString::fromLatin1("guid"), guid);
        entry.insert(QString::fromLatin1("title"), title);
        entry.insert(QString::fromLatin1("image"), image);
        entry.insert(QString::fromLatin1("description"), description);
        results.append(entry);
    }

    return results;
}

QVariantList PodcastIndexClient::parseEpisodeList(const QVariant &root) const
{
    const QVariantMap map = root.toMap();
    const QVariantList items = map.value(QString::fromLatin1("items")).toList();

    QVariantList results;
    results.reserve(items.size());

    for (int i = 0; i < items.size(); ++i) {
        const QVariantMap item = items.at(i).toMap();
        const QVariant idValue = pickValue(item, "id", "guid");
        const QString title = pickString(item, "title");
        const QString description = pickString(item, "description");
        const QVariant dateValue = pickValue(item, "datePublished");
        const QVariant durationValue = pickValue(item, "duration");
        const QString enclosureUrl = pickString(item, "enclosureUrl");
        const QString enclosureType = pickString(item, "enclosureType");
        const QString image = pickString(item, "image", "feedImage");

        QVariantMap entry;
        entry.insert(QString::fromLatin1("id"), idValue);
        entry.insert(QString::fromLatin1("title"), title);
        entry.insert(QString::fromLatin1("description"), description);
        entry.insert(QString::fromLatin1("datePublished"), dateValue);
        entry.insert(QString::fromLatin1("duration"), durationValue);
        entry.insert(QString::fromLatin1("enclosureUrl"), enclosureUrl);
        entry.insert(QString::fromLatin1("enclosureType"), enclosureType);
        entry.insert(QString::fromLatin1("image"), image);
        results.append(entry);
    }

    return results;
}

QVariantMap PodcastIndexClient::parsePodcastDetail(const QVariant &root) const
{
    const QVariantMap map = root.toMap();
    const QVariantMap feed = map.value(QString::fromLatin1("feed")).toMap();

    if (feed.isEmpty()) {
        return QVariantMap();
    }

    const int feedId = pickValue(feed, "id", "feedId").toInt();
    const QString guid = pickString(feed, "podcastGuid", "guid");
    const QString title = pickString(feed, "title");
    const QString description = pickString(feed, "description");
    const QString image = pickString(feed, "image", "artwork");
    const QString author = pickString(feed, "author", "ownerName");
    const QString url = pickString(feed, "url", "link");

    QVariantMap entry;
    entry.insert(QString::fromLatin1("feedId"), feedId);
    entry.insert(QString::fromLatin1("guid"), guid);
    entry.insert(QString::fromLatin1("title"), title);
    entry.insert(QString::fromLatin1("description"), description);
    entry.insert(QString::fromLatin1("image"), image);
    entry.insert(QString::fromLatin1("author"), author);
    entry.insert(QString::fromLatin1("url"), url);

    return entry;
}

QByteArray PodcastIndexClient::apiKey() const
{
    return PodcastIndexConfig::apiKey();
}

QByteArray PodcastIndexClient::apiSecret() const
{
    return PodcastIndexConfig::apiSecret();
}

void PodcastIndexClient::onReplyFinished()
{
    m_timeout.stop();

    if (!m_reply) {
        setBusy(false);
        return;
    }

    QNetworkReply *reply = m_reply;
    m_reply = 0;
    const QByteArray payload = reply->readAll();
    const QNetworkReply::NetworkError netError = reply->error();
    const QString netErrorString = reply->errorString();
    const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    reply->deleteLater();

    if (netError != QNetworkReply::NoError) {
        setErrorMessage(QString::fromLatin1("Network error: %1").arg(netErrorString));
        setBusy(false);
        m_requestType = NoneRequest;
        return;
    }

    if (statusCode < 200 || statusCode >= 300) {
        setErrorMessage(QString::fromLatin1("HTTP error %1").arg(statusCode));
        setBusy(false);
        m_requestType = NoneRequest;
        return;
    }

    QJson::Parser parser;
    bool ok = false;
    const QVariant result = parser.parse(payload, &ok);
    if (!ok) {
        setErrorMessage(QString::fromLatin1("JSON parse error: %1").arg(parser.errorString()));
        setBusy(false);
        m_requestType = NoneRequest;
        return;
    }

    if (m_requestType == SearchRequest) {
        setPodcasts(parseFeedList(result));
    } else if (m_requestType == PodcastRequest) {
        setPodcastDetail(parsePodcastDetail(result));
    } else if (m_requestType == EpisodesRequest) {
        setEpisodes(parseEpisodeList(result));
    }

    setBusy(false);
    m_requestType = NoneRequest;
}

void PodcastIndexClient::onTimeout()
{
    abortActiveRequest();
    setErrorMessage(QString::fromLatin1("Request timed out."));
    setBusy(false);
    m_requestType = NoneRequest;
}

void PodcastIndexClient::onSslErrors(const QList<QSslError> &errors)
{
    if (!m_reply) {
        return;
    }

    QStringList messages;
    for (int i = 0; i < errors.size(); ++i) {
        messages.append(errors.at(i).errorString());
    }

    QTextStream ts(stdout);
    ts << "SSL errors: " << messages.join(QString::fromLatin1("; ")) << '\n';
    ts.flush();

    // MVP: ignore SSL errors to keep feasibility testing unblocked.
    m_reply->ignoreSslErrors();
}

void PodcastIndexClient::logSslInfo()
{
    if (m_loggedSslInfo) {
        return;
    }
    m_loggedSslInfo = true;

    QTextStream ts(stdout);
    ts << "SSL supported: " << (QSslSocket::supportsSsl() ? "true" : "false") << '\n';
#if (QT_VERSION >= 0x040800)
    ts << "SSL build: " << QSslSocket::sslLibraryBuildVersionString() << '\n';
    ts << "SSL runtime: " << QSslSocket::sslLibraryVersionString() << '\n';
#else
    ts << "SSL runtime version string not available on this Qt version.\n";
#endif
    ts.flush();
}
