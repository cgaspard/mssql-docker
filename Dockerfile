# ORIGINAL MSSQL DOCKER IMAGE CREATED BY MICROSOFT
# GitRepo: https://github.com/Microsoft/mssql-docker

# Base OS layer: Latest Ubuntu LTS
# FROM ubuntu:20.04
FROM mcr.microsoft.com/mssql/server:2022-CU11-ubuntu-20.04
USER root

#ENV MSSQL_MAX_MEMORYLIMIT_MB=4096

# Install prerequistes since it is needed to get repo config for SQL server
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -yq curl apt-transport-https gnupg wget apt-transport-https software-properties-common netcat unixodbc-dev
    
# Install SQL Server from apt
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2022.list | tee /etc/apt/sources.list.d/mssql-server.list && \
    wget -q "https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb" && \
    dpkg -i packages-microsoft-prod.deb && \
    apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y mssql-server-ha
RUN apt-get install -y mssql-server-fts
RUN apt-get install -y mssql-tools
RUN apt-get install -y dotnet-runtime-6.0 dotnet-runtime-7.0
RUN echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile

# ADD THIS FOR POLYBASE
#    #apt-get install -y mssql-server-polybase && \    

# Install PowerShell SQL SERVER MODULES & AZURE MODULES
RUN wget https://github.com/PowerShell/PowerShell/releases/download/v7.2.11/powershell-lts_7.2.11-1.deb_amd64.deb && \
    dpkg -i powershell-lts_7.2.11-1.deb_amd64.deb && \
    pwsh -c "Install-Module -Name SqlServer -Force" && \
    pwsh -c "Install-Module -Name Az -Force -AllowClobber"

# Configure SQL Server to enable SQL Agent
RUN /opt/mssql/bin/mssql-conf set sqlagent.enabled true

# Cleanup the base image
RUN apt-get clean && \
    rm packages-microsoft-prod.deb && \
    rm powershell-lts_7.2.11-1.deb_amd64.deb && \
    rm -rf /var/lib/apt/lists

# Copy the startup script
COPY startup.sh /startup.sh

# Expose ports
EXPOSE 1433

# Run as root user
USER root

# Run as mssql user
# USER mssql

# Run new startup script
CMD /bin/bash /startup.sh