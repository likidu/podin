import QtQuick 1.1
import com.nokia.symbian 1.1

Item {
    id: bar

    property QtObject monitor: memoryMonitor
    property int barHeight: 6
    property bool showText: true

    width: parent ? parent.width : 200
    height: showText ? (barHeight + 18) : barHeight

    function usedPercent() {
        if (!monitor || monitor.totalBytes <= 0) {
            return 0;
        }
        var used = monitor.usedBytes;
        if (used < 0) {
            used = 0;
        }
        var percent = Math.round((used * 100) / monitor.totalBytes);
        if (percent < 0) {
            percent = 0;
        }
        if (percent > 100) {
            percent = 100;
        }
        return percent;
    }

    function formatBytes(bytes) {
        if (!bytes || bytes <= 0) {
            return "0 MB";
        }
        var mb = Math.round(bytes / (1024 * 1024));
        if (mb < 1) {
            var kb = Math.round(bytes / 1024);
            return kb + " KB";
        }
        return mb + " MB";
    }

    function labelText() {
        if (!monitor || monitor.totalBytes <= 0) {
            return "RAM: n/a";
        }
        return "RAM used: " + usedPercent() + "% (" +
               formatBytes(monitor.usedBytes) + " / " +
               formatBytes(monitor.totalBytes) + ")";
    }

    Rectangle {
        id: track
        width: parent.width
        height: bar.barHeight
        radius: bar.barHeight / 2
        color: "#2d3a57"
    }

    Rectangle {
        id: fill
        height: track.height
        radius: track.radius
        color: "#5a7cff"
        width: {
            var percent = bar.usedPercent();
            return Math.round(track.width * percent / 100);
        }
    }

    Text {
        id: label
        anchors.top: track.bottom
        anchors.topMargin: 4
        width: parent.width
        text: bar.labelText()
        color: "#9fb0d3"
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        visible: bar.showText
    }
}
