#include <QtGui/QApplication>
#include <QtCore/QCoreApplication>
#include <QtCore/QStringList>
#include <QtCore/QSize>
#include <QtCore/QUrl>
#include <QtCore/QLibraryInfo>
#include <QtCore/QDir>
#include <QtCore/QDateTime>
#include <QtCore/QFile>
#include <QtCore/QBasicTimer>
#include <QtCore/QMutex>
#include <QtCore/QMutexLocker>
#include <QtCore/QQueue>
#include <QtCore/QTextStream>
#include <QtCore/QTimerEvent>
#include <QtCore/QDebug>
#include <QtGui/QDesktopServices>
#include <QtDeclarative/QDeclarativeView>
#include <QtDeclarative/QDeclarativeContext>
#include <QtDeclarative/QDeclarativeEngine>

#include "ArtworkCacheManager.h"
#include "MemoryMonitor.h"
#include "PodcastIndexClient.h"
#include "StorageManager.h"
#include "StreamUrlResolver.h"
#include "TlsChecker.h"

namespace {
QTextStream &infoStream()
{
    static QTextStream ts(stdout);
    return ts;
}

QFile *gLogFile = 0;
QMutex gLogMutex;
QQueue<QString> gLogQueue;
bool gLogDropping = false;
const int kMaxLogQueue = 200;

QString resolveLogPath()
{
    QStringList candidates;
    if (QDir(QString::fromLatin1("E:/")).exists()) {
        candidates << QString::fromLatin1("E:/Podin/logs");
    }
    candidates << QString::fromLatin1("C:/Data/Podin/logs");

    const QString dataLocation = QDesktopServices::storageLocation(QDesktopServices::DataLocation);
    if (!dataLocation.isEmpty()) {
        candidates << (dataLocation + QLatin1String("/logs"));
    }

    for (int i = 0; i < candidates.size(); ++i) {
        const QString base = candidates.at(i);
        QDir dir(base);
        if (!dir.exists() && !dir.mkpath(QLatin1String("."))) {
            continue;
        }
        return dir.filePath(QLatin1String("podin.log"));
    }

    return QString();
}

void ensureLogFile()
{
    if (gLogFile) {
        return;
    }
    const QString path = resolveLogPath();
    if (path.isEmpty()) {
        return;
    }
    QFile *file = new QFile(path);
    if (!file->open(QIODevice::Append | QIODevice::Text)) {
        delete file;
        return;
    }
    gLogFile = file;
}

void flushLogQueue()
{
    QQueue<QString> batch;
    {
        QMutexLocker locker(&gLogMutex);
        if (gLogQueue.isEmpty()) {
            return;
        }
        batch = gLogQueue;
        gLogQueue.clear();
    }

    ensureLogFile();
    if (!gLogFile) {
        return;
    }

    QTextStream ts(gLogFile);
    while (!batch.isEmpty()) {
        ts << batch.dequeue() << '\n';
    }
    ts.flush();
}

void messageOutput(QtMsgType type, const char *msg)
{
    QString level;
    switch (type) {
    case QtDebugMsg:
        level = QLatin1String("DEBUG");
        break;
    case QtWarningMsg:
        level = QLatin1String("WARN");
        break;
    case QtCriticalMsg:
        level = QLatin1String("CRIT");
        break;
    case QtFatalMsg:
        level = QLatin1String("FATAL");
        break;
    default:
        level = QLatin1String("INFO");
        break;
    }

    QString line = QDateTime::currentDateTime().toString(QLatin1String("yyyy-MM-dd hh:mm:ss"));
    line += QLatin1String(" ");
    line += level;
    line += QLatin1String(" ");
    line += QString::fromLocal8Bit(msg);

#ifndef Q_OS_SYMBIAN
    // Print to stdout for terminal visibility (Simulator only)
    QTextStream out(stdout);
    out << line << '\n';
    out.flush();
#endif

    {
        QMutexLocker locker(&gLogMutex);
        if (gLogQueue.size() >= kMaxLogQueue) {
            gLogQueue.dequeue();
            gLogDropping = true;
        }
        gLogQueue.enqueue(line);
        if (gLogDropping) {
            gLogQueue.enqueue(QLatin1String("WARN Log queue overflow, dropping old entries."));
            gLogDropping = false;
        }
    }

    if (type == QtFatalMsg) {
        abort();
    }
}

class LogPump : public QObject
{
public:
    explicit LogPump(QObject *parent = 0)
        : QObject(parent)
    {
        m_timer.start(1500, this);
    }

protected:
    void timerEvent(QTimerEvent *event)
    {
        if (event->timerId() == m_timer.timerId()) {
            flushLogQueue();
        }
        QObject::timerEvent(event);
    }

private:
    QBasicTimer m_timer;
};

void logPaths(const char *label, const QStringList &paths)
{
    QTextStream &ts = infoStream();
    ts << label << '\n';
    for (int i = 0; i < paths.size(); ++i) {
        ts << "  [" << i << "] " << paths.at(i) << '\n';
    }
    ts.flush();
}

bool pathEquals(const QString &a, const QString &b)
{
    return a.compare(b, Qt::CaseInsensitive) == 0;
}

void appendIfDir(QStringList &list, const QString &path)
{
    if (path.isEmpty())
        return;
    QDir dir(path);
    if (!dir.exists())
        return;
    const QString absPath = dir.absolutePath();
    for (int i = 0; i < list.size(); ++i) {
        if (pathEquals(list.at(i), absPath))
            return;
    }
    list.append(absPath);
}

QString simulatorRoot()
{
    static QString cached;
    static bool cachedSet = false;
    if (cachedSet)
        return cached;

    QStringList guesses;
    const QString envRoot = QString::fromLocal8Bit(qgetenv("QTSIMULATOR_ROOT"));
    if (!envRoot.isEmpty())
        guesses.append(QDir::cleanPath(envRoot));

    guesses << QString::fromLatin1("C:/Symbian/QtSDK/Simulator")
            << QString::fromLatin1("D:/Symbian/QtSDK/Simulator")
            << QString::fromLatin1("C:/QtSDK/Simulator")
            << QString::fromLatin1("D:/QtSDK/Simulator");

    QDir probe(QApplication::applicationDirPath());
    for (int i = 0; i < 6; ++i) {
        if (!probe.cdUp())
            break;
        if (probe.exists("Qt") && probe.exists("QtMobility")) {
            guesses.prepend(probe.absolutePath());
            break;
        }
    }

    for (int i = 0; i < guesses.size(); ++i) {
        QDir dir(guesses.at(i));
        if (dir.exists() && dir.exists("Qt") && dir.exists("QtMobility")) {
            cached = dir.absolutePath();
            cachedSet = true;
            return cached;
        }
    }

    cachedSet = true;
    cached.clear();
    return cached;
}

QString simulatorQtDir()
{
    const QString root = simulatorRoot();
    if (root.isEmpty())
        return QString();
    return QDir(root).absoluteFilePath(QString::fromLatin1("Qt/mingw"));
}

QString simulatorMobilityDir()
{
    const QString root = simulatorRoot();
    if (root.isEmpty())
        return QString();
    return QDir(root).absoluteFilePath(QString::fromLatin1("QtMobility/mingw"));
}

void prependToPathEnv(const QString &path)
{
    if (path.isEmpty())
        return;
    QDir dir(path);
    if (!dir.exists())
        return;
    const QString absPath = dir.absolutePath();
    QString current = QString::fromLocal8Bit(qgetenv("PATH"));
    if (current.contains(absPath, Qt::CaseInsensitive))
        return;
    current.prepend(absPath + QLatin1Char(';'));
    qputenv("PATH", current.toLocal8Bit());
}

void ensureRuntimeLibraries()
{
    const QString qtDir = simulatorQtDir();
    if (!qtDir.isEmpty())
        prependToPathEnv(QDir(qtDir).absoluteFilePath(QString::fromLatin1("bin")));
    const QString mobilityDir = simulatorMobilityDir();
    if (!mobilityDir.isEmpty())
        prependToPathEnv(QDir(mobilityDir).absoluteFilePath(QString::fromLatin1("lib")));
}

QStringList buildPluginPaths()
{
    QStringList paths;
    appendIfDir(paths, QApplication::applicationDirPath());

    const QString qtDir = simulatorQtDir();
    if (!qtDir.isEmpty())
        appendIfDir(paths, QDir(qtDir).absoluteFilePath(QString::fromLatin1("plugins")));

    const QString mobilityDir = simulatorMobilityDir();
    if (!mobilityDir.isEmpty())
        appendIfDir(paths, QDir(mobilityDir).absoluteFilePath(QString::fromLatin1("plugins")));

    const QStringList defaults = QCoreApplication::libraryPaths();
    for (int i = 0; i < defaults.size(); ++i) {
        const QString candidate = defaults.at(i);
        if (candidate.contains(QString::fromLatin1("qt-everywhere"), Qt::CaseInsensitive))
            continue;
        appendIfDir(paths, candidate);
    }

    return paths;
}

QStringList buildImportPaths(QDeclarativeEngine *engine)
{
    QStringList paths;
    appendIfDir(paths, QApplication::applicationDirPath());

    const QString qtDir = simulatorQtDir();
    if (!qtDir.isEmpty())
        appendIfDir(paths, QDir(qtDir).absoluteFilePath(QString::fromLatin1("imports")));

    const QString mobilityDir = simulatorMobilityDir();
    if (!mobilityDir.isEmpty())
        appendIfDir(paths, QDir(mobilityDir).absoluteFilePath(QString::fromLatin1("imports")));

    appendIfDir(paths, QApplication::applicationDirPath() + QString::fromLatin1("/imports"));

    if (engine) {
        const QStringList defaults = engine->importPathList();
        for (int i = 0; i < defaults.size(); ++i) {
            const QString candidate = defaults.at(i);
            if (candidate.contains(QString::fromLatin1("qt-everywhere"), Qt::CaseInsensitive))
                continue;
            appendIfDir(paths, candidate);
        }
    }

    return paths;
}

void applyPluginPaths()
{
    QStringList paths = buildPluginPaths();
    QCoreApplication::setLibraryPaths(paths);
    logPaths("[PLUGIN PATHS]", QCoreApplication::libraryPaths());
}

void applyImportPaths(QDeclarativeEngine *engine)
{
    if (!engine)
        return;
    QStringList paths = buildImportPaths(engine);
    engine->setImportPathList(paths);
    logPaths("[IMPORT PATHS]", engine->importPathList());
}
}

int main(int argc, char *argv[])
{
    QApplication::setGraphicsSystem("raster");
    QApplication app(argc, argv);
    qInstallMsgHandler(messageOutput);
    LogPump logPump(&app);
    qDebug("Podin starting...");
    flushLogQueue();

    ensureRuntimeLibraries();
    applyPluginPaths();

    PodcastIndexClient apiClient;
    StorageManager storage;
    ArtworkCacheManager artworkCache;
    MemoryMonitor memoryMonitor;
    StreamUrlResolver streamUrlResolver;
    TlsChecker tlsChecker;

    QDeclarativeView view;
    view.rootContext()->setContextProperty("apiClient", &apiClient);
    view.rootContext()->setContextProperty("storage", &storage);
    view.rootContext()->setContextProperty("artworkCache", &artworkCache);
    view.rootContext()->setContextProperty("memoryMonitor", &memoryMonitor);
    view.rootContext()->setContextProperty("streamUrlResolver", &streamUrlResolver);
    view.rootContext()->setContextProperty("tlsChecker", &tlsChecker);
    applyImportPaths(view.engine());

    view.setSource(QUrl("qrc:/qml/AppWindow.qml"));
    view.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    view.setWindowTitle(QObject::tr("Podin"));
    view.setMinimumSize(QSize(360, 640));
    view.setMaximumSize(QSize(480, 800));
    view.resize(360, 640);

    view.show();
    return app.exec();
}
