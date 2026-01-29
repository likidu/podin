import QtQuick 1.1
import com.nokia.symbian 1.1

Page {
    id: page
    objectName: "SearchPage"
    orientationLock: PageOrientation.LockPortrait

    property QtObject playback: null
    property bool hasSearched: false
    property string lastSearchTerm: ""
    property int searchOffset: 0
    property int searchPageSize: 10
    property int searchMaxResults: 100
    property int lastBatchCount: 0
    property int lastTotalCount: 0
    property bool canLoadMore: false
    property bool isLoadingMore: false
    property real restoreContentY: 0
    property variant imageSizeSeen: ({})
    property int imageSizeCount: 0
    property int imageTotalWidth: 0
    property int imageTotalHeight: 0
    property int imageTotalPixels: 0
    property string imageSizeSummary: ""

    function resetSearchState() {
        page.searchOffset = 0;
        page.lastBatchCount = 0;
        page.lastTotalCount = 0;
        page.canLoadMore = false;
        page.isLoadingMore = false;
        page.restoreContentY = 0;
        page.resetImageStats();
    }

    function resetImageStats() {
        page.imageSizeSeen = ({});
        page.imageSizeCount = 0;
        page.imageTotalWidth = 0;
        page.imageTotalHeight = 0;
        page.imageTotalPixels = 0;
        page.imageSizeSummary = "";
    }

    function normalizedSearchTerm(value) {
        if (!value) {
            return "";
        }
        return value.replace(/^\s+|\s+$/g, "");
    }

    Rectangle {
        id: background
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#2f3f6d" }
            GradientStop { position: 1.0; color: "#12192b" }
        }
    }

    function startSearch() {
        page.hasSearched = true;
        page.lastSearchTerm = page.normalizedSearchTerm(searchField.text);
        page.resetSearchState();
        apiClient.search(page.lastSearchTerm);
    }

    function loadMore() {
        if (apiClient.busy || page.lastSearchTerm.length === 0) {
            return;
        }
        page.isLoadingMore = true;
        page.restoreContentY = podcastList.contentY;
        page.searchOffset = apiClient.podcasts.length;
        var nextMax = page.searchOffset + page.searchPageSize;
        if (page.searchMaxResults > 0 && nextMax > page.searchMaxResults) {
            nextMax = page.searchMaxResults;
        }
        if (nextMax <= apiClient.podcasts.length) {
            page.isLoadingMore = false;
            page.canLoadMore = false;
            return;
        }
        apiClient.searchMore(page.lastSearchTerm, nextMax);
    }

    function recordImageSize(feedId, width, height) {
        if (!storage || !storage.enableArtworkLoading) {
            return;
        }
        if (!feedId || width <= 0 || height <= 0) {
            return;
        }
        if (!page.imageSizeSeen) {
            page.imageSizeSeen = ({});
        }
        if (page.imageSizeSeen[feedId]) {
            return;
        }
        page.imageSizeSeen[feedId] = true;
        page.imageSizeCount += 1;
        page.imageTotalWidth += width;
        page.imageTotalHeight += height;
        page.imageTotalPixels += (width * height);
        var avgW = Math.round(page.imageTotalWidth / page.imageSizeCount);
        var avgH = Math.round(page.imageTotalHeight / page.imageSizeCount);
        var avgBytes = Math.round((page.imageTotalPixels / page.imageSizeCount) * 4 / 1024);
        page.imageSizeSummary = "Avg cover: " + avgW + "x" + avgH + " px (~" + avgBytes + " KB decoded)";
    }

    Timer {
        id: restoreScrollTimer
        interval: 1
        running: false
        repeat: false
        onTriggered: podcastList.contentY = page.restoreContentY
    }

    function openPodcastDetails(podcast) {
        if (!pageStack || !podcast) {
            return;
        }
        var params = {
            feedId: podcast.feedId,
            podcastGuid: podcast.guid ? podcast.guid : "",
            podcastTitle: podcast.title ? podcast.title : "",
            tools: page.tools,
            playback: page.playback
        };
        pageStack.push(Qt.resolvedUrl("PodcastDetailPage.qml"), params);
    }

    Item {
        id: headerBar
        z: 1
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: headerContent.height + 24

        Rectangle {
            anchors.fill: parent
            color: "#1a2236"
            opacity: 0.95
        }

        Rectangle {
            width: parent.width
            height: 1
            anchors.bottom: parent.bottom
            color: "#2d3a57"
        }

        Column {
            id: headerContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 10

            Text {
                width: parent.width
                text: qsTr("Podcast Index")
                font.pixelSize: 22
                color: platformStyle.colorNormalLight
                horizontalAlignment: Text.AlignHCenter
            }

            MemoryBar {
                width: parent.width
                monitor: memoryMonitor
            }

            Row {
                width: parent.width
                spacing: 6

                TextField {
                    id: searchField
                    width: parent.width - clearButton.width - 6
                    text: qsTr("gcores")
                    placeholderText: qsTr("Search podcasts")
                    inputMethodHints: Qt.ImhNoPredictiveText
                    Keys.onReturnPressed: page.startSearch()
                }

                Button {
                    id: clearButton
                    width: 32
                    height: searchField.height
                    text: qsTr("x")
                    enabled: searchField.text.length > 0
                    onClicked: searchField.text = ""
                }
            }

            Button {
                id: searchButton
                width: parent.width
                text: apiClient.busy ? qsTr("Searching...") : qsTr("Search")
                enabled: !apiClient.busy
                onClicked: page.startSearch()
            }

            BusyIndicator {
                running: apiClient.busy
                visible: apiClient.busy
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                width: parent.width
                text: apiClient.errorMessage
                visible: apiClient.errorMessage.length > 0
                color: "#ffd6d9"
                font.pixelSize: 16
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                width: parent.width
                text: page.imageSizeSummary
                visible: page.imageSizeCount > 0
                color: "#9fb0d3"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    ListView {
        id: podcastList
        anchors.top: headerBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 8
        anchors.bottomMargin: 16
        spacing: 8
        model: apiClient.podcasts

        footer: Item {
            width: podcastList.width
            height: loadMoreButton.visible ? loadMoreButton.height + 8 : 0

            Button {
                id: loadMoreButton
                width: parent.width
                text: apiClient.busy ? qsTr("Loading...") : qsTr("Load More")
                enabled: !apiClient.busy
                visible: page.hasSearched && apiClient.podcasts.length > 0 && page.canLoadMore
                onClicked: page.loadMore()
            }
        }

        delegate: Rectangle {
            width: podcastList.width
            height: 72
            radius: 6
            color: index % 2 === 0 ? "#1a2233" : "#1f2a3d"

            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 12

                Rectangle {
                    width: 48
                    height: 48
                    radius: 4
                    color: "#2b354a"
                    border.width: 1
                    border.color: "#3b4660"

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: storage && storage.enableArtworkLoading ? modelData.image : ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                        cache: false
                        sourceSize.width: 44
                        sourceSize.height: 44
                        visible: storage && storage.enableArtworkLoading && modelData.image && modelData.image.length > 0
                        onStatusChanged: {
                            if (status === Image.Ready) {
                                page.recordImageSize(modelData.feedId, implicitWidth, implicitHeight);
                            }
                        }
                    }
                }

                Column {
                    width: parent.width - 70
                    spacing: 4

                    Text {
                        text: modelData.title
                        color: platformStyle.colorNormalLight
                        font.pixelSize: 18
                        elide: Text.ElideRight
                    }

                    Text {
                        text: modelData.description ? modelData.description : ""
                        color: "#b7c4e0"
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: page.openPodcastDetails(modelData)
            }
        }
    }

    Text {
        anchors.centerIn: podcastList
        text: qsTr("No results.")
        color: platformStyle.colorNormalLight
        font.pixelSize: 18
        visible: page.hasSearched && !apiClient.busy && apiClient.podcasts.length === 0 && apiClient.errorMessage.length === 0
    }

    Connections {
        target: apiClient
        onPodcastsChanged: {
            var total = apiClient.podcasts.length;
            if (page.searchOffset === 0) {
                page.lastBatchCount = total;
            } else {
                page.lastBatchCount = total - page.lastTotalCount;
                if (page.lastBatchCount < 0) {
                    page.lastBatchCount = total;
                }
            }
            page.lastTotalCount = total;
            page.canLoadMore = page.lastBatchCount >= page.searchPageSize &&
                               (!page.searchMaxResults || total < page.searchMaxResults);
            if (page.isLoadingMore) {
                page.isLoadingMore = false;
                restoreScrollTimer.stop();
                restoreScrollTimer.start();
            }
        }
    }

    Connections {
        target: apiClient
        onBusyChanged: {
            if (!apiClient.busy) {
                page.isLoadingMore = false;
            }
        }
    }

    Connections {
        target: storage
        onEnableArtworkLoadingChanged: {
            if (!storage.enableArtworkLoading) {
                page.resetImageStats();
            }
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Inactive) {
            page.resetSearchState();
            page.hasSearched = false;
            apiClient.clearPodcasts();
        }
    }
}
