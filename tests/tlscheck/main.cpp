#include <QtCore/QCoreApplication>
#include <QtCore/QStringList>
#include <QtCore/QTimer>
#include <QtCore/QTextStream>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkRequest>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QSslSocket>

static void logLine(const QString &s) {
    QTextStream ts(stdout);
    ts << s << '\n';
}

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);

    // Keep plugin lookups local to the app folder to avoid mismatched SDK plugins
    QCoreApplication::setLibraryPaths(QStringList() << QCoreApplication::applicationDirPath());

    // Basic SSL support introspection
    logLine(QString("supportsSsl: %1").arg(QSslSocket::supportsSsl() ? "true" : "false"));
    // Some Qt 4.x versions don't expose these methods; guard by version
#if (QT_VERSION >= 0x040800)
    logLine(QString("sslLibraryBuildVersion: %1").arg(QSslSocket::sslLibraryBuildVersionString()));
    logLine(QString("sslLibraryRuntimeVersion: %1").arg(QSslSocket::sslLibraryVersionString()));
#else
    logLine("sslLibrary*VersionString APIs not available on this Qt version.");
#endif

    if (!QSslSocket::supportsSsl()) {
        logLine("ERROR: SSL not supported by QtNetwork at runtime.");
        return 2;
    }

    // Pick an endpoint that only allows TLS 1.2 to prove capability
    // badssl.com hosts a port that requires TLSv1.2
    const QUrl url(QString::fromLatin1("https://tls-v1-2.badssl.com:1012/"));
    QNetworkAccessManager nam;
    QNetworkRequest req(url);
    req.setRawHeader("User-Agent", "tlscheck/1.0");

    QNetworkReply *reply = nam.get(req);
    QObject::connect(reply, SIGNAL(sslErrors(const QList<QSslError>&)), reply, SLOT(ignoreSslErrors()));

    int exitCode = 1; // default to failure
    QObject::connect(reply, SIGNAL(finished()), &app, SLOT(quit()));
    QObject::connect(&nam, SIGNAL(finished(QNetworkReply*)), &app, SLOT(quit()));

    // Hard timeout to avoid hanging
    QTimer timeout;
    timeout.setSingleShot(true);
    QObject::connect(&timeout, SIGNAL(timeout()), &app, SLOT(quit()));
    timeout.start(15000);

    // Run event loop
    app.exec();

    if (reply->error() == QNetworkReply::NoError) {
        logLine("TLS 1.2 handshake and HTTP GET succeeded.");
        exitCode = 0;
    } else {
        logLine(QString("ERROR: Request failed: %1").arg(reply->errorString()));
        exitCode = 1;
    }

    reply->deleteLater();
    return exitCode;
}
