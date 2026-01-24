#pragma once

#include <QtCore/QByteArray>
#include <QtCore/QtGlobal>
#include <QtCore/QString>
#include <QtCore/QUrl>

namespace PodcastIndexConfig {

static const char *const kBaseUrl = "https://api.podcastindex.org/api/1.0";
static const char *const kUserAgent = "Podin/0.1 (Symbian; Qt4)";
static const char *const kApiKeyEnvName = "PODIN_API_KEY";
static const char *const kApiSecretEnvName = "PODIN_API_SECRET";

// Optional built-in defaults for local testing. Leave empty to require env vars.
static const char *const kApiKeyDefault = "UZCP45SS4RCDYP4EUBKT";
static const char *const kApiSecretDefault = "zzAGdXQwKgpUzvgsbWFDw^HfJ5RKS7VX$ACCEBgb";

inline QByteArray readEnvValue(const char *name)
{
    return qgetenv(name);
}

inline QByteArray apiKey()
{
    const QByteArray envValue = readEnvValue(kApiKeyEnvName);
    if (!envValue.isEmpty()) {
        return envValue;
    }
    return QByteArray(kApiKeyDefault);
}

inline QByteArray apiSecret()
{
    const QByteArray envValue = readEnvValue(kApiSecretEnvName);
    if (!envValue.isEmpty()) {
        return envValue;
    }
    return QByteArray(kApiSecretDefault);
}

inline QUrl buildUrl(const QString &endpoint)
{
    QString base = QString::fromLatin1(kBaseUrl);
    if (!base.endsWith('/')) {
        base.append('/');
    }
    QString path = endpoint;
    if (path.startsWith('/')) {
        path.remove(0, 1);
    }
    return QUrl(base + path);
}

} // namespace PodcastIndexConfig
