cmake_minimum_required(VERSION 3.21)
project(Slate VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Quick QuickControls2 OpenGL Network Svg Test)

# ---- libmpv -------------------------------------------------------------
# Windows: point MPV_DIR at an unpacked mpv-dev package (include/ + libmpv.dll.a + libmpv-2.dll).
# Linux/macOS: found through pkg-config.
set(MPV_DIR "" CACHE PATH "Folder containing include/mpv and libmpv import library")
add_library(libmpv INTERFACE)
if(MPV_DIR)
    find_library(MPV_LIBRARY NAMES mpv libmpv libmpv.dll.a PATHS "${MPV_DIR}" "${MPV_DIR}/lib" NO_DEFAULT_PATH REQUIRED)
    target_include_directories(libmpv INTERFACE "${MPV_DIR}/include")
    target_link_libraries(libmpv INTERFACE "${MPV_LIBRARY}")
else()
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)
    target_link_libraries(libmpv INTERFACE PkgConfig::MPV)
endif()

# ---- core library (no UI) so tests can link it -----------------------------
add_library(slatecore STATIC
    src/timecode.h src/timecode.cpp
    src/markermodel.h src/markermodel.cpp
    src/folderqueue.h src/folderqueue.cpp
)
target_include_directories(slatecore PUBLIC src)
target_link_libraries(slatecore PUBLIC Qt6::Core Qt6::Gui)

# ---- app --------------------------------------------------------------------
set(SLATE_RC "")
if(WIN32)
    # Icon and version details shown in Explorer and Task Manager.
    configure_file(packaging/windows/slate.rc.in ${CMAKE_CURRENT_BINARY_DIR}/slate.rc @ONLY)
    set(SLATE_RC ${CMAKE_CURRENT_BINARY_DIR}/slate.rc)
endif()
qt_add_executable(slate WIN32 MACOSX_BUNDLE
    src/main.cpp
    ${SLATE_RC}
)
if(WIN32)
    set_target_properties(slate PROPERTIES OUTPUT_NAME Slate)
endif()
set(SLATE_QML Main Theme Icon Tip Btn SMenu SMenuItem SSwitch SSlider Segmented Toast Timeline TransportBar MarkerPanel ClipsPanel InfoPanel TranscriptPanel ScopesPanel AudioView EmptyState CommandPalette SettingsDialog OpenUrlDialog)
foreach(f IN LISTS SLATE_QML)
    # Put each QML file next to the module's qmldir so they see the C++ types and each other.
    set_source_files_properties(qml/${f}.qml PROPERTIES QT_RESOURCE_ALIAS ${f}.qml)
endforeach()
set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_add_qml_module(slate
    URI Slate
    VERSION 1.0
    SOURCES
        src/mpvobject.h src/mpvobject.cpp
        src/appcontroller.h src/appcontroller.cpp
        src/media.h src/media.cpp
        src/visuals.h src/visuals.cpp
        src/transcript.h src/transcript.cpp
        src/icons.h src/icons.cpp
    RESOURCES
        assets/slate.png
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/Icon.qml
        qml/Tip.qml
        qml/Btn.qml
        qml/SMenu.qml
        qml/SMenuItem.qml
        qml/SSwitch.qml
        qml/SSlider.qml
        qml/Segmented.qml
        qml/Toast.qml
        qml/Timeline.qml
        qml/TransportBar.qml
        qml/MarkerPanel.qml
        qml/ClipsPanel.qml
        qml/InfoPanel.qml
        qml/TranscriptPanel.qml
        qml/ScopesPanel.qml
        qml/AudioView.qml
        qml/EmptyState.qml
        qml/CommandPalette.qml
        qml/SettingsDialog.qml
        qml/OpenUrlDialog.qml
)
target_link_libraries(slate PRIVATE slatecore libmpv Qt6::Quick Qt6::QuickControls2 Qt6::OpenGL Qt6::Network Qt6::Svg Qt6::Test)
target_compile_definitions(slate PRIVATE PROJECT_VERSION_STRING="${PROJECT_VERSION}")

# ---- tests ------------------------------------------------------------------
enable_testing()
qt_add_executable(slate_tests tests/tst_core.cpp)
target_link_libraries(slate_tests PRIVATE slatecore Qt6::Test)
add_test(NAME core COMMAND slate_tests)

install(TARGETS slate RUNTIME DESTINATION . BUNDLE DESTINATION .)
