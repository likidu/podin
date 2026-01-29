TEMPLATE = app
TARGET = Podin

# Qt 4.x modules
QT += core gui network declarative sql
symbian:LIBS += -lhal

CONFIG -= debug_and_release
CONFIG += debug
CONFIG(debug, debug|release) { CONFIG += console }

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

    sqldrivers.path = /resource/qt/plugins/sqldrivers
    sqldrivers.files = $$[QT_INSTALL_PLUGINS]/sqldrivers/qsqlite.dll
    DEPLOYMENT += sqldrivers
}

SOURCES += \
    src/main.cpp \
    src/ArtworkCacheManager.cpp \
    src/MemoryMonitor.cpp \
    src/PodcastIndexClient.cpp \
    src/StreamUrlResolver.cpp \
    src/TlsChecker.cpp \
    src/StorageManager.cpp

HEADERS += \
    src/ArtworkCacheManager.h \
    src/MemoryMonitor.h \
    src/PodcastIndexClient.h \
    src/PodcastIndexConfig.h \
    src/StreamUrlResolver.h \
    src/TlsChecker.h \
    src/ApiConfig.h \
    src/StorageManager.h

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
    qml/PodinPageStackWindow.qml \
    qml/AudioFacade.qml
