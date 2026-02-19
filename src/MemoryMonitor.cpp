#include "MemoryMonitor.h"

#ifdef Q_OS_SYMBIAN
#include <hal.h>
#include <hal_data.h>
#include <e32hal.h>
#endif

MemoryMonitor::MemoryMonitor(QObject *parent)
    : QObject(parent)
    , m_totalBytes(0)
    , m_freeBytes(0)
{
    connect(&m_timer, SIGNAL(timeout()), this, SLOT(refresh()));
    m_timer.start(2000);
    refresh();
}

qint64 MemoryMonitor::totalBytes() const
{
    return m_totalBytes;
}

qint64 MemoryMonitor::freeBytes() const
{
    return m_freeBytes;
}

qint64 MemoryMonitor::usedBytes() const
{
    if (m_totalBytes <= 0) {
        return 0;
    }
    qint64 used = m_totalBytes - m_freeBytes;
    if (used < 0) {
        used = 0;
    }
    return used;
}

int MemoryMonitor::usedPercent() const
{
    if (m_totalBytes <= 0) {
        return 0;
    }
    const qint64 used = usedBytes();
    const qint64 percent = (used * 100) / m_totalBytes;
    if (percent < 0) {
        return 0;
    }
    if (percent > 100) {
        return 100;
    }
    return static_cast<int>(percent);
}

bool MemoryMonitor::isMemoryLow() const
{
    // On non-Symbian platforms, we don't have real memory values
    if (m_totalBytes <= 0) {
        return false;
    }
    return m_freeBytes < LowMemoryThreshold;
}

bool MemoryMonitor::isMemoryCritical() const
{
    // On non-Symbian platforms, we don't have real memory values
    if (m_totalBytes <= 0) {
        return false;
    }
    return m_freeBytes < CriticalMemoryThreshold;
}

void MemoryMonitor::powerOff()
{
#ifdef Q_OS_SYMBIAN
    qDebug("MemoryMonitor: powering off device");
    UserHal::SwitchOff();
#else
    qDebug("MemoryMonitor: powerOff() called (no-op on simulator)");
#endif
}

void MemoryMonitor::refresh()
{
#ifdef Q_OS_SYMBIAN
    TInt total = 0;
    TInt free = 0;
    if (HAL::Get(HALData::EMemoryRAM, total) != KErrNone) {
        total = 0;
    }
    if (HAL::Get(HALData::EMemoryRAMFree, free) != KErrNone) {
        free = 0;
    }
    if (total < 0) {
        total = 0;
    }
    if (free < 0) {
        free = 0;
    }
    updateValues(total, free);
#else
    updateValues(m_totalBytes, m_freeBytes);
#endif
}

void MemoryMonitor::updateValues(qint64 totalBytes, qint64 freeBytes)
{
    if (totalBytes < 0) {
        totalBytes = 0;
    }
    if (freeBytes < 0) {
        freeBytes = 0;
    }
    if (totalBytes > 0 && freeBytes > totalBytes) {
        freeBytes = totalBytes;
    }
    if (totalBytes == m_totalBytes && freeBytes == m_freeBytes) {
        return;
    }
    m_totalBytes = totalBytes;
    m_freeBytes = freeBytes;
    emit memoryChanged();
}
