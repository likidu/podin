#ifndef STREAMURLRESOLVER_H
#define STREAMURLRESOLVER_H

#include <QObject>
#include <QUrl>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QSslError>

class StreamUrlResolver : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QUrl sourceUrl READ sourceUrl WRITE setSourceUrl NOTIFY sourceUrlChanged)
    Q_PROPERTY(QUrl resolvedUrl READ resolvedUrl NOTIFY resolvedUrlChanged)
    Q_PROPERTY(bool resolving READ isResolving NOTIFY resolvingChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)

public:
    explicit StreamUrlResolver(QObject *parent = 0);
    ~StreamUrlResolver();

    QUrl sourceUrl() const;
    void setSourceUrl(const QUrl &url);

    QUrl resolvedUrl() const;
    bool isResolving() const;
    QString errorString() const;

    Q_INVOKABLE void resolve(const QUrl &url);
    Q_INVOKABLE void abort();

signals:
    void sourceUrlChanged();
    void resolvedUrlChanged();
    void resolvingChanged();
    void errorStringChanged();
    void resolved(const QUrl &finalUrl);
    void error(const QString &message);

private slots:
    void onFinished();
    void onMetaDataChanged();
    void onSslErrors(const QList<QSslError> &errors);

private:
    void followRedirect(const QUrl &url);
    void finishWithUrl(const QUrl &url);
    void finishWithError(const QString &message);
    QUrl simplifyUrl(const QUrl &url, int depth = 0);

    QNetworkAccessManager *m_nam;
    QNetworkReply *m_reply;
    QUrl m_sourceUrl;
    QUrl m_resolvedUrl;
    bool m_resolving;
    bool m_handledInMetaData;  // Prevents race between onMetaDataChanged and onFinished
    QString m_errorString;
    int m_redirectCount;
    static const int MaxRedirects = 10;
};

#endif // STREAMURLRESOLVER_H
