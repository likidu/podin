import QtQuick 1.1
import com.nokia.symbian 1.1

Page {
    id: page
    objectName: "SettingsPage"
    orientationLock: PageOrientation.LockPortrait

    property QtObject playback: null

    function sleepTimerLabel() {
        var mins = storage ? storage.sleepTimerMinutes : 0;
        if (mins <= 0) {
            return qsTr("Sleep timer: Off");
        }
        return qsTr("Sleep timer: %1 min").arg(mins);
    }

    function setSleepMinutes(mins) {
        if (!storage) {
            return;
        }
        storage.sleepTimerMinutes = mins;
    }

    Rectangle {
        anchors.fill: parent
        color: "#171f33"
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
                        text: qsTr("Volume: %1%").arg(storage ? storage.volumePercent : 50)
                        font.pixelSize: 14
                        color: "#b7c4e0"
                    }

                    Slider {
                        id: volumeSlider
                        width: parent.width
                        minimumValue: 0
                        maximumValue: 100
                        value: storage ? storage.volumePercent : 50
                        onValueChanged: {
                            if (!storage || !volumeSlider.pressed) {
                                return;
                            }
                            var v = Math.round(value);
                            storage.volumePercent = v;
                            if (audioEngine) {
                                audioEngine.volume = v / 100.0;
                            }
                        }
                    }
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

            Column {
                width: parent.width
                spacing: 10

                Text {
                    width: parent.width
                    text: qsTr("Sleep Mode")
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

                    Button {
                        width: parent.width
                        text: page.sleepTimerLabel()
                        onClicked: {
                            if (!storage) {
                                return;
                            }
                            if (storage.sleepTimerMinutes > 0) {
                                storage.sleepTimerMinutes = 0;
                            } else {
                                storage.sleepTimerMinutes = 30;
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4
                        visible: storage ? storage.sleepTimerMinutes > 0 : false

                        Text {
                            width: parent.width
                            text: qsTr("Power off device after:")
                            font.pixelSize: 14
                            color: "#b7c4e0"
                        }

                        Row {
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: [15, 30, 60, 90, 120]

                                Button {
                                    width: (parent.width - 4 * 4) / 5
                                    text: modelData
                                    checked: storage ? storage.sleepTimerMinutes === modelData : false
                                    onClicked: page.setSleepMinutes(modelData)
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: qsTr("When enabled, the device will power off after the selected time during playback.")
                        font.pixelSize: 12
                        color: "#9fb0d3"
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
