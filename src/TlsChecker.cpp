#include "TlsChecker.h"

#include <QtCore/QTextStream>
#include <QtCore/QUrl>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QSslSocket>

TlsChecker::TlsChecker(QObject *parent)
    : QObject(parent)
    , m_nam(0)
    , m_reply(0)
    , m_running(false)
{
    m_timeout.setSingleShot(true);
    connect(&m_timeout, SIGNAL(timeout()), this, SLOT(onTimeout()));
}

bool TlsChecker::isRunning() const
{
    return m_running;
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
