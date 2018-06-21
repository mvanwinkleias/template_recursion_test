ARTIFACT_NAME = template-recursion-test

MAKEFILE_PATH = $(strip $(dir $(realpath $(firstword $(MAKEFILE_LIST)))))

PACKAGE_SHELL_INCLUDE_PATH=$(MAKEFILE_PATH)/package_shell/make

include $(PACKAGE_SHELL_INCLUDE_PATH)/project-base_variables.gmk

ifneq ("$(wildcard $(ARTIFACT_NAME)/artifact_variables.gmk)","")
	include $(ARTIFACT_NAME)/artifact_variables.gmk
endif

include $(PACKAGE_SHELL_INCLUDE_PATH)/make-standard_phonies.gmk

include $(PACKAGE_SHELL_INCLUDE_PATH)/project_directories-full_project.gmk
include $(PACKAGE_SHELL_INCLUDE_PATH)/package_shell-additional.gmk
include $(PACKAGE_SHELL_INCLUDE_PATH)/source-basic_tests.gmk
include $(PACKAGE_SHELL_INCLUDE_PATH)/package_install-base_directories.gmk
include $(PACKAGE_SHELL_INCLUDE_PATH)/package_install-conditional_additions.gmk
include $(PACKAGE_SHELL_INCLUDE_PATH)/package_install-final_cleanup.gmk

# Supported package systems
include $(PACKAGE_SHELL_INCLUDE_PATH)/package_build-rpm.gmk
include $(PACKAGE_SHELL_INCLUDE_PATH)/package_build-deb.gmk

.PHONY: debug-ALL

debug-ALL: \
	debug-base-Makefile \
	debug-project-base_variables \
	debug-make-standard_phonies \
	debug-project_directories-full_project \
	debug-package_shell-additional \
	debug-source-basic_tests \
	debug-package_install-base_directories \
	debug-package_install-conditional_additions \
	debug-package_install-final_cleanup \
	debug-package_build-rpm \
	debug-package_build-deb

.PHONY: debug-base-Makefile

debug-base-Makefile:
	# Makefile - debug variables
	#   ARTIFACT_NAME: '$(ARTIFACT_NAME)'
	#   MAKEFILE_PATH: '$(MAKEFILE_PATH)'
	#   PACKAGE_SHELL_INCLUDE_PATH: '$(PACKAGE_SHELL_INCLUDE_PATH)'
	#
