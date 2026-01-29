#include "TlsChecker.h"

#include <QtCore/QByteArray>
#include <QtCore/QTextStream>
#include <QtCore/QUrl>
#include <QtCore/QVariant>
#include <QtCore/QVariantList>
#include <QtCore/QVariantMap>
#include <QtCore/QStringList>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QSslError>
#include <QtNetwork/QSslSocket>

#include "ApiConfig.h"
#include "parser.h"
#include "serializer.h"

namespace {
QString joinStrings(const QStringList &list, const QString &separator)
{
    QString result;
    for (int i = 0; i < list.size(); ++i) {
        if (i > 0) {
            result += separator;
        }
        result += list.at(i);
    }
    return result;
}
}

TlsChecker::TlsChecker(QObject *parent)
    : QObject(parent)
    , m_nam(0)
    , m_reply(0)
    , m_running(false)
    , m_jsonNam(0)
    , m_jsonReply(0)
    , m_jsonRunning(false)
{
    m_timeout.setSingleShot(true);
    connect(&m_timeout, SIGNAL(timeout()), this, SLOT(onTimeout()));

    m_jsonTimeout.setSingleShot(true);
    connect(&m_jsonTimeout, SIGNAL(timeout()), this, SLOT(onJsonTimeout()));
}

bool TlsChecker::isRunning() const
{
    return m_running;
}

bool TlsChecker::isJsonRunning() const
{
    return m_jsonRunning;
}

void TlsChecker::logLine(const QString &s)
{
    QTextStream ts(stdout);
    ts << s << '\n';
    ts.flush();
}

void TlsChecker::setRunning(bool running)
{
    if (m_running == running)
        return;

    m_running = running;
    emit runningChanged();
}

void TlsChecker::setJsonRunning(bool running)
{
    if (m_jsonRunning == running)
        return;

    m_jsonRunning = running;
    emit jsonRunningChanged();
}

void TlsChecker::startCheck()
{
    if (m_reply) {
        return; // already running
    }

    setRunning(true);

    logLine(QString::fromLatin1("supportsSsl: %1")
        .arg(QSslSocket::supportsSsl() ? "true" : "false"));

#if (QT_VERSION >= 0x040800)
    logLine(QString::fromLatin1("sslLibraryBuildVersion: %1")
        .arg(QSslSocket::sslLibraryBuildVersionString()));
    logLine(QString::fromLatin1("sslLibraryRuntimeVersion: %1")
        .arg(QSslSocket::sslLibraryVersionString()));
#else
    logLine(QString::fromLatin1("sslLibrary*VersionString APIs not available on this Qt version."));
#endif

    if (!QSslSocket::supportsSsl()) {
        logLine(QString::fromLatin1("ERROR: SSL not supported by QtNetwork at runtime."));
        setRunning(false);
        emit finished(false, QString::fromLatin1("SSL not supported at runtime"));
        return;
    }

    const QUrl url(QString::fromLatin1("https://tls-v1-2.badssl.com:1012/"));
    // const QUrl url(QString::fromLatin1("https://api.podcastindex.org/api/v1.0/recent/episodes?max=1"));
    QNetworkRequest req(url);
    req.setRawHeader("User-Agent", "Podin/1.0");

    if (!m_nam) {
        m_nam = new QNetworkAccessManager(this);
    }

    m_reply = m_nam->get(req);
    connect(m_reply, SIGNAL(sslErrors(const QList<QSslError>&)), m_reply, SLOT(ignoreSslErrors()));
    connect(m_reply, SIGNAL(finished()), this, SLOT(onReplyFinished()));

    m_timeout.start(15000);
}

void TlsChecker::startJsonTest()
{
    if (m_jsonReply) {
        return; // already running
    }

    if (!QSslSocket::supportsSsl()) {
        const QString msg = QString::fromLatin1("ERROR: SSL not supported at runtime; JSON test aborted.");
        logLine(msg);
        emit jsonTestFinished(false, msg);
        return;
    }

    const QUrl url(ApiConfig::buildUrl(ApiConfig::kSendCodeEndpoint));
    QNetworkRequest req(url);
    ApiConfig::applyDefaultHeaders(req);
    req.setHeader(QNetworkRequest::ContentTypeHeader, QString::fromLatin1("application/json"));

    QVariantMap payload;
    payload.insert(QString::fromLatin1("areaCode"), QString::fromLatin1("+86"));
    payload.insert(QString::fromLatin1("mobilePhoneNumber"), QString::fromLatin1("17601270092"));

    QJson::Serializer serializer;
    bool serializeOk = false;
    const QByteArray body = serializer.serialize(payload, &serializeOk);
    if (!serializeOk) {
        const QString msg = QString::fromLatin1("ERROR: Failed to serialize JSON payload for sendCode");
        logLine(msg);
        emit jsonTestFinished(false, msg);
        return;
    }

    if (!m_jsonNam) {
        m_jsonNam = new QNetworkAccessManager(this);
    }

    setJsonRunning(true);
    logLine(QString::fromLatin1("POST %1 payload: %2").arg(url.toString(), QString::fromLatin1(body)));

    m_jsonReply = m_jsonNam->post(req, body);
    connect(m_jsonReply, SIGNAL(finished()), this, SLOT(onJsonReplyFinished()));
    connect(m_jsonReply, SIGNAL(sslErrors(const QList<QSslError>&)), this, SLOT(onJsonSslErrors(const QList<QSslError>&)));

    m_jsonTimeout.start(15000);
}

void TlsChecker::onReplyFinished()
{
    m_timeout.stop();

    bool ok = false;
    QString msg;

    if (m_reply->error() == QNetworkReply::NoError) {
        ok = true;
        msg = QString::fromLatin1("TLS 1.2 handshake and HTTP GET succeeded.");
        logLine(msg);
    } else {
        ok = false;
        msg = QString::fromLatin1("ERROR: Request failed: %1").arg(m_reply->errorString());
        logLine(msg);
    }

    m_reply->deleteLater();
    m_reply = 0;
    if (m_nam) {
        m_nam->deleteLater();
        m_nam = 0;
    }

    setRunning(false);
    emit finished(ok, msg);
}

void TlsChecker::onJsonReplyFinished()
{
    m_jsonTimeout.stop();

    if (!m_jsonReply) {
        setJsonRunning(false);
        return;
    }

    const QNetworkReply::NetworkError netError = m_jsonReply->error();
    const QString netErrorString = m_jsonReply->errorString();
    const QByteArray payload = m_jsonReply->readAll();

    m_jsonReply->deleteLater();
    m_jsonReply = 0;
    if (m_jsonNam) {
        m_jsonNam->deleteLater();
        m_jsonNam = 0;
    }

    bool ok = false;
    QString msg;

    if (netError != QNetworkReply::NoError) {
        msg = QString::fromLatin1("ERROR: JSON request failed: %1").arg(netErrorString);
        if (netError == QNetworkReply::SslHandshakeFailedError) {
            msg += QString::fromLatin1(" (endpoint may require SNI or newer TLS support)");
        }
        logLine(msg);
    } else {
        QJson::Parser parser;
        bool parseOk = false;
        const QVariant result = parser.parse(payload, &parseOk);
        if (!parseOk) {
            msg = QString::fromLatin1("ERROR: JSON parse failed: %1 (line %2)")
                .arg(parser.errorString())
                .arg(parser.errorLine());
            logLine(msg);
        } else {
            bool haveMessage = false;
            QString msgCandidate;

            if (result.type() == QVariant::Map) {
                const QVariantMap map = result.toMap();

                const QString msgField = map.value(QString::fromLatin1("msg")).toString();
                const QString messageField = map.value(QString::fromLatin1("message")).toString();
                if (!msgField.isEmpty()) {
                    msgCandidate = QString::fromLatin1("JSON message: %1").arg(msgField);
                    haveMessage = true;
                } else if (!messageField.isEmpty()) {
                    msgCandidate = QString::fromLatin1("JSON message: %1").arg(messageField);
                    haveMessage = true;
                }

                const QString ipValue = map.value(QString::fromLatin1("ip")).toString();
                if (!haveMessage && !ipValue.isEmpty()) {
                    QStringList locationParts;
                    const QString cityValue = map.value(QString::fromLatin1("city")).toString();
                    const QString countryValue = map.value(QString::fromLatin1("country_name")).toString();
                    if (!cityValue.isEmpty()) {
                        locationParts.append(cityValue);
                    }
                    if (!countryValue.isEmpty()) {
                        locationParts.append(countryValue);
                    }
                    if (locationParts.isEmpty()) {
                        msgCandidate = QString::fromLatin1("JSON IP: %1").arg(ipValue);
                    } else {
                        const QString joinedLocations = joinStrings(locationParts, QString::fromLatin1(", "));
                        msgCandidate = QString::fromLatin1("JSON IP: %1 (%2)").arg(ipValue, joinedLocations);
                    }
                    haveMessage = true;
                }

                if (!haveMessage) {
                    const QString outputValue = map.value(QString::fromLatin1("outputValue")).toString();
                    const QString timeStamp = map.value(QString::fromLatin1("timeStamp")).toString();
                    if (!outputValue.isEmpty()) {
                        if (timeStamp.isEmpty()) {
                            msgCandidate = QString::fromLatin1("JSON output: %1").arg(outputValue);
                        } else {
                            msgCandidate = QString::fromLatin1("JSON output: %1 @ %2").arg(outputValue, timeStamp);
                        }
                        haveMessage = true;
                    }
                }

                if (!haveMessage) {
                    const QVariantMap pulseMap = map.value(QString::fromLatin1("pulse")).toMap();
                    const QString pulseOutput = pulseMap.value(QString::fromLatin1("outputValue")).toString();
                    const QString pulseTime = pulseMap.value(QString::fromLatin1("timeStamp")).toString();
                    if (!pulseOutput.isEmpty()) {
                        if (pulseTime.isEmpty()) {
                            msgCandidate = QString::fromLatin1("JSON pulse: %1").arg(pulseOutput);
                        } else {
                            msgCandidate = QString::fromLatin1("JSON pulse: %1 @ %2").arg(pulseOutput, pulseTime);
                        }
                        haveMessage = true;
                    }
                }

                if (!haveMessage && !map.isEmpty()) {
                    const QStringList mapKeys = map.keys();
                    msgCandidate = QString::fromLatin1("JSON object keys: %1").arg(joinStrings(mapKeys, QString::fromLatin1(", ")));
                    haveMessage = true;
                }
            } else if (result.type() == QVariant::List) {
                const QVariantList list = result.toList();
                msgCandidate = QString::fromLatin1("JSON array received (%1 items)").arg(list.size());
                haveMessage = true;
            } else {
                msgCandidate = QString::fromLatin1("JSON value parsed (%1)").arg(QString::fromLatin1(result.typeName()));
                haveMessage = true;
            }

            if (!haveMessage) {
                msgCandidate = QString::fromLatin1("JSON response was empty.");
            }

            ok = true;
            msg = msgCandidate;
            logLine(msg);
        }
    }

    setJsonRunning(false);
    emit jsonTestFinished(ok, msg);
}

void TlsChecker::onTimeout()
{
    if (!m_reply)
        return;

    disconnect(m_reply, 0, this, 0);
    m_reply->abort();
    m_reply->deleteLater();
    m_reply = 0;
    const QString msg = QString::fromLatin1("ERROR: Timeout while waiting for response");
    logLine(msg);
    if (m_nam) {
        m_nam->deleteLater();
        m_nam = 0;
    }

    setRunning(false);
    emit finished(false, msg);
}

void TlsChecker::onJsonTimeout()
{
    if (!m_jsonReply)
        return;

    disconnect(m_jsonReply, 0, this, 0);
    m_jsonReply->abort();
    m_jsonReply->deleteLater();
    m_jsonReply = 0;
    if (m_jsonNam) {
        m_jsonNam->deleteLater();
        m_jsonNam = 0;
    }

    const QString msg = QString::fromLatin1("ERROR: JSON request timed out");
    logLine(msg);

    setJsonRunning(false);
    emit jsonTestFinished(false, msg);
}

void TlsChecker::onJsonSslErrors(const QList<QSslError> &errors)
{
    if (!m_jsonReply)
        return;

    QStringList messages;
    for (int i = 0; i < errors.size(); ++i) {
        messages.append(errors.at(i).errorString());
    }
    logLine(QString::fromLatin1("JSON request SSL errors: %1").arg(joinStrings(messages, QString::fromLatin1("; "))));
    m_jsonReply->ignoreSslErrors();
}
