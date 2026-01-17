TEMPLATE = app
TARGET = playerpage-test
CONFIG += qt console testcase
CONFIG -= app_bundle
CONFIG -= debug_and_release
CONFIG += release
QT += core gui declarative multimedia testlib
SOURCES += tst_playerpage.cpp
