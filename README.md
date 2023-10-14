
# MSSQL Docker Image

This repository provides a custom Docker image for Microsoft SQL Server with additional configurations and capabilities.

## Description

The Docker image is based on the official [Microsoft SQL Server Docker Image](https://github.com/Microsoft/mssql-docker). It builds upon this by enabling additional features and configurations, such as:
- Enabling SQL Server Agent.
- Installing additional modules and tools like PowerShell, SQL Server modules, and Azure modules.
- Adjusting server memory limits.
- Additional startup configuration with a custom startup script.

## Dockerfile

The provided Dockerfile installs various necessary packages and configurations to support the additional capabilities mentioned above.

## Startup Script

The `startup.sh` script, which is copied into the Docker image, enables additional functionalities and configurations:
- It enables waiting for SQL Server to start up, ensuring that it is ready to accept connections before proceeding with further configurations or operations.
- It allows for the setting of max server memory limits when the Docker container is started.
- It checks for a bootstrap script and executes it after a delay specified by the `BOOTSTRAP_DELAY` environment variable.

## Usage

### Building the Docker Image

To build the Docker image, you can use the Docker CLI as follows:

```sh
docker build -t custom-mssql:latest .
```

### Running a Container from the Image

To run a container using the built image, use the following command:

```sh
docker run -d --name sqlserver --restart always --platform=linux/amd64 --cap-add SYS_PTRACE --env MSSQL_MAX_MEMORYLIMIT_MB=2048 --env TZ=America/Chicago --env 'ACCEPT_EULA=1' --env 'MSSQL_SA_PASSWORD=<YourPassword>' -p 1433:1433 cjgaspard/mssql-server:2022-ubuntu-20.04
```

Ensure to replace `<YourPassword>` with your desired SA password.

### Environment Variables

The Docker image uses the following environment variables:

- `BOOTSTRAP_DELAY`: (Optional) Time to wait in seconds before running the bootstrap script. Default is 30 seconds.
- `BOOTSTRAP_SCRIPT`: (Optional) Path to a PowerShell script that will be executed after the SQL Server has started and after the bootstrap delay.
- `MSSQL_MAX_MEMORYLIMIT_MB`: (Optional) Sets the maximum amount of memory that SQL Server can use.
- `ACCEPT_EULA`: (Required) Set to `Y` to accept the SQL Server license agreement.
- `SA_PASSWORD`: (Required) Password for the SQL Server SA user.

Ensure to set the mandatory environment variables (`ACCEPT_EULA` and `SA_PASSWORD`) when starting your container.

## License

This project uses the [MIT License](LICENSE).
