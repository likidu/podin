#pragma once

#include <QtCore/QLatin1String>
#include <QtCore/QString>

namespace AppConfig {

// App name used in folder paths
static const char *const kAppName = "Podin";

// Base data directories (tried in priority order)
static const char *const kMemoryCardBase = "E:/Podin";
static const char *const kPhoneBase      = "C:/Data/Podin";

// Subdirectories
static const char *const kLogsSubdir     = "logs";

} // namespace AppConfig
