#ifndef TLSCHECKER_H
#define TLSCHECKER_H

#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtCore/QList>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QSslSocket>
#include <QtNetwork/QSslError>

class TlsChecker : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)
    Q_PROPERTY(bool jsonRunning READ isJsonRunning NOTIFY jsonRunningChanged)
public:
    explicit TlsChecker(QObject *parent = 0);

    bool isRunning() const;
    bool isJsonRunning() const;

public slots:
    void startCheck();
    void startJsonTest();

signals:
    void finished(bool ok, const QString &message);
    void runningChanged();

    void jsonTestFinished(bool ok, const QString &message);
    void jsonRunningChanged();

private slots:
    void onReplyFinished();
    void onTimeout();

    void onJsonReplyFinished();
    void onJsonTimeout();
    void onJsonSslErrors(const QList<QSslError> &errors);

private:
    void logLine(const QString &s);
    void setRunning(bool running);
    void setJsonRunning(bool running);

    QNetworkAccessManager *m_nam;
    QNetworkReply *m_reply;
    QTimer m_timeout;
    bool m_running;

    QNetworkAccessManager *m_jsonNam;
    QNetworkReply *m_jsonReply;
    QTimer m_jsonTimeout;
    bool m_jsonRunning;
};

#endif // TLSCHECKER_H
