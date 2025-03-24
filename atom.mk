
LOCAL_PATH := $(call my-dir)

###############################################################################
# Common variables for Openssl
###############################################################################
LIBCRYPTO_CONFIG_NAME :=

ifeq ("$(TARGET_OS)","darwin")
  LIBCRYPTO_CROSS_SDKROOT := $(shell export SDKROOT=`xcrun --sdk ${APPLE_SDK} --show-sdk-path` ;\
                                     echo CROSS_TOP=$${SDKROOT%/SDKs/*} CROSS_SDK=$${SDKROOT\#\#*/SDKs/} )
ifeq ("$(TARGET_OS_FLAVOUR)","iphoneos")
  LIBCRYPTO_CONFIG_NAME := iphoneos-cross
else ifeq ("$(TARGET_OS_FLAVOUR)","iphonesimulator")
  LIBCRYPTO_CONFIG_NAME := iossimulator-xcrun
else ifeq ("$(TARGET_ARCH)","x86")
  LIBCRYPTO_CONFIG_NAME := darwin-i386-cc
else ifeq ("$(TARGET_ARCH)","x64")
  LIBCRYPTO_CONFIG_NAME := darwin64-x86_64-cc
else ifeq ("$(TARGET_ARCH)","arm")
  LIBCRYPTO_CONFIG_NAME := darwin64-arm64-cc
else ifeq ("$(TARGET_ARCH)","aarch64")
  LIBCRYPTO_CONFIG_NAME := darwin64-arm64-cc
else
  $(error "unknown architecture $(TARGET_ARCH)")
endif
ifneq ($(words $(filter -arch,$(APPLE_ARCH))),1)
#disable assembler code for multiarch build
LIBCRYPTO_CONFIG_NAME += no-asm
endif
else ifneq ($(filter "$(TARGET_OS)","linux" "android"),)
ifeq ("$(TARGET_ARCH)","x64")
  LIBCRYPTO_CONFIG_NAME := linux-x86_64
else ifeq ("$(TARGET_ARCH)","x86")
  LIBCRYPTO_CONFIG_NAME := linux-x86
else ifeq ("$(TARGET_ARCH)","aarch64")
  LIBCRYPTO_CONFIG_NAME := linux-aarch64
else ifeq ("$(TARGET_ARCH)","arm")
  LIBCRYPTO_CONFIG_NAME := linux-armv4
else
  $(error "unknown architecture $(TARGET_ARCH)")
endif
else ifeq ("$(TARGET_OS)","windows")
ifeq ("$(TARGET_ARCH)","x64")
  LIBCRYPTO_CONFIG_NAME := mingw64
else ifeq ("$(TARGET_ARCH)","x86")
  LIBCRYPTO_CONFIG_NAME := mingw
else
  $(error "unknown architecture $(TARGET_ARCH)")
endif
else ifeq ("$(TARGET_OS)", "baremetal")
  LIBCRYPTO_CONFIG_NAME := gcc
  # disable most features requiring a fullblown OS
  LIBCRYPTO_CONFIG_NAME += no-shared no-dso no-threads no-stdio no-posix-io no-sock
endif

ifeq ("$(TARGET_PBUILD_FORCE_STATIC)","1")
LIBCRYPTO_CONFIG_SHARED := no-shared
else ifeq ("$(TARGET_OS)-$(TARGET_OS_FLAVOUR)-$(USE_ALCHEMY_ANDROID_SDK)","linux-android-")
# Force static build for Android SDK, to avoid conflict with pre-loaded libssl/libcrypto in zygote
LIBCRYPTO_CONFIG_SHARED := no-shared
else
LIBCRYPTO_CONFIG_SHARED := shared
endif

# List of deprecated protocol versions / algorithms
LIBCRYPTO_CONFIG_DEPRECATED := \
	no-ssl3    no-ssl3-method \
	no-tls1    no-tls1-method \
	no-tls1_1  no-tls1_1-method \
	no-dtls1   no-dtls1-method

###############################################################################
# Openssl
###############################################################################

# if we have no CONFIG_NAME, we do not know how to build, so comment out the module
ifneq ($(LIBCRYPTO_CONFIG_NAME),)

include $(CLEAR_VARS)

LOCAL_MODULE := libcrypto
LOCAL_DESCRIPTION := Cryptography library
LOCAL_CATEGORY_PATH := libs

LOCAL_CONDITIONAL_LIBRARIES := OPTIONAL:ca-certificates

LOCAL_EXPORT_LDLIBS := -lssl -lcrypto

LOCAL_AUTOTOOLS_VERSION := 3.0.15
LOCAL_AUTOTOOLS_ARCHIVE := openssl-$(LOCAL_AUTOTOOLS_VERSION).tar.gz
LOCAL_AUTOTOOLS_SUBDIR  := openssl-$(LOCAL_AUTOTOOLS_VERSION)

LOCAL_AUTOTOOLS_MAKE_BUILD_ENV := \
	$(AUTOTOOLS_CONFIGURE_ENV)

# Do not build tests or tools
LOCAL_AUTOTOOLS_MAKE_BUILD_ARGS := \
	CC="$(CCACHE) $(TARGET_CC)" \
	AR="$(TARGET_AR)" \
	all

# Used for clean internally also
LOCAL_AUTOTOOLS_MAKE_INSTALL_ENV := \
	$(AUTOTOOLS_CONFIGURE_ENV)

# Used for clean internally also
LOCAL_AUTOTOOLS_MAKE_INSTALL_ARGS := \
	CC="$(CCACHE) $(TARGET_CC)" \
	AR="$(TARGET_AR)" \
	INSTALL_PREFIX="$(AUTOTOOLS_INSTALL_DESTDIR)" \
	LIBDIR=../$(TARGET_DEFAULT_LIB_DESTDIR)

LOCAL_AUTOTOOLS_MAKE_BUILD_ENV += $(LIBCRYPTO_CROSS_SDKROOT)
LOCAL_AUTOTOOLS_MAKE_INSTALL_ENV += $(LIBCRYPTO_CROSS_SDKROOT)

define LOCAL_AUTOTOOLS_CMD_CONFIGURE
	$(Q) cd $(PRIVATE_SRC_DIR) && $(AUTOTOOLS_CONFIGURE_ENV) \
		./Configure $(LIBCRYPTO_CONFIG_NAME) -DL_ENDIAN \
		$(LIBCRYPTO_CONFIG_SHARED) \
		$(LIBCRYPTO_CONFIG_DEPRECATED) \
		no-tests \
		--prefix=$(AUTOTOOLS_CONFIGURE_PREFIX) \
		--openssldir=$(TARGET_AUTOTOOLS_CONFIGURE_SYSCONFDIR)/ssl
endef

# Only install libraries/binaries
define LOCAL_AUTOTOOLS_CMD_INSTALL
	$(Q) $(AUTOTOOLS_MAKE_ENV) $(PRIVATE_MAKE_INSTALL_ENV) \
		$(MAKE) -C $(PRIVATE_SRC_DIR) \
		$(AUTOTOOLS_MAKE_ARGS) $(PRIVATE_MAKE_INSTALL_ARGS) \
		install_sw
	$(Q) chmod u+w $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_LIB_DESTDIR)/libssl* \
	               $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_LIB_DESTDIR)/libcrypto*
endef

# Need to do a lot of manual cleaning
define LOCAL_AUTOTOOLS_CMD_POST_CLEAN
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/bin/openssl
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/bin/c_rehash
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/lib/libssl*.a*
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/lib/libssl*.so*
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/lib/libcrypto*.a*
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/lib/libcrypto*.so*
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/lib/engines/*.so
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/lib/pkgconfig/libcrypto.pc
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/lib/pkgconfig/libssl.pc
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/lib/pkgconfig/openssl.pc
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/local/usr/lib/libcrypto.*
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/local/usr/lib/libssl.*
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/local/usr/lib/pkgconfig/libcrypto.pc
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/local/usr/lib/pkgconfig/openssl.pc
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/local/usr/lib/pkgconfig/libssl.pc
	$(Q) rm -rf $(TARGET_OUT_STAGING)/usr/include/openssl
	$(Q) rm -f $(TARGET_OUT_FINAL)/usr/lib/libcrypto.*
	$(Q) rm -f $(TARGET_OUT_FINAL)/usr/lib/libssl.*
	$(Q) rm -f $(TARGET_OUT_FINAL)/usr/local/usr/lib/libcrypto.*
	$(Q) rm -f $(TARGET_OUT_FINAL)/usr/local/usr/lib/libssl.*
endef

LOCAL_CREATE_LINKS := usr/ssl:../etc/ssl

include $(BUILD_AUTOTOOLS)

endif

###############################################################################
# Openssl (Host part)
###############################################################################

include $(CLEAR_VARS)

LOCAL_HOST_MODULE := libcrypto
LOCAL_EXPORT_LDLIBS := -lssl -lcrypto -ldl -pthread
LOCAL_CATEGORY_PATH := libs

LOCAL_EXPORT_C_INCLUDES := \
        $(HOST_OUT_STAGING)/usr/include/openssl

LOCAL_CONDITIONAL_LIBRARIES := OPTIONAL:host.ca-certificates

LOCAL_AUTOTOOLS_VERSION := 3.0.15
LOCAL_AUTOTOOLS_ARCHIVE := openssl-$(LOCAL_AUTOTOOLS_VERSION).tar.gz
LOCAL_AUTOTOOLS_SUBDIR  := openssl-$(LOCAL_AUTOTOOLS_VERSION)

# Do not build tests or tools
LOCAL_AUTOTOOLS_MAKE_BUILD_ARGS := \
	CC="$(CCACHE) $(HOST_CC)" \
	AR="$(HOST_AR)" \
	all

LOCAL_AUTOTOOLS_MAKE_BUILD_ENV := \
	$(HOST_AUTOTOOLS_CONFIGURE_ENV)

define LOCAL_AUTOTOOLS_CMD_CONFIGURE
	$(Q) cd $(PRIVATE_SRC_DIR) && \
		$(HOST_AUTOTOOLS_CONFIGURE_ENV) ./config \
		--prefix=$(HOST_AUTOTOOLS_CONFIGURE_PREFIX) \
		--openssldir=$(HOST_AUTOTOOLS_CONFIGURE_SYSCONFDIR)/ssl \
		--libdir=lib \
		$(LIBCRYPTO_CONFIG_DEPRECATED) \
		no-tests
endef

# Only install libraries/binaries
define LOCAL_AUTOTOOLS_CMD_INSTALL
	$(Q) $(HOST_AUTOTOOLS_MAKE_ENV) $(PRIVATE_MAKE_INSTALL_ENV) \
		$(MAKE) -C $(PRIVATE_SRC_DIR) \
		$(HOST_AUTOTOOLS_MAKE_ARGS) $(PRIVATE_MAKE_INSTALL_ARGS) \
		install_sw
	$(Q) rm -f $(HOST_OUT_STAGING)/usr/lib/libcrypto*.so*
	$(Q) rm -f $(HOST_OUT_STAGING)/usr/lib/libssl*.so*
endef

# Need to do a lot of manual cleaning
define LOCAL_AUTOTOOLS_CMD_POST_CLEAN
	$(Q) rm -f $(HOST_OUT_STAGING)/usr/bin/openssl
	$(Q) rm -f $(HOST_OUT_STAGING)/usr/bin/c_rehash
	$(Q) rm -f $(HOST_OUT_STAGING)/usr/lib/libssl*.a*
	$(Q) rm -f $(HOST_OUT_STAGING)/usr/lib/libssl*.so*
	$(Q) rm -f $(HOST_OUT_STAGING)/usr/lib/libcrypto*.a*
	$(Q) rm -f $(HOST_OUT_STAGING)/usr/lib/libcrypto*.so*
	$(Q) rm -f $(HOST_OUT_STAGING)/usr/lib/engines/*.so
	$(Q) rm -f $(HOST_OUT_STAGING)/usr/lib/pkgconfig/libcrypto.pc
	$(Q) rm -f $(HOST_OUT_STAGING)/usr/lib/pkgconfig/libssl.pc
	$(Q) rm -f $(HOST_OUT_STAGING)/usr/lib/pkgconfig/openssl.pc
	$(Q) rm -f $(HOST_OUT_STAGING)/usr/local/usr/lib/libcrypto.*
	$(Q) rm -f $(HOST_OUT_STAGING)/usr/local/usr/lib/pkgconfig/libcrypto.pc
	$(Q) rm -f $(HOST_OUT_STAGING)/usr/local/usr/lib/pkgconfig/openssl.pc
	$(Q) rm -f $(HOST_OUT_STAGING)/usr/local/usr/lib/pkgconfig/libssl.pc
	$(Q) rm -rf $(HOST_OUT_STAGING)/usr/include/openssl
	$(Q) rm -rf $(HOST_OUT_BUILD)/libcrypto
endef

LOCAL_CREATE_LINKS := usr/ssl:../etc/ssl

include $(BUILD_AUTOTOOLS)
