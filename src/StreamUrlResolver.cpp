#include "StreamUrlResolver.h"
#include "AppConfig.h"
#include <QDebug>

StreamUrlResolver::StreamUrlResolver(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
    , m_reply(0)
    , m_resolving(false)
    , m_handledInMetaData(false)
    , m_redirectCount(0)
{
}

StreamUrlResolver::~StreamUrlResolver()
{
    abort();
}

QUrl StreamUrlResolver::sourceUrl() const
{
    return m_sourceUrl;
}

void StreamUrlResolver::setSourceUrl(const QUrl &url)
{
    if (m_sourceUrl != url) {
        m_sourceUrl = url;
        emit sourceUrlChanged();
    }
}

QUrl StreamUrlResolver::resolvedUrl() const
{
    return m_resolvedUrl;
}

bool StreamUrlResolver::isResolving() const
{
    return m_resolving;
}

QString StreamUrlResolver::errorString() const
{
    return m_errorString;
}

void StreamUrlResolver::resolve(const QUrl &url)
{
    abort();

    m_sourceUrl = url;
    emit sourceUrlChanged();

    m_resolvedUrl = QUrl();
    emit resolvedUrlChanged();

    m_errorString.clear();
    emit errorStringChanged();

    m_redirectCount = 0;

    if (!url.isValid() || url.isEmpty()) {
        finishWithError("Invalid URL");
        return;
    }

    m_resolving = true;
    emit resolvingChanged();

    followRedirect(url);
}

void StreamUrlResolver::abort()
{
    if (m_reply) {
        m_reply->abort();
        m_reply->deleteLater();
        m_reply = 0;
    }
    if (m_resolving) {
        m_resolving = false;
        emit resolvingChanged();
    }
}

void StreamUrlResolver::followRedirect(const QUrl &url)
{
    if (m_redirectCount >= MaxRedirects) {
        finishWithError("Too many redirects");
        return;
    }

    // Reset flag for new request
    m_handledInMetaData = false;

    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", QByteArray("Mozilla/5.0 (SymbianOS) Podin/") + AppConfig::kAppVersion);
    // Some servers don't handle HEAD well, use GET but we'll abort after headers
    m_reply = m_nam->get(request);
    connect(m_reply, SIGNAL(finished()), this, SLOT(onFinished()));
    connect(m_reply, SIGNAL(metaDataChanged()), this, SLOT(onMetaDataChanged()));
    connect(m_reply, SIGNAL(sslErrors(const QList<QSslError> &)),
            this, SLOT(onSslErrors(const QList<QSslError> &)));
}

void StreamUrlResolver::onSslErrors(const QList<QSslError> &errors)
{
    if (!m_reply) {
        return;
    }
    Q_UNUSED(errors);
    // Ignore SSL errors to allow playback from servers with certificate issues
    m_reply->ignoreSslErrors();
}

void StreamUrlResolver::onMetaDataChanged()
{
    if (!m_reply) {
        return;
    }

    int statusCode = m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    // If we got a redirect, handle it immediately without waiting for body
    if (statusCode >= 300 && statusCode < 400) {
        QUrl redirectUrl = m_reply->attribute(QNetworkRequest::RedirectionTargetAttribute).toUrl();
        if (redirectUrl.isEmpty()) {
            QByteArray locationHeader = m_reply->rawHeader("Location");
            if (!locationHeader.isEmpty()) {
                redirectUrl = QUrl::fromEncoded(locationHeader);
            }
        }

        if (!redirectUrl.isEmpty()) {
            if (redirectUrl.isRelative()) {
                redirectUrl = m_reply->url().resolved(redirectUrl);
            }
            
            // Mark as handled to prevent onFinished from processing
            m_handledInMetaData = true;
            
            // Abort current request and follow redirect
            m_reply->abort();
            m_reply->deleteLater();
            m_reply = 0;
            
            m_redirectCount++;
            followRedirect(redirectUrl);
            return;
        }
    }
    
    // If we got a 200 OK, we can finish early
    if (statusCode >= 200 && statusCode < 300) {
        QUrl finalUrl = m_reply->url();
        
        // Mark as handled to prevent onFinished from processing
        m_handledInMetaData = true;
        
        // Abort download, we only needed the final URL
        m_reply->abort();
        m_reply->deleteLater();
        m_reply = 0;
        
        finishWithUrl(finalUrl);
    }
}

void StreamUrlResolver::onFinished()
{
    if (!m_reply) {
        return;
    }

    // If already handled in onMetaDataChanged, skip processing
    if (m_handledInMetaData) {
        // Reply was already cleaned up in onMetaDataChanged
        return;
    }

    QNetworkReply *reply = m_reply;
    m_reply = 0;

    // Check if it was aborted (we handled it in metaDataChanged)
    if (reply->error() == QNetworkReply::OperationCanceledError) {
        reply->deleteLater();
        return;
    }

    if (reply->error() != QNetworkReply::NoError) {
        QString errMsg = reply->errorString();
        reply->deleteLater();
        finishWithError(errMsg);
        return;
    }

    int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    if (statusCode >= 300 && statusCode < 400) {
        QUrl redirectUrl = reply->attribute(QNetworkRequest::RedirectionTargetAttribute).toUrl();
        if (redirectUrl.isEmpty()) {
            QByteArray locationHeader = reply->rawHeader("Location");
            if (!locationHeader.isEmpty()) {
                redirectUrl = QUrl::fromEncoded(locationHeader);
            }
        }

        reply->deleteLater();

        if (redirectUrl.isEmpty()) {
            finishWithError("Redirect with no Location header");
            return;
        }

        if (redirectUrl.isRelative()) {
            redirectUrl = reply->url().resolved(redirectUrl);
        }

        m_redirectCount++;
        followRedirect(redirectUrl);
        return;
    }

    QUrl finalUrl = reply->url();
    reply->deleteLater();

    if (statusCode >= 200 && statusCode < 300) {
        finishWithUrl(finalUrl);
    } else {
        finishWithError(QString("HTTP error %1").arg(statusCode));
    }
}

QUrl StreamUrlResolver::simplifyUrl(const QUrl &url, int depth)
{
    // Prevent stack overflow from malicious or misconfigured nested fallback_url chains
    const int MaxSimplifyDepth = 5;
    if (depth >= MaxSimplifyDepth) {
        qDebug() << "StreamUrlResolver: Max simplify depth reached, returning URL as-is";
        return url;
    }

    QString urlStr = url.toString();
    QString path = url.path();
    bool isAudioFile = path.endsWith(".mp3", Qt::CaseInsensitive) || 
                       path.endsWith(".m4a", Qt::CaseInsensitive) ||
                       path.endsWith(".aac", Qt::CaseInsensitive);
    
    // If URL is reasonably short, use it as-is
    if (urlStr.length() <= 512) {
        return url;
    }

    // Check for fallback_url parameter (common in podcast CDNs)
    QString query = url.encodedQuery();
    int fallbackIdx = query.indexOf("fallback_url=");
    if (fallbackIdx != -1) {
        QString fallbackPart = query.mid(fallbackIdx + 13); // skip "fallback_url="
        // Find end of this parameter (next & or end of string)
        int endIdx = fallbackPart.indexOf('&');
        if (endIdx != -1) {
            fallbackPart = fallbackPart.left(endIdx);
        }
        // URL decode
        QString fallbackUrl = QUrl::fromPercentEncoding(fallbackPart.toUtf8());
        if (!fallbackUrl.isEmpty() && (fallbackUrl.startsWith("http://") || fallbackUrl.startsWith("https://"))) {
            return simplifyUrl(QUrl(fallbackUrl), depth + 1);
        }
    }
    
    // For audio files, try to keep only essential signing/auth params
    // Many CDNs (CloudFront, Akamai, Triton, etc.) use similar signing parameters
    if (isAudioFile) {
        QUrl simplified = url;
        QList<QPair<QString, QString> > newParams;
        QList<QPair<QString, QString> > oldParams = url.queryItems();
        
        for (int i = 0; i < oldParams.size(); ++i) {
            const QString &key = oldParams.at(i).first;
            // Keep signing/auth parameters from various CDNs:
            // CloudFront: Expires, Signature, Key-Pair-Id
            // Akamai: hdnea, hdnts, __gda__, __token__
            // Generic: token, auth, sig, hash, key, expires, exp
            if (key == "Expires" || key == "expires" || key == "exp" ||
                key == "Signature" || key == "signature" || key == "sig" ||
                key == "Key-Pair-Id" ||
                key == "__gda__" || key == "__token__" ||
                key == "hdnea" || key == "hdnts" ||
                key == "token" || key == "auth" || key == "hash" || key == "key" ||
                key == "Policy") {
                newParams.append(oldParams.at(i));
            }
        }
        
        // If we found auth params, use simplified URL with just those
        if (!newParams.isEmpty()) {
            simplified.setQueryItems(newParams);
            if (simplified.toString().length() < urlStr.length()) {
                return simplified;
            }
        }

        // If URL is extremely long (> 2000 chars) with no auth params, try without query
        if (urlStr.length() > 2000 && newParams.isEmpty()) {
            simplified.setEncodedQuery(QByteArray());
            return simplified;
        }
    }
    
    // Return original if we can't simplify
    return url;
}

void StreamUrlResolver::finishWithUrl(const QUrl &url)
{
    QUrl finalUrl = simplifyUrl(url);

    // Keep original protocol - let PlaybackController handle fallbacks
    // Symbian's SSL/TLS can have issues with some servers

    m_resolvedUrl = finalUrl;
    emit resolvedUrlChanged();

    m_resolving = false;
    emit resolvingChanged();

    emit resolved(finalUrl);
}

void StreamUrlResolver::finishWithError(const QString &message)
{
    qDebug() << "StreamUrlResolver: Error:" << message;

    m_errorString = message;
    emit errorStringChanged();

    m_resolving = false;
    emit resolvingChanged();

    emit error(message);
}
