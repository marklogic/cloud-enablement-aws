Name: marklogic-mlcmd
Version: 12.0.1
Release: 1
Summary: MarkLogic AWS Command Line Tool
License: Apache-2.0
Group: Applications/System
BuildArch: noarch

%description
MarkLogic AWS Command Line Tool for managing MarkLogic Cluster on AWS.

%install
mkdir -p %{buildroot}/opt/MarkLogic/bin/cloud
mkdir -p %{buildroot}/opt/MarkLogic/mlcmd
cp -r %{project_dir}/NOTICE.TXT %{buildroot}/opt/MarkLogic/mlcmd
cp -r %{project_dir}/mlcmd/bin %{buildroot}/opt/MarkLogic/mlcmd/bin
cp -r %{project_dir}/mlcmd/conf %{buildroot}/opt/MarkLogic/mlcmd/conf
cp -r %{project_dir}/mlcmd/ext %{buildroot}/opt/MarkLogic/mlcmd/ext
cp -r %{project_dir}/mlcmd/lib %{buildroot}/opt/MarkLogic/mlcmd/lib
cp -r %{project_dir}/mlcmd/scripts %{buildroot}/opt/MarkLogic/mlcmd/scripts
cp -fp %{project_dir}/mlcmd/mlcmd.sh %{buildroot}/opt/MarkLogic/bin/cloud/mlcmd

%files
%attr(0755, root, root) /opt/MarkLogic/mlcmd/
%attr(0644, root, root) /opt/MarkLogic/mlcmd/NOTICE.TXT
%attr(0755, root, root) /opt/MarkLogic/bin/cloud/mlcmd
%attr(0644, root, root) /opt/MarkLogic/mlcmd/lib/*
%attr(0644, root, root) /opt/MarkLogic/mlcmd/conf/*
%attr(0644, root, root) /opt/MarkLogic/mlcmd/ext/aws/*
%attr(0644, root, root) /opt/MarkLogic/mlcmd/scripts/*
%attr(0755, root, root) /opt/MarkLogic/mlcmd/scripts/ec2-startup.xsh
%attr(0755, root, root) /opt/MarkLogic/mlcmd/scripts/update-hosts.xsh
