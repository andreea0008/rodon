cmake_minimum_required(VERSION 3.16)
project(RodON VERSION 0.1 LANGUAGES CXX)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
    message(FATAL_ERROR "In-source builds are not allowed.")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(PROJECT_VERSION_MAJOR 0)
set(PROJECT_VERSION_MINOR 1)
set(PROJECT_VERSION_PATCH 0)
set(PROJECT_VERSION_TWEAK 0)
set(PROJECT_VERSION "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}.${PROJECT_VERSION_TWEAK}")
set(PROJECT_VERSION_SHORT "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}")

if(APPLE)
    include(CheckLanguage)
    check_language(Swift)

    if(CMAKE_Swift_COMPILER)
        enable_language(Swift)
        message(STATUS "Swift compiler enabled")
    endif()
endif()

find_package(Qt6 REQUIRED COMPONENTS Quick LinguistTools)
find_package(unofficial-sodium CONFIG REQUIRED)
qt_standard_project_setup(REQUIRES 6.8)


set(IS_PRODUCTION TRUE)
if(IS_PRODUCTION)
    set(RODON_URL "http://2.28.64.194:3000/api/v1")
else()
    set(RODON_URL "http://localhost:3000/api/v1")
endif()

# C++ sources
file(GLOB_RECURSE CPP_H_FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/source/*.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/source/*.cpp"
)

list(FILTER CPP_H_FILES EXCLUDE REGEX ".*KeychainStore_stub\\.cpp$")
list(FILTER CPP_H_FILES EXCLUDE REGEX ".*KeychainStore_apple\\.mm$")

# Assets
file(GLOB_RECURSE APP_ICONS
    "${CMAKE_CURRENT_SOURCE_DIR}/ui/*.png"
    "${CMAKE_CURRENT_SOURCE_DIR}/ui/*.jpg"
    "${CMAKE_CURRENT_SOURCE_DIR}/ui/*.html"
    "${CMAKE_CURRENT_SOURCE_DIR}/ui/*.svg"
    "${CMAKE_CURRENT_SOURCE_DIR}/ui/*.json"
    "${CMAKE_CURRENT_SOURCE_DIR}/ui/*.gif"
)

list(FILTER APP_ICONS EXCLUDE REGEX ".*/Assets\\.xcassets/.*")

foreach(ICON ${APP_ICONS})
    file(RELATIVE_PATH ICON_ALIAS "${CMAKE_CURRENT_SOURCE_DIR}/ui" "${ICON}")
    set_property(SOURCE "${ICON}" PROPERTY QT_RESOURCE_ALIAS "${ICON_ALIAS}")
endforeach()

# Fonts
file(GLOB_RECURSE APP_FONTS "${CMAKE_CURRENT_SOURCE_DIR}/ui/font/*.ttf")
foreach(FONT ${APP_FONTS})
    file(RELATIVE_PATH FONT_RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "${FONT}")
    set_property(SOURCE "${FONT}" PROPERTY QT_RESOURCE_ALIAS "${FONT_RELATIVE}")
endforeach()

# QML + JS
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/qml"
)
file(GLOB_RECURSE APP_QML_FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/*.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/*.js"
)

foreach(QML_FILE ${APP_QML_FILES})
    file(RELATIVE_PATH QML_FILE_RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}/qml" "${QML_FILE}")
    set_property(SOURCE "${QML_FILE}" PROPERTY QT_RESOURCE_ALIAS "${QML_FILE_RELATIVE}")
endforeach()

set_source_files_properties(
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/Fonts.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/Colors.qml"
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

if(APPLE)
    file(GLOB_RECURSE IOS_H_FILES
        "${CMAKE_CURRENT_SOURCE_DIR}/ios/*.h"
        "${CMAKE_CURRENT_SOURCE_DIR}/ios/*.mm"
    )
    list(APPEND CPP_H_FILES ${IOS_H_FILES})
endif()

# translation files
set(SUPPORTED_LANGUAGES uk de pl en es fr it)
set(TS_FILES)
foreach(LANG ${SUPPORTED_LANGUAGES})
    list(APPEND TS_FILES "${CMAKE_SOURCE_DIR}/translations/rodon_${LANG}.ts")
endforeach()

qt_add_executable(${PROJECT_NAME} main.cpp)

qt_add_qml_module(${PROJECT_NAME}
    URI SVPN
    VERSION 1.0
    SOURCES
    ${CPP_H_FILES}
    QML_FILES
    ${APP_QML_FILES}
    RESOURCES
    ${APP_ICONS}
    ${APP_FONTS}
)

target_include_directories(${PROJECT_NAME} PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/source"
)

if(APPLE)
    # iOS + macOS: власний Keychain з shared access group (для extension)
    target_sources(${PROJECT_NAME} PRIVATE
        source/KeychainStore.h
        ios/KeychainStore_apple.mm
    )
    target_link_libraries(${PROJECT_NAME} PRIVATE "-framework Security")
else()
    # TODO: qtkeychain для Android/Windows/Linux, коли дійде черга
    target_sources(${PROJECT_NAME} PRIVATE
        source/KeychainStore.h
        source/KeychainStore_stub.cpp
    )
endif()

if(IOS)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "15.0")

    set(STORYBOARD_FILE "${CMAKE_SOURCE_DIR}/ios/Storyboard.storyboard")
    set(ASSETS_FOLDER   "${CMAKE_SOURCE_DIR}/ios/AppIcons/Assets.xcassets")

    set_source_files_properties("${STORYBOARD_FILE}" PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
    set_source_files_properties("${ASSETS_FOLDER}"   PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
    target_sources(${PROJECT_NAME} PRIVATE "${STORYBOARD_FILE}" "${ASSETS_FOLDER}")

    target_include_directories(${PROJECT_NAME} PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/ios"
    )

set_target_properties(${PROJECT_NAME} PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_GUI_IDENTIFIER              "com.rodon.vpn.app"
    MACOSX_BUNDLE_BUNDLE_NAME                 "RodON"
    MACOSX_BUNDLE_BUNDLE_VERSION              "${PROJECT_VERSION}"
    MACOSX_BUNDLE_SHORT_VERSION_STRING        "${PROJECT_VERSION_SHORT}"
    MACOSX_BUNDLE_INFO_PLIST                  "${CMAKE_CURRENT_SOURCE_DIR}/ios/Info.plist"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.rodon.vpn.app"
    # "com.rodon.vpnapp"
    XCODE_ATTRIBUTE_DEVELOPMENT_TEAM          "H8GLL2MY9E"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY        "iPhone Developer"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY    "1"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "15.0"
    XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME          "AppIcon"
    XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS YES
    XCODE_ATTRIBUTE_UILaunchStoryboardName    "Storyboard"
    XCODE_ATTRIBUTE_INFOPLIST_KEY_CFBundleDisplayName "RodON"
    XCODE_ATTRIBUTE_MARKETING_VERSION         "${PROJECT_VERSION}"
    XCODE_ATTRIBUTE_CURRENT_PROJECT_VERSION   "${PROJECT_VERSION}"
    XCODE_ATTRIBUTE_INFOPLIST_KEY_LSApplicationCategoryType "public.app-category.productivity"
    # XCODE_EMBED_APP_EXTENSIONS "RodonTunnel"
    # XCODE_EMBED_APP_EXTENSIONS_CODE_SIGN_ON_COPY "YES"
    XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS
    "${CMAKE_CURRENT_SOURCE_DIR}/ios/rodon.entitlements"
)

set(WGK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ios/wireguardkit")
file(GLOB WGK_C "${WGK_DIR}/WireGuardKitC/*.c")
message(STATUS "WGK_C files: ${WGK_C}")
    # --- iOS VPN Extension (WireGuard) ---
if(IOS)
    set(WGK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ios/wireguardkit")

    file(GLOB WGK_SWIFT "${WGK_DIR}/WireGuardKit/*.swift")
    file(GLOB WGK_C     "${WGK_DIR}/WireGuardKitC/*.c")
    file(GLOB TUNNEL_SWIFT "${CMAKE_CURRENT_SOURCE_DIR}/ios/tunnel/*.swift")

    add_executable(RodonTunnel
        ${TUNNEL_SWIFT}
        ${WGK_SWIFT}
    )
    target_sources(RodonTunnel PRIVATE ${WGK_C})
    set_source_files_properties(${WGK_C} PROPERTIES LANGUAGE C)


set_target_properties(RodonTunnel PROPERTIES
    MACOSX_BUNDLE TRUE
    XCODE_PRODUCT_TYPE "com.apple.product-type.app-extension"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.rodon.vpn.app.tunnel"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/ios/tunnel/Info.plist"
    XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/ios/RodonTunnel.entitlements"
    XCODE_ATTRIBUTE_SWIFT_VERSION "5.0"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "15.0"
    XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "H8GLL2MY9E"
    XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
    XCODE_ATTRIBUTE_MARKETING_VERSION "${PROJECT_VERSION}"
    XCODE_ATTRIBUTE_CURRENT_PROJECT_VERSION "${PROJECT_VERSION}"
    # Критично — rpath для Swift-рантайму (цього бракувало):
    XCODE_ATTRIBUTE_LD_RUNPATH_SEARCH_PATHS "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"
    # C-модуль WireGuardKitC для Swift:
    XCODE_ATTRIBUTE_SWIFT_INCLUDE_PATHS "$(inherited) \"${WGK_DIR}/WireGuardKitC\""
    XCODE_ATTRIBUTE_HEADER_SEARCH_PATHS "$(inherited) \"${WGK_DIR}/WireGuardKitC\""
    XCODE_ATTRIBUTE_SWIFT_ENABLE_EXPLICIT_MODULES "NO"
    XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER "${CMAKE_CURRENT_SOURCE_DIR}/ios/tunnel/RodonTunnel-Bridging-Header.h"
    XCODE_ATTRIBUTE_HEADER_SEARCH_PATHS "$(inherited) \"${WGK_DIR}\" \"${WGK_DIR}/WireGuardKitC\""
)

target_link_libraries(RodonTunnel PRIVATE
    "${WGK_DIR}/libwg-go.a"
    "-framework NetworkExtension"
    "-framework Foundation"
    "-framework UIKit"
)

# Вбудувати extension у основний апк
set_target_properties(${PROJECT_NAME} PROPERTIES
    XCODE_EMBED_APP_EXTENSIONS RodonTunnel
    XCODE_EMBED_APP_EXTENSIONS_CODE_SIGN_ON_COPY YES
)
endif()

# --- WireGuardKit vendored sources ---
# set(WGK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ios/wireguardkit")
# file(GLOB WGK_SWIFT "${WGK_DIR}/WireGuardKit/*.swift")
# file(GLOB WGK_C     "${WGK_DIR}/WireGuardKitC/*.c")

# file(GLOB TUNNEL_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/ios/tunnel/*.swift")

# add_executable(RodonTunnel MACOSX_BUNDLE
#     ${TUNNEL_SOURCES}
#     ${WGK_SWIFT}
#     ${WGK_C}
# )

# set_target_properties(RodonTunnel PROPERTIES
#     BUNDLE TRUE
#     BUNDLE_EXTENSION "appex"
#     XCODE_PRODUCT_TYPE "com.apple.product-type.app-extension"
#     XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.rodon.vpn.app.tunnel"
#     MACOSX_BUNDLE_GUI_IDENTIFIER "com.rodon.vpn.app.tunnel"
#     MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/ios/tunnel/Info.plist"
#     XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "15.0"
#     XCODE_ATTRIBUTE_SWIFT_VERSION "5.0"
#     XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS
#     "${CMAKE_CURRENT_SOURCE_DIR}/ios/RodonTunnel.entitlements"
#     XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "H8GLL2MY9E"
#     XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
#     XCODE_ATTRIBUTE_SWIFT_INCLUDE_PATHS "${WGK_DIR}/WireGuardKitC"
#     XCODE_ATTRIBUTE_OTHER_SWIFT_FLAGS "-I${WGK_DIR}/WireGuardKitC"
#     XCODE_ATTRIBUTE_DEAD_CODE_STRIPPING "NO"
#     XCODE_ATTRIBUTE_ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES "YES"
# )

# target_include_directories(RodonTunnel PRIVATE
#     "${WGK_DIR}/WireGuardKitC"
# )

# target_link_libraries(RodonTunnel PRIVATE
#     "${WGK_DIR}/libwg-go.a"
#     "-framework NetworkExtension"
#     "-framework Foundation"
#     "-framework UIKit"
# )
endif()

if(APPLE AND NOT IOS)
    set(ICNS_FILE "${CMAKE_CURRENT_SOURCE_DIR}/ios/rodon.icns")
    set_source_files_properties("${ICNS_FILE}" PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
    target_sources(${PROJECT_NAME} PRIVATE "${ICNS_FILE}")

    set_target_properties(${PROJECT_NAME} PROPERTIES
        MACOSX_BUNDLE TRUE
        WIN32_EXECUTABLE TRUE
        MACOSX_BUNDLE_GUI_IDENTIFIER       "com.rodon.vpnapp"
        MACOSX_BUNDLE_BUNDLE_VERSION       "${PROJECT_VERSION}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION_SHORT}"
        MACOSX_BUNDLE_ICON_FILE            "rodon.icns"
    )
endif()

target_compile_definitions(${PROJECT_NAME} PRIVATE
    APP_VERSION="${PROJECT_VERSION_SHORT}"
)
target_compile_definitions(${PROJECT_NAME} PRIVATE RODON_URL="${RODON_URL}")
if(APPLE)
    target_link_libraries(${PROJECT_NAME} PRIVATE
        Qt6::Quick unofficial-sodium::sodium
        "-framework Foundation"
        "-framework NetworkExtension"
        "-framework Security"
        "-framework LocalAuthentication"
    )
else()
    target_link_libraries(${PROJECT_NAME}
        PRIVATE Qt6::Quick unofficial-sodium::sodium
    )
endif()

qt_add_translations(${PROJECT_NAME}
    TS_FILES ${TS_FILES}
    RESOURCE_PREFIX "/i18n"
    SOURCES ${APP_QML_FILES}
    LUPDATE_OPTIONS -no-obsolete
)

include(GNUInstallDirs)
install(TARGETS ${PROJECT_NAME}
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
