PACKAGE_NAME = marklogic-mlcmd
VERSION = 12.0.1
RELEASE = 1
BUILD_DIR = $(shell pwd)/build
RPMBUILD_DIR = $(BUILD_DIR)/rpmbuild
INSTALL_DIR = /opt/MarkLogic/mlcmd
PROJECT_DIR = $(shell pwd)

all: clean build package

clean:
    # Remove the build directory
	rm -rf $(BUILD_DIR)

build:
    # Create necessary directories for RPM build
	mkdir -p $(RPMBUILD_DIR)/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

package: build
    # Copy the spec file to the SPECS directory
	cp marklogic-mlcmd.spec $(RPMBUILD_DIR)/SPECS/
    # Build the RPM package
	rpmbuild --define "_topdir $(RPMBUILD_DIR)" \
             --define "build_dir $(BUILD_DIR)" \
			 --define "project_dir $(PROJECT_DIR)" \
             -ba $(RPMBUILD_DIR)/SPECS/$(PACKAGE_NAME).spec

.PHONY: all clean build package