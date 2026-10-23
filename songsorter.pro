TEMPLATE = app
TARGET = SongSorter

QT += quick network multimedia
CONFIG += c++17

SOURCES += src/app/main.cpp \
           src/app/QmlLiveReload.cpp \
           src/core/SongScanner.cpp \
           src/core/SongModel.cpp \
           src/core/TjaValidator.cpp \
           src/ai/DeepSeekClient.cpp \
           src/services/AudioPlayer.cpp \
           src/services/AppleMusicClient.cpp \
           src/utils/Logger.cpp \
           src/utils/ThreadPool.cpp \
           src/utils/ToastManager.cpp

HEADERS += src/core/SongInfo.h \
           src/app/QmlLiveReload.h \
           src/core/ChartData.h \
           src/core/TjaValidator.h \
           src/core/SongScanner.h \
           src/core/SongModel.h \
           src/ai/DeepSeekClient.h \
           src/services/AudioPlayer.h \
           src/services/AppleMusicClient.h \
           src/utils/Logger.h \
           src/utils/ThreadPool.h \
           src/utils/ToastManager.h

DISTFILES += main.qml \
             ui/panels/ToastNotification.qml
