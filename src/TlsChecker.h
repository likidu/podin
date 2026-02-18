#ifndef TLSCHECKER_H
#define TLSCHECKER_H

#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QSslSocket>

class TlsChecker : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)
public:
    explicit TlsChecker(QObject *parent = 0);

    bool isRunning() const;

public slots:
    void startCheck();

signals:
    void finished(bool ok, const QString &message);
    void runningChanged();

private slots:
    void onReplyFinished();
    void onTimeout();

private:
    void logLine(const QString &s);
    void setRunning(bool running);

    QNetworkAccessManager *m_nam;
    QNetworkReply *m_reply;
    QTimer m_timeout;
    bool m_running;
};

#endif // TLSCHECKER_H
