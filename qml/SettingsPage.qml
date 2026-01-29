import QtQuick 1.1
import com.nokia.symbian 1.1

Page {
    id: page
    objectName: "SettingsPage"
    orientationLock: PageOrientation.LockPortrait

    property QtObject playback: null

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1f2a43" }
            GradientStop { position: 1.0; color: "#0f1524" }
        }
    }

    Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.height + 32
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: content
            width: parent.width - 32
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 16
            spacing: 16

            Text {
                width: parent.width
                text: qsTr("Settings")
                font.pixelSize: 22
                color: platformStyle.colorNormalLight
                horizontalAlignment: Text.AlignHCenter
            }

            MemoryBar {
                width: parent.width
                monitor: memoryMonitor
            }

            Column {
                width: parent.width
                spacing: 10

                Text {
                    width: parent.width
                    text: qsTr("Player")
                    font.pixelSize: 18
                    color: platformStyle.colorNormalLight
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#3a4a6a"
                }

                Column {
                    width: parent.width
                    spacing: 6

                    Text {
                        width: parent.width
                        text: qsTr("Forward skip seconds: %1").arg(storage ? storage.forwardSkipSeconds : 30)
                        font.pixelSize: 14
                        color: "#b7c4e0"
                    }

                    Slider {
                        id: forwardSlider
                        width: parent.width
                        minimumValue: 5
                        maximumValue: 60
                        value: storage ? storage.forwardSkipSeconds : 30
                        onValueChanged: {
                            if (!storage || !forwardSlider.pressed) {
                                return;
                            }
                            storage.forwardSkipSeconds = Math.round(value);
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 6

                    Text {
                        width: parent.width
                        text: qsTr("Backward skip seconds: %1").arg(storage ? storage.backwardSkipSeconds : 15)
                        font.pixelSize: 14
                        color: "#b7c4e0"
                    }

                    Slider {
                        id: backwardSlider
                        width: parent.width
                        minimumValue: 2
                        maximumValue: 30
                        value: storage ? storage.backwardSkipSeconds : 15
                        onValueChanged: {
                            if (!storage || !backwardSlider.pressed) {
                                return;
                            }
                            storage.backwardSkipSeconds = Math.round(value);
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 10

                Text {
                    width: parent.width
                    text: qsTr("Artwork")
                    font.pixelSize: 18
                    color: platformStyle.colorNormalLight
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#3a4a6a"
                }

                Column {
                    width: parent.width
                    spacing: 6

                    Text {
                        width: parent.width
                        text: qsTr("Enable artwork loading in lists")
                        font.pixelSize: 14
                        color: "#b7c4e0"
                        wrapMode: Text.WordWrap
                    }

                    Button {
                        width: parent.width
                        text: storage && storage.enableArtworkLoading
                              ? qsTr("Artwork loading: On")
                              : qsTr("Artwork loading: Off")
                        onClicked: {
                            if (!storage) {
                                return;
                            }
                            storage.enableArtworkLoading = !storage.enableArtworkLoading;
                        }
                    }

                    Text {
                        width: parent.width
                        text: qsTr("Turn off to save memory. List thumbnails will show placeholders only.")
                        font.pixelSize: 12
                        color: "#9fb0d3"
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
