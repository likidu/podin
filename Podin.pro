TEMPLATE = app
TARGET = Podin
VERSION = 0.2.0

# Qt 4.x modules
QT += core gui network declarative sql
CONFIG += mobility
MOBILITY += multimedia
symbian:LIBS += -lhal

CONFIG -= debug_and_release
CONFIG(debug, debug|release) {
    CONFIG += console
    DEFINES += PODIN_DEBUG
}

# Place all build artifacts inside build directory
DESTDIR = $$OUT_PWD
OBJECTS_DIR = $$OUT_PWD/obj
MOC_DIR = $$OUT_PWD/moc
RCC_DIR = $$OUT_PWD/rcc
UI_DIR = $$OUT_PWD/ui

INCLUDEPATH += src
include($$PWD/lib/qjson/qjson.pri)
DEFINES += QJSON_STATIC

symbian {
    TARGET.EPOCHEAPSIZE = 0x020000 0x2000000
    # Required capabilities for network streaming audio
    TARGET.CAPABILITY += NetworkServices ReadUserData WriteUserData UserEnvironment

    # Note: SQLite driver is built into QtSql.dll on Symbian, no separate plugin deployment needed

    # Create the private data directory during installation
    # This ensures the app can write its database there
    DEPLOYMENT.installer_header = 0x2002CCCF

    # Deploy an empty placeholder file to create the private directory
    emptyfile.sources = data/.placeholder
    emptyfile.path = /private/ea711e8d
    DEPLOYMENT += emptyfile
}

SOURCES += \
    src/main.cpp \
    src/ArtworkCacheManager.cpp \
    src/MemoryMonitor.cpp \
    src/PodcastIndexClient.cpp \
    src/StreamUrlResolver.cpp \
    src/TlsChecker.cpp \
    src/StorageManager.cpp \
    src/AudioEngine.cpp

HEADERS += \
    src/ArtworkCacheManager.h \
    src/MemoryMonitor.h \
    src/PodcastIndexClient.h \
    src/PodcastIndexConfig.h \
    src/StreamUrlResolver.h \
    src/TlsChecker.h \
    src/AppConfig.h \
    src/StorageManager.h \
    src/AudioEngine.h

RESOURCES += \
    qml/qml.qrc

OTHER_FILES += \
    qml/SearchPage.qml \
    qml/MemoryBar.qml \
    qml/PodcastDetailPage.qml \
    qml/EpisodesPage.qml \
    qml/PlayerPage.qml \
    qml/PlaybackController.qml \
    qml/SubscriptionsPage.qml \
    qml/SettingsPage.qml \
    qml/PodinPageStackWindow.qml
