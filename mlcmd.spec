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
mkdir -p %{buildroot}/opt/MarkLogic/bin/cloud
mkdir -p %{buildroot}/opt/MarkLogic/mlcmd
cp -r %{project_dir}/mlcmd/bin %{buildroot}/opt/MarkLogic/mlcmd/bin
cp -r %{project_dir}/mlcmd/bin %{buildroot}/opt/MarkLogic/mlcmd/conf
cp -r %{project_dir}/mlcmd/bin %{buildroot}/opt/MarkLogic/mlcmd/ext
cp -r %{project_dir}/mlcmd/bin %{buildroot}/opt/MarkLogic/mlcmd/scripts
cp -fp %{project_dir}/mlcmd/mlcmd.sh %{buildroot}/opt/MarkLogic/bin/cloud/mlcmd
chmod -R 755 %{buildroot}/opt/MarkLogic/mlcmd
echo "Completed install section"

%files
%attr(0755, root, root) /opt/MarkLogic/mlcmd/
%attr(0755, root, root) /opt/MarkLogic/bin/cloud/mlcmd

%changelog
* Mon Apr 28 2025 Your Name <your.email@example.com> - 1.0.0-1
- Initial RPM package for mlcmd.