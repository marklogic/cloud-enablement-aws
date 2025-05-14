Name: mlcmd
Version: 1.0.0
Release: 1
Summary: MarkLogic Command Line Tools
License: Proprietary
Group: Applications/System
BuildArch: noarch

%global debug_package %{nil}

%description
MarkLogic Command Line Tools for managing and interacting with MarkLogic.

%install
echo "Starting install section"
pwd
mkdir -p %{buildroot}/opt/MarkLogic/mlcmd
# Copy files from the source directory to the build root
pwd
cp -r %{project_dir}/mlcmd/* %{buildroot}/opt/MarkLogic/mlcmd
chmod -R 755 %{buildroot}/opt/MarkLogic/mlcmd
echo "Contents of %{buildroot}/opt/MarkLogic/mlcmd:"
ls -l %{buildroot}/opt/MarkLogic/mlcmd
echo "Completed install section"

%files
%attr(0755, root, root) /opt/MarkLogic/mlcmd/*

%changelog
* Mon Apr 28 2025 Your Name <your.email@example.com> - 1.0.0-1
- Initial RPM package for mlcmd.