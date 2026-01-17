#include <QtTest/QtTest>
#include <QtCore/QFileInfo>
#include <QtCore/QScopedPointer>
#include <QtCore/QFile>
#include <QtCore/QDir>
#include <QtCore/QVariant>
#include <QtCore/QUrl>
#include <QtDeclarative/QDeclarativeEngine>
#include <QtDeclarative/QDeclarativeComponent>
#include <QtDeclarative/qdeclarative.h>

namespace {
static void appendIfDir(QStringList &list, const QString &path)
{
    if (path.isEmpty())
        return;
    QDir dir(path);
    if (!dir.exists())
        return;
    const QString abs = dir.absolutePath();
    foreach (const QString &existing, list) {
        if (QString::compare(existing, abs, Qt::CaseInsensitive) == 0)
            return;
    }
    list.prepend(abs);
}
}

class StubAudio : public QObject
{
    Q_OBJECT
    Q_ENUMS(Status State)
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ muted WRITE setMuted NOTIFY mutedChanged)
    Q_PROPERTY(Status status READ status WRITE setStatus NOTIFY statusChanged)
    Q_PROPERTY(State state READ state WRITE setState NOTIFY stateChanged)
    Q_PROPERTY(int position READ position WRITE setPosition NOTIFY positionChanged)

public:
    enum Status { NoMedia = 0, Loading, Loaded, Buffering, Stalled, Buffered, EndOfMedia, InvalidMedia };
    enum State { PlayingState = 0, PausedState = 1, StoppedState = 2 };

    explicit StubAudio(QObject *parent = 0)
        : QObject(parent)
        , m_volume(1.0)
        , m_muted(false)
        , m_status(NoMedia)
        , m_state(StoppedState)
        , m_position(0)
    {
    }

    QUrl source() const { return m_source; }
    void setSource(const QUrl &url) { if (m_source == url) return; m_source = url; emit sourceChanged(); }

    qreal volume() const { return m_volume; }
    void setVolume(qreal value) { if (m_volume == value) return; m_volume = value; emit volumeChanged(); }

    bool muted() const { return m_muted; }
    void setMuted(bool value) { if (m_muted == value) return; m_muted = value; emit mutedChanged(); }

    Status status() const { return m_status; }
    void setStatus(Status value) { if (m_status == value) return; m_status = value; emit statusChanged(); }

    State state() const { return m_state; }
    void setState(State value) { if (m_state == value) return; m_state = value; emit stateChanged(); }

    int position() const { return m_position; }
    void setPosition(int value) { if (m_position == value) return; m_position = value; emit positionChanged(); }

    Q_INVOKABLE void play() { setState(PlayingState); setStatus(Loaded); }
    Q_INVOKABLE void pause() { setState(PausedState); }
    Q_INVOKABLE void stop() { setState(StoppedState); setStatus(NoMedia); setPosition(0); }

signals:
    void sourceChanged();
    void volumeChanged();
    void mutedChanged();
    void statusChanged();
    void stateChanged();
    void positionChanged();
    void error(const QString &errorString);

private:
    QUrl m_source;
    qreal m_volume;
    bool m_muted;
    Status m_status;
    State m_state;
    int m_position;
};

class PlayerPageTest : public QObject
{
    Q_OBJECT

public:
    PlayerPageTest()
        : m_page(0)
    {
    }

private slots:
    void initTestCase();
    void cleanupTestCase();
    void init();
    void cleanup();

    void defaults();
    void statusIncludesStreamUrl();
    void statusAppendsExtraNote();
    void selectStreamSwitchesUrl();
    void streamUrlChangeUpdatesSelection();
    void stopPlaybackReportedStates();

private:
    QString m_repoRoot;
    QString m_qmlDir;
    QScopedPointer<QDeclarativeEngine> m_engine;
    QScopedPointer<QDeclarativeComponent> m_component;
    QObject *m_page;
};

void PlayerPageTest::initTestCase()
{
    QDir dir(QCoreApplication::applicationDirPath());
    const QString buildDir = dir.absolutePath();
    QVERIFY2(dir.cdUp(), qPrintable(QString::fromLatin1("Failed to cdUp from %1").arg(buildDir)));
    const QString buildRoot = dir.absolutePath();
    QVERIFY2(dir.cdUp(), qPrintable(QString::fromLatin1("Failed to locate repo root from %1").arg(buildRoot)));
    m_repoRoot = dir.absolutePath();
    m_qmlDir = dir.absoluteFilePath(QString::fromLatin1("qml"));
    QVERIFY2(QDir(m_qmlDir).exists(), qPrintable(QString::fromLatin1("Missing qml directory at %1").arg(m_qmlDir)));

    qmlRegisterType<StubAudio>("QtMultimediaKitStub", 1, 0, "Audio");

    m_engine.reset(new QDeclarativeEngine);
    QStringList importPaths = m_engine->importPathList();
    appendIfDir(importPaths, m_qmlDir);
    m_engine->setImportPathList(importPaths);

    QStringList libraryPaths = QCoreApplication::libraryPaths();
    appendIfDir(libraryPaths, QCoreApplication::applicationDirPath());
    const QString simulatorRoot = QString::fromLocal8Bit(qgetenv("QTSIMULATOR_ROOT"));
    if (!simulatorRoot.isEmpty()) {
        QDir root(simulatorRoot);
        if (root.exists()) {
            appendIfDir(libraryPaths, root.absoluteFilePath(QString::fromLatin1("Qt/mingw/plugins")));
            appendIfDir(libraryPaths, root.absoluteFilePath(QString::fromLatin1("QtMobility/mingw/plugins")));
            appendIfDir(importPaths, root.absoluteFilePath(QString::fromLatin1("Qt/mingw/imports")));
            appendIfDir(importPaths, root.absoluteFilePath(QString::fromLatin1("QtMobility/mingw/imports")));
        }
    }
    QCoreApplication::setLibraryPaths(libraryPaths);
    m_engine->setImportPathList(importPaths);

    const QString playerPath = QDir(m_qmlDir).absoluteFilePath(QString::fromLatin1("PlayerPage.qml"));
    QVERIFY2(QFileInfo(playerPath).exists(), qPrintable(QString::fromLatin1("Missing PlayerPage.qml at %1").arg(playerPath)));

    QFile playerFile(playerPath);
    QVERIFY2(playerFile.open(QIODevice::ReadOnly | QIODevice::Text), qPrintable(QString::fromLatin1("Failed to open %1").arg(playerPath)));
    QByteArray qmlSource = playerFile.readAll();
    playerFile.close();

    const QByteArray multimediaImport("import QtMultimediaKit 1.1");
    QVERIFY2(qmlSource.contains(multimediaImport), "PlayerPage.qml missing QtMultimediaKit import");
    qmlSource.replace(multimediaImport, QByteArray("import QtMultimediaKitStub 1.0"));

    m_component.reset(new QDeclarativeComponent(m_engine.data()));
    m_component->setData(qmlSource, QUrl::fromLocalFile(playerPath));
    QVERIFY2(m_component->isReady(), qPrintable(m_component->errorString()));
}

void PlayerPageTest::cleanupTestCase()
{
    m_component.reset();
    m_engine.reset();
}

void PlayerPageTest::init()
{
    m_page = m_component->create();
    QVERIFY2(m_page, qPrintable(m_component->errorString()));
    QCoreApplication::processEvents();
}

void PlayerPageTest::cleanup()
{
    delete m_page;
    m_page = 0;
}

void PlayerPageTest::defaults()
{
    QVERIFY(m_page);
    QCOMPARE(m_page->property("selectedStreamId").toString(), QString::fromLatin1("mp3"));
    const QString mp3Url = m_page->property("mp3StreamUrl").toUrl().toString();
    QCOMPARE(m_page->property("streamUrl").toUrl().toString(), mp3Url);

    const QString status = m_page->property("statusMessage").toString();
    QVERIFY2(status.startsWith(QString::fromLatin1("Stream URL: %1").arg(mp3Url)), qPrintable(status));
}

void PlayerPageTest::statusIncludesStreamUrl()
{
    QVERIFY(QMetaObject::invokeMethod(m_page, "updateStatus", Q_ARG(QVariant, QVariant(QString()))));
    const QString status = m_page->property("statusMessage").toString();
    const QString stream = m_page->property("streamUrl").toUrl().toString();
    QVERIFY2(status.startsWith(QString::fromLatin1("Stream URL: %1").arg(stream)), qPrintable(status));
}

void PlayerPageTest::statusAppendsExtraNote()
{
    const QString note = QString::fromLatin1("Custom message.");
    QVERIFY(QMetaObject::invokeMethod(m_page, "updateStatus", Q_ARG(QVariant, QVariant(note))));
    const QString status = m_page->property("statusMessage").toString();
    QVERIFY2(status.contains(QString::fromLatin1("\n%1").arg(note)), qPrintable(status));
}

void PlayerPageTest::selectStreamSwitchesUrl()
{
    const QString targetId = QString::fromLatin1("m4a");
    QVERIFY(QMetaObject::invokeMethod(m_page, "selectStream", Q_ARG(QVariant, QVariant(targetId))));
    QCOMPARE(m_page->property("selectedStreamId").toString(), targetId);
    const QString m4aUrl = m_page->property("m4aStreamUrl").toUrl().toString();
    QCOMPARE(m_page->property("streamUrl").toUrl().toString(), m4aUrl);
}

void PlayerPageTest::streamUrlChangeUpdatesSelection()
{
    const QVariant m4aUrl = m_page->property("m4aStreamUrl");
    QVERIFY(m4aUrl.isValid());
    QVERIFY(m_page->setProperty("streamUrl", m4aUrl));
    QCoreApplication::processEvents();
    QCOMPARE(m_page->property("selectedStreamId").toString(), QString::fromLatin1("m4a"));
    const QString status = m_page->property("statusMessage").toString();
    QVERIFY2(status.contains(QString::fromLatin1("Stream URL: %1").arg(m4aUrl.toUrl().toString())), qPrintable(status));
}

void PlayerPageTest::stopPlaybackReportedStates()
{
    // Scenario 1: was active -> expect "Playback stopped."
    m_page->setProperty("isPlaying", true);
    m_page->setProperty("pendingPlay", false);
    QVERIFY(QMetaObject::invokeMethod(m_page, "stopPlayback", Q_ARG(QVariant, QVariant())));
    QString status = m_page->property("statusMessage").toString();
    QVERIFY2(status.contains(QString::fromLatin1("Playback stopped.")), qPrintable(status));

    // Scenario 2: idle -> expect "Ready to stream."
    m_page->setProperty("isPlaying", false);
    m_page->setProperty("pendingPlay", false);
    QVERIFY(QMetaObject::invokeMethod(m_page, "stopPlayback", Q_ARG(QVariant, QVariant())));
    status = m_page->property("statusMessage").toString();
    QVERIFY2(status.contains(QString::fromLatin1("Ready to stream.")), qPrintable(status));
}

QTEST_MAIN(PlayerPageTest)
#include "tst_playerpage.moc"
