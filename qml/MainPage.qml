import QtQuick 1.1
import com.nokia.symbian 1.1

Page {
    id: page
    orientationLock: PageOrientation.LockPortrait

    property string statusText: qsTr("Tap to start the TLS 1.2 check.")
    property bool lastOk: true

    signal requestPlayer()

    Rectangle {
        id: background
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#2f3f6d" }
            GradientStop { position: 1.0; color: "#12192b" }
        }
    }

    Column {
        id: content
        z: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 20
        width: parent.width - 64

        Button {
            id: runButton
            width: content.width
            text: tlsChecker.running ? qsTr("Checking...") : qsTr("Run TLS Check")
            enabled: !tlsChecker.running
            onClicked: {
                page.lastOk = true;
                page.statusText = qsTr("Running TLS check...");
                tlsChecker.startCheck();
            }
        }

        Button {
            id: jsonButton
            width: content.width
            text: tlsChecker.jsonRunning ? qsTr("Testing JSON...") : qsTr("Test JSON")
            enabled: !tlsChecker.jsonRunning
            onClicked: {
                page.lastOk = true;
                page.statusText = qsTr("Running JSON request...");
                tlsChecker.startJsonTest();
            }
        }

        Button {
            id: playerButton
            width: content.width
            text: qsTr("Test Player")
            onClicked: {
                page.lastOk = true;
                page.statusText = qsTr("Opening test player...");
                page.requestPlayer();
            }
        }

        Item {
            width: content.width
            height: 40

            Rectangle {
                id: spinner
                anchors.centerIn: parent
                width: 28
                height: 28
                radius: 14
                color: "transparent"
                border.width: 2
                border.color: "#9ebcf5"
                visible: tlsChecker.running
                smooth: true

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: "#e8f1ff"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                }

                NumberAnimation on rotation {
                    running: tlsChecker.running
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }
        }

        Text {
            id: statusLabel
            width: content.width
            text: page.statusText
            color: page.lastOk ? platformStyle.colorNormalLight : "#ffd6d9"
            font.pixelSize: 18
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Connections {
        target: tlsChecker
        onFinished: {
            page.lastOk = ok;
            page.statusText = message;
        }
        onRunningChanged: {
            if (tlsChecker.running) {
                page.lastOk = true;
                page.statusText = qsTr("Running TLS check...");
            }
        }
        onJsonTestFinished: {
            page.lastOk = ok;
            page.statusText = message;
        }
        onJsonRunningChanged: {
            if (tlsChecker.jsonRunning) {
                page.lastOk = true;
                page.statusText = qsTr("Running JSON request...");
            }
        }
    }
}
