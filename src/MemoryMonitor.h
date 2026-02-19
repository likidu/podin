#ifndef MEMORYMONITOR_H
#define MEMORYMONITOR_H

#include <QtCore/QObject>
#include <QtCore/QTimer>

class MemoryMonitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(qint64 totalBytes READ totalBytes NOTIFY memoryChanged)
    Q_PROPERTY(qint64 freeBytes READ freeBytes NOTIFY memoryChanged)
    Q_PROPERTY(qint64 usedBytes READ usedBytes NOTIFY memoryChanged)
    Q_PROPERTY(int usedPercent READ usedPercent NOTIFY memoryChanged)
    Q_PROPERTY(bool isMemoryLow READ isMemoryLow NOTIFY memoryChanged)
    Q_PROPERTY(bool isMemoryCritical READ isMemoryCritical NOTIFY memoryChanged)

public:
    explicit MemoryMonitor(QObject *parent = 0);

    qint64 totalBytes() const;
    qint64 freeBytes() const;
    qint64 usedBytes() const;
    int usedPercent() const;
    bool isMemoryLow() const;
    bool isMemoryCritical() const;

    // Thresholds in bytes
    static const qint64 LowMemoryThreshold = 10 * 1024 * 1024;      // 10 MB
    static const qint64 CriticalMemoryThreshold = 5 * 1024 * 1024;  // 5 MB

    Q_INVOKABLE void powerOff();

public slots:
    void refresh();

signals:
    void memoryChanged();

private:
    void updateValues(qint64 totalBytes, qint64 freeBytes);

    QTimer m_timer;
    qint64 m_totalBytes;
    qint64 m_freeBytes;
};

#endif // MEMORYMONITOR_H
