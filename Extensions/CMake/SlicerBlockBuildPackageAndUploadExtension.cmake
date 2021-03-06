
#-----------------------------------------------------------------------------
# Macro allowing to set a variable to its default value only if not already defined
macro(setIfNotDefined var defaultvalue)
  if(NOT DEFINED ${var})
    set(${var} "${defaultvalue}")
  endif()
endmacro()

#-----------------------------------------------------------------------------
if(NOT EXISTS "${SCRIPT_ARGS_FILE}")
  message(FATAL_ERROR "Argument 'SCRIPT_ARGS_FILE' is either missing or pointing to an nonexistent file !")
endif()
include(${SCRIPT_ARGS_FILE})

#-----------------------------------------------------------------------------
# Sanity checks
set(expected_defined_vars
  BUILD_TESTING
  CTEST_BUILD_CONFIGURATION
  CTEST_CMAKE_GENERATOR
  EXTENSION_BUILD_OPTIONS_STRING
  EXTENSION_BUILD_SUBDIRECTORY
  EXTENSION_ENABLED
  EXTENSION_NAME
  EXTENSION_SOURCE_DIR
  EXTENSION_SUPERBUILD_BINARY_DIR
  GIT_EXECUTABLE
  RUN_CTEST_BUILD
  RUN_CTEST_CONFIGURE
  RUN_CTEST_PACKAGES
  RUN_CTEST_SUBMIT
  RUN_CTEST_TEST
  RUN_CTEST_UPLOAD
  Slicer_CMAKE_DIR Slicer_DIR
  Slicer_EXTENSIONS_TRACK_QUALIFIER
  Slicer_WC_REVISION
  Subversion_SVN_EXECUTABLE
  )
if(RUN_CTEST_UPLOAD)
  list(APPEND expected_defined_vars
    EXTENSION_ARCHITECTURE
    EXTENSION_BITNESS
    EXTENSION_OPERATING_SYSTEM
    MIDAS_PACKAGE_API_KEY
    MIDAS_PACKAGE_EMAIL
    MIDAS_PACKAGE_URL
    )
endif()
foreach(var ${expected_defined_vars})
  if(NOT DEFINED ${var})
    message(FATAL_ERROR "Variable ${var} is not defined !")
  endif()
endforeach()

#-----------------------------------------------------------------------------
set(CMAKE_MODULE_PATH
  ${Slicer_CMAKE_DIR}
  ${Slicer_CMAKE_DIR}/../Extensions/CMake
  ${CMAKE_MODULE_PATH}
  )

include(CMakeParseArguments)
include(MIDASCTestUploadURL)
include(UseSlicerMacros) # for slicer_setting_variable_message

#-----------------------------------------------------------------------------
set(optional_vars
  EXTENSION_CATEGORY
  EXTENSION_CONTRIBUTORS
  EXTENSION_DESCRIPTION
  EXTENSION_HOMEPAGE
  EXTENSION_ICONURL
  EXTENSION_SCREENSHOTURLS
  EXTENSION_STATUS
  )
foreach(var ${optional_vars})
  slicer_setting_variable_message(${var})
endforeach()

#-----------------------------------------------------------------------------
# Set site name and force to lower case
site_name(CTEST_SITE)
string(TOLOWER "${CTEST_SITE}" ctest_site_lowercase)
set(CTEST_SITE ${ctest_site_lowercase} CACHE STRING "Name of the computer/site where compile is being run" FORCE)

# Get working copy information
include(SlicerMacroExtractRepositoryInfo)
SlicerMacroExtractRepositoryInfo(VAR_PREFIX EXTENSION SOURCE_DIR ${EXTENSION_SOURCE_DIR})

# Set build name
set(CTEST_BUILD_NAME "${Slicer_WC_REVISION}-${EXTENSION_NAME}-${EXTENSION_WC_TYPE}${EXTENSION_WC_REVISION}-${EXTENSION_COMPILER}-${EXTENSION_BUILD_OPTIONS_STRING}-${CTEST_BUILD_CONFIGURATION}")

setIfNotDefined(CTEST_PARALLEL_LEVEL 8)
setIfNotDefined(CTEST_MODEL "Experimental")

set(label ${EXTENSION_NAME})
set_property(GLOBAL PROPERTY SubProject ${label})
set_property(GLOBAL PROPERTY Label ${label})

# If no CTestConfig.cmake file is found in ${ctestconfig_dest_dir},
# one will be generated.
set(ctestconfig_dest_dir ${EXTENSION_SUPERBUILD_BINARY_DIR}/${EXTENSION_BUILD_SUBDIRECTORY})
if(NOT EXISTS ${ctestconfig_dest_dir}/CTestConfig.cmake)
  message(STATUS "CTestConfig.cmake has been written to: ${ctestconfig_dest_dir}")
  file(WRITE ${ctestconfig_dest_dir}/CTestConfig.cmake
"set(CTEST_PROJECT_NAME \"${EXTENSION_NAME}\")
set(CTEST_NIGHTLY_START_TIME \"3:00:00 UTC\")

set(CTEST_DROP_METHOD \"http\")
set(CTEST_DROP_SITE \"slicer.cdash.org\")
set(CTEST_DROP_LOCATION \"/submit.php?project=Slicer4\")
set(CTEST_DROP_SITE_CDASH TRUE)")
endif()

set(track_qualifier_cleaned "${Slicer_EXTENSIONS_TRACK_QUALIFIER}-")
# Track associated with 'master' should default to either 'Continuous', 'Nightly' or 'Experimental'
if(track_qualifier_cleaned STREQUAL "master-")
  set(track_qualifier_cleaned "")
endif()
set(track "Extensions-${track_qualifier_cleaned}${CTEST_MODEL}")
ctest_start(${CTEST_MODEL} TRACK ${track} ${EXTENSION_SOURCE_DIR} ${EXTENSION_SUPERBUILD_BINARY_DIR})
ctest_read_custom_files(${EXTENSION_SUPERBUILD_BINARY_DIR} ${EXTENSION_SUPERBUILD_BINARY_DIR}/${EXTENSION_BUILD_SUBDIRECTORY})

set(cmakecache_content
"#Generated by SlicerBlockBuildPackageAndUploadExtension.cmake
${EXTENSION_NAME}_BUILD_SLICER_EXTENSION:BOOL=ON
CMAKE_BUILD_TYPE:STRING=${CTEST_BUILD_CONFIGURATION}
CMAKE_GENERATOR:STRING=${CTEST_CMAKE_GENERATOR}
CMAKE_MAKE_PROGRAM:FILEPATH=${CMAKE_MAKE_PROGRAM}
CMAKE_C_COMPILER:FILEPATH=${CMAKE_C_COMPILER}
CMAKE_CXX_COMPILER:FILEPATH=${CMAKE_CXX_COMPILER}
GIT_EXECUTABLE:FILEPATH=${GIT_EXECUTABLE}
Subversion_SVN_EXECUTABLE:FILEPATH=${Subversion_SVN_EXECUTABLE}
Slicer_DIR:PATH=${Slicer_DIR}
Slicer_EXTENSIONS_TRACK_QUALIFIER:STRING=${Slicer_EXTENSIONS_TRACK_QUALIFIER}
MIDAS_PACKAGE_URL:STRING=${MIDAS_PACKAGE_URL}
MIDAS_PACKAGE_EMAIL:STRING=${MIDAS_PACKAGE_EMAIL}
MIDAS_PACKAGE_API_KEY:STRING=${MIDAS_PACKAGE_API_KEY}
EXTENSION_DEPENDS:STRING=${EXTENSION_DEPENDS}
")

if(APPLE)
  set(cmakecache_content "${cmakecache_content}
CMAKE_OSX_ARCHITECTURES:STRING=${CMAKE_OSX_ARCHITECTURES}
CMAKE_OSX_DEPLOYMENT_TARGET:STRING=${CMAKE_OSX_DEPLOYMENT_TARGET}
CMAKE_OSX_SYSROOT:PATH=${CMAKE_OSX_SYSROOT}")
endif()

foreach(dep ${EXTENSION_DEPENDS})
  set(cmakecache_content "${cmakecache_content}\n${dep}_DIR:PATH=${CMAKE_CURRENT_BINARY_DIR}/../${dep}-build")
endforeach()

#-----------------------------------------------------------------------------
# Write CMakeCache.txt only if required
set(cmakecache_current "")
if(EXISTS ${EXTENSION_SUPERBUILD_BINARY_DIR}/CMakeCache.txt)
  file(READ ${EXTENSION_SUPERBUILD_BINARY_DIR}/CMakeCache.txt cmakecache_current)
endif()
if(NOT ${cmakecache_content} STREQUAL "${cmakecache_current}")
  file(WRITE ${EXTENSION_SUPERBUILD_BINARY_DIR}/CMakeCache.txt ${cmakecache_content})
endif()

# Explicitly set CTEST_BINARY_DIRECTORY so that ctest_submit find
# the xml part files in <EXTENSION_SUPERBUILD_BINARY_DIR>/Testing
set(CTEST_BINARY_DIRECTORY ${EXTENSION_SUPERBUILD_BINARY_DIR})

#-----------------------------------------------------------------------------
# Configure extension
if(RUN_CTEST_CONFIGURE)
  #message("----------- [ Configuring extension ${EXTENSION_NAME} ] -----------")
  ctest_configure(
    BUILD ${EXTENSION_SUPERBUILD_BINARY_DIR}
    SOURCE ${EXTENSION_SOURCE_DIR}
    RETURN_VALUE res
    )
  if(RUN_CTEST_SUBMIT)
    ctest_submit(PARTS Configure)
  endif()
  if(NOT res EQUAL 0)
    message(FATAL_ERROR "Failed to configure extension ${EXTENSION_NAME}")
  endif()
endif()

#-----------------------------------------------------------------------------
# Build extension
set(build_errors)
if(RUN_CTEST_BUILD)
  #message("----------- [ Building extension ${EXTENSION_NAME} ] -----------")
  ctest_build(BUILD ${EXTENSION_SUPERBUILD_BINARY_DIR} NUMBER_ERRORS build_errors APPEND)
  if(RUN_CTEST_SUBMIT)
    ctest_submit(PARTS Build)
  endif()
endif()

#-----------------------------------------------------------------------------
# Test extension
if(BUILD_TESTING AND RUN_CTEST_TEST)
  #message("----------- [ Testing extension ${EXTENSION_NAME} ] -----------")
  # Check if there are tests to run
  execute_process(COMMAND ${CMAKE_CTEST_COMMAND} -C ${CTEST_BUILD_CONFIGURATION} -N
    WORKING_DIRECTORY ${EXTENSION_SUPERBUILD_BINARY_DIR}/${EXTENSION_BUILD_SUBDIRECTORY}
    OUTPUT_VARIABLE output
    OUTPUT_STRIP_TRAILING_WHITESPACE
    )
  string(REGEX REPLACE ".*Total Tests: ([0-9]+)" "\\1" test_count "${output}")
  if("${test_count}" GREATER 0)
    ctest_test(
        BUILD ${EXTENSION_SUPERBUILD_BINARY_DIR}/${EXTENSION_BUILD_SUBDIRECTORY}
        PARALLEL_LEVEL ${CTEST_PARALLEL_LEVEL})
    if(RUN_CTEST_SUBMIT)
      ctest_submit(PARTS Test)
    endif()
  endif()
endif()

#-----------------------------------------------------------------------------
# Package extension
if(build_errors GREATER "0")
  message(WARNING "Skip extension packaging: ${build_errors} build error(s) occured !")
else()
  message("Packaging and uploading extension ${EXTENSION_NAME} to midas ...")
  set(package_list)
  if(RUN_CTEST_PACKAGES)
    ctest_build(
      TARGET packageupload
      BUILD ${EXTENSION_SUPERBUILD_BINARY_DIR}/${EXTENSION_BUILD_SUBDIRECTORY}
      APPEND
      )
    ctest_submit(PARTS Build)
  endif()

  if(RUN_CTEST_UPLOAD AND COMMAND ctest_upload)
    message("Uploading package URL for extension ${EXTENSION_NAME} ...")

    file(STRINGS ${EXTENSION_SUPERBUILD_BINARY_DIR}/${EXTENSION_BUILD_SUBDIRECTORY}/PACKAGES.txt package_list)

    foreach(p ${package_list})
      get_filename_component(package_name "${p}" NAME)
      message("Uploading URL to [${package_name}] on CDash")
      midas_ctest_upload_url(
        API_URL ${MIDAS_PACKAGE_URL}
        FILEPATH ${p}
        )
      if(RUN_CTEST_SUBMIT)
        ctest_submit(PARTS Upload)
      endif()
    endforeach()
  endif()
endif()
