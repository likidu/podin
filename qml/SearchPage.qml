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
        color: "#202c4c"
    }

    function startSearch() {
        page.hasSearched = true;
        page.lastSearchTerm = page.normalizedSearchTerm(searchField.text);
        if (page.lastSearchTerm.length > 0 && storage) {
            storage.addSearchHistory(page.lastSearchTerm);
        }
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

    function proxyImageUrl(item) {
        if (item.guid && item.imageUrlHash) {
            return "https://podcastimage.liya.design/hash/"
                + item.imageUrlHash + "/feed/" + item.guid + "/32";
        }
        return item.image ? item.image : "";
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

            Item {
                width: parent.width
                height: 48

                TextField {
                    id: searchField
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 20
                    text: qsTr("gcores")
                    placeholderText: qsTr("     Search podcasts")
                    platformLeftMargin: 32
                    platformRightMargin: 36
                    inputMethodHints: Qt.ImhNoPredictiveText
                    Keys.onReturnPressed: page.startSearch()
                }

                Image {
                    id: searchIcon
                    source: "qrc:/qml/gfx/icon-search-dark.svg"
                    width: 20
                    height: 20
                    smooth: true
                    sourceSize.width: 20
                    sourceSize.height: 20
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: 0.6
                }

                Item {
                    id: clearButton
                    width: 36
                    height: 36
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchField.text.length > 0

                    Image {
                        width: 16
                        height: 16
                        anchors.centerIn: parent
                        source: "qrc:/qml/gfx/icon-x-dark.svg"
                        sourceSize.width: 16
                        sourceSize.height: 16
                        smooth: true
                        opacity: 0.8
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: searchField.text = ""
                    }
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
                visible: debugMode && page.imageSizeCount > 0
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
            height: searchTextCol.height + 16
            radius: 6
            color: index % 2 === 0 ? "#1a2233" : "#1f2a3d"

            Rectangle {
                id: searchThumb
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 8
                anchors.topMargin: 8
                width: 48
                height: 48
                radius: 4
                color: "#2b354a"
                border.width: 1
                border.color: "#3b4660"

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: storage && storage.enableArtworkLoading ? page.proxyImageUrl(modelData) : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    cache: true
                    sourceSize.width: 44
                    sourceSize.height: 44
                    visible: storage && storage.enableArtworkLoading && source.toString().length > 0
                    onStatusChanged: {
                        if (status === Image.Ready) {
                            page.recordImageSize(modelData.feedId, implicitWidth, implicitHeight);
                        }
                    }
                }
            }

            Column {
                id: searchTextCol
                anchors.left: searchThumb.right
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                anchors.topMargin: 8
                spacing: 4

                Text {
                    width: parent.width
                    text: modelData.title
                    color: platformStyle.colorNormalLight
                    font.pixelSize: 18
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    width: parent.width
                    text: modelData.description ? modelData.description : ""
                    color: "#b7c4e0"
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
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

    Item {
        id: historyPanel
        anchors.top: headerBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 8
        anchors.bottomMargin: 16
        visible: apiClient.podcasts.length === 0 && !apiClient.busy && storage && storage.searchHistory.length > 0

        Column {
            id: historyHeader
            width: parent.width
            spacing: 6

            Text {
                width: parent.width
                text: qsTr("Previous Searches")
                font.pixelSize: 18
                color: platformStyle.colorNormalLight
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#3a4a6a"
            }
        }

        ListView {
            id: historyList
            anchors.top: historyHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: 8
            spacing: 4
            clip: true
            model: storage ? storage.searchHistory : []

            delegate: Rectangle {
                width: historyList.width
                height: 40
                radius: 4
                color: index % 2 === 0 ? "#1a2233" : "#1f2a3d"

                Text {
                    anchors.left: parent.left
                    anchors.right: historyDeleteBtn.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    text: modelData.term
                    color: "#b7c4e0"
                    font.pixelSize: 16
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                MouseArea {
                    anchors.left: parent.left
                    anchors.right: historyDeleteBtn.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    onClicked: {
                        searchField.text = modelData.term;
                        page.startSearch();
                    }
                }

                Item {
                    id: historyDeleteBtn
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 40
                    z: 1

                    Image {
                        width: 14
                        height: 14
                        anchors.centerIn: parent
                        source: "qrc:/qml/gfx/icon-x.svg"
                        sourceSize.width: 14
                        sourceSize.height: 14
                        smooth: true
                        opacity: 0.6
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            var term = modelData.term;
                            storage.removeSearchHistory(term);
                        }
                    }
                }
            }
        }
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
        onSearchHistoryChanged: {
            historyList.model = storage.searchHistory;
        }
    }

    Timer {
        id: cleanupTimer
        interval: 300
        repeat: false
        onTriggered: {
            page.resetSearchState();
            page.hasSearched = false;
            apiClient.clearPodcasts();
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Inactive) {
            cleanupTimer.restart();
        }
    }
}
