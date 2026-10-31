cmake_minimum_required(VERSION 3.21)
project(Slate VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Quick QuickControls2 OpenGL Test)

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
qt_add_executable(slate WIN32 MACOSX_BUNDLE
    src/main.cpp
)
set(SLATE_QML Main Theme TransportBar Timeline MarkerPanel InfoPanel CommandPalette IconButton Toast)
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
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/TransportBar.qml
        qml/Timeline.qml
        qml/MarkerPanel.qml
        qml/InfoPanel.qml
        qml/CommandPalette.qml
        qml/IconButton.qml
        qml/Toast.qml
)
target_link_libraries(slate PRIVATE slatecore libmpv Qt6::Quick Qt6::QuickControls2 Qt6::OpenGL)
target_compile_definitions(slate PRIVATE PROJECT_VERSION_STRING="${PROJECT_VERSION}")

# ---- tests ------------------------------------------------------------------
enable_testing()
qt_add_executable(slate_tests tests/tst_core.cpp)
target_link_libraries(slate_tests PRIVATE slatecore Qt6::Test)
add_test(NAME core COMMAND slate_tests)

install(TARGETS slate RUNTIME DESTINATION . BUNDLE DESTINATION .)
