#pragma once

#include <QtCore/QByteArray>
#include <QtCore/QString>
#include <QtNetwork/QNetworkRequest>

namespace ApiConfig {

static const char *const kBaseUrl = "https://api.xiaoyuzhoufm.com/v1/";
static const char *const kSendCodeEndpoint = "auth/sendCode";

static const char *const kUserAgent = "Podin/1.0 (JSON Test)";
static const char *const kAcceptHeader = "application/json";
static const char *const kDeviceProperties = "{\"idfa\":\"00000000-0000-0000-0000-000000000000\",\"idfv\":\"39095101-CEB8-43F7-92CF-8F17970CAEF5\"}";
static const char *const kDeviceId = "13B00C45-734F-4D5F-A8D3-C21AE2C4D814";
static const char *const kAppBuildNo = "2749";
static const char *const kCustomDev = "";
static const char *const kBundleId = "app.podcast.cosmos";
static const char *const kOnlineHost = "api.xiaoyuzhoufm.com";
static const char *const kAppVersion = "2.94.0";

inline QByteArray &accessTokenStorage()
{
    static QByteArray value;
    return value;
}

inline QByteArray &refreshTokenStorage()
{
    static QByteArray value;
    return value;
}

inline void setTokens(const QByteArray &accessToken, const QByteArray &refreshToken)
{
    accessTokenStorage() = accessToken;
    refreshTokenStorage() = refreshToken;
}

inline void clearTokens()
{
    accessTokenStorage().clear();
    refreshTokenStorage().clear();
}

inline void applyDefaultHeaders(QNetworkRequest &request)
{
    request.setRawHeader("User-Agent", QByteArray(kUserAgent));
    request.setRawHeader("Accept", QByteArray(kAcceptHeader));
    request.setRawHeader("x-jike-device-properties", QByteArray(kDeviceProperties));
    request.setRawHeader("x-jike-device-id", QByteArray(kDeviceId));
    request.setRawHeader("App-BuildNo", QByteArray(kAppBuildNo));
    request.setRawHeader("x-custom-xiaoyuzhou-app-dev", QByteArray(kCustomDev));
    request.setRawHeader("BundleID", QByteArray(kBundleId));
    request.setRawHeader("X-Online-Host", QByteArray(kOnlineHost));
    request.setRawHeader("App-Version", QByteArray(kAppVersion));

    const QByteArray access = accessTokenStorage();
    if (!access.isEmpty()) {
        request.setRawHeader("x-jike-access-token", access);
    }

    const QByteArray refresh = refreshTokenStorage();
    if (!refresh.isEmpty()) {
        request.setRawHeader("x-jike-refresh-token", refresh);
    }
}

inline QString buildUrl(const char *endpoint)
{
    QString base = QString::fromLatin1(kBaseUrl);
    if (!base.endsWith('/')) {
        base.append('/');
    }
    QString path = QString::fromLatin1(endpoint);
    if (path.startsWith('/')) {
        path.remove(0, 1);
    }
    return base + path;
}

} // namespace ApiConfig

