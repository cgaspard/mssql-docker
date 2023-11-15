#!/bin/bash

# Check if BOOTSTRAP_DELAY is set and is a valid integer. If not, default to 30 seconds.
if [[ -z "$BOOTSTRAP_DELAY" || ! "$BOOTSTRAP_DELAY" =~ ^[0-9]+$ ]]; then
    BOOTSTRAP_DELAY=30
fi

start_sql_server() {
    # Start SQL Server in the background
    /opt/mssql/bin/sqlservr &
    
    # Wait for SQL Server to start up
    echo "Waiting for SQL Server to start up..."
    counter=0
    while ! nc -z localhost 1433; do
        sleep 1
        counter=$((counter + 1))
        if [ $counter -ge 60 ]; then
            echo "SQL Server did not start within 60 seconds. Exiting."
            exit 1
        fi
    done
}

install_certificate() {
    if [ -n "$CERTIFICATE_FILE" ] && [ -n "$PRIVATE_KEY_FILE" ] && [ -n "$CERTIFICATE_PASSWORD" ]; then
        echo "Installing certificate from $CERTIFICATE_FILE..."
        /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -Q "CREATE CERTIFICATE MyServerCert FROM FILE = '$CERTIFICATE_FILE' WITH PRIVATE KEY (FILE = '$PRIVATE_KEY_FILE', DECRYPTION BY PASSWORD = '$CERTIFICATE_PASSWORD');"
    else
        echo "Certificate file, private key file, or password not set, skipping certificate installation."
    fi
}

# Check for the environment variable
if [ -z "$BOOTSTRAP_SCRIPT" ]; then
    echo "BOOTSTRAP_SCRIPT is not set. Starting SQL Server."
    start_sql_server
    install_certificate
    
    # Handling Memory Limits
    if [ -z "$MSSQL_MAX_MEMORYLIMIT_MB" ]; then
        echo "MSSQL_MAX_MEMORYLIMIT_MB is not set. Skipping."
    else
        echo "SQL Server started, waiting 60 seconds before attempting to adjust memory limits"
        sleep 60
        echo "MSSQL_MAX_MEMORYLIMIT_MB is set. Setting max server memory to $MSSQL_MAX_MEMORYLIMIT_MB MB"
        /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -Q "EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'max server memory', $MSSQL_MAX_MEMORYLIMIT_MB; RECONFIGURE;"
    fi

    # Keep script running
    wait

else

    start_sql_server
    install_certificate

    # Check if the bootstrap script has been run before
    if [ -f "/var/opt/mssql/data/bootstrap_started" ]; then
        echo "Bootstrap script has been started before, skipping."
    else
        echo "BOOTSTRAP_SCRIPT is set. Starting SQL Server and running bootstrap script."

        # Mark the bootstrap script as done
        touch /var/opt/mssql/data/bootstrap_started

        echo "Waiting for $BOOTSTRAP_DELAY seconds..."
        sleep ${BOOTSTRAP_DELAY}

        # Run the bootstrap script based on its extension
        if [[ "$BOOTSTRAP_SCRIPT" == *".ps1" ]]; then
            echo "Running bootstrap script with PowerShell..."
            pwsh ${BOOTSTRAP_SCRIPT}
        elif [[ "$BOOTSTRAP_SCRIPT" == *".sh" ]]; then
            echo "Running bootstrap script with Bash..."
            bash ${BOOTSTRAP_SCRIPT}
        else
            echo "No specific script extension detected for BOOTSTRAP_SCRIPT. Attempting to run directly..."
            ${BOOTSTRAP_SCRIPT}
        fi

        touch /var/opt/mssql/data/bootstrap_done

    fi
    # Keep script running
    wait
fi
