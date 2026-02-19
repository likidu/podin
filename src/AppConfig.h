#pragma once

#include <QtCore/QLatin1String>
#include <QtCore/QString>

namespace AppConfig {

// App name and version
static const char *const kAppName    = "Podin";
static const char *const kAppVersion = "0.2.0";

// Base data directories (tried in priority order)
static const char *const kMemoryCardBase = "E:/Podin";
static const char *const kPhoneBase      = "C:/Data/Podin";

// Subdirectories
static const char *const kLogsSubdir     = "logs";

} // namespace AppConfig
