THEOS_DEVICE_IP = 192.168.1.205

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BoringSSLKeys
$(TWEAK_NAME)_FILES = Tweak.xm
$(TWEAK_NAME)_CFLAGS = -Wno-unused-function -Wno-unused-variable

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
