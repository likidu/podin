TEMPLATE = app
TARGET = Podin

# Qt 4.x modules
QT += core gui network declarative sql

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

SOURCES += \
    src/main.cpp \
    src/PodcastIndexClient.cpp \
    src/TlsChecker.cpp \
    src/StorageManager.cpp

HEADERS += \
    src/PodcastIndexClient.h \
    src/PodcastIndexConfig.h \
    src/TlsChecker.h \
    src/ApiConfig.h \
    src/StorageManager.h

RESOURCES += \
    qml/qml.qrc

OTHER_FILES += \
    qml/SearchPage.qml \
    qml/PodcastDetailPage.qml \
    qml/EpisodesPage.qml \
    qml/PlayerPage.qml \
    qml/PlaybackController.qml \
    qml/SubscriptionsPage.qml \
    qml/SettingsPage.qml \
    qml/PodinPageStackWindow.qml \
    qml/AudioFacade.qml
