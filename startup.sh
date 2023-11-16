#!/bin/bash

# Checks if BOOTSTRAP_DELAY is set and is a valid integer, defaults to 30 seconds if not set or invalid.
if [[ -z "$BOOTSTRAP_DELAY" || ! "$BOOTSTRAP_DELAY" =~ ^[0-9]+$ ]]; then
    BOOTSTRAP_DELAY=30
fi

# Function to start SQL Server in the background and check its availability.
start_sql_server() {
    # Start SQL Server in the background.
    /opt/mssql/bin/sqlservr &
    
    # Echoes a message indicating the start of the SQL Server.
    echo "############################### Waiting for SQL Server to start up..."
    
    # Counter to track the number of seconds waited.
    counter=0

    # Loop to check if SQL Server is up and running by checking port 1433.
    while ! nc -z localhost 1433; do
        sleep 1
        counter=$((counter + 1))
        # If SQL Server doesn't start within 60 seconds, script exits with an error message.
        if [ $counter -ge 60 ]; then
            echo "############################### SQL Server did not start within 60 seconds. Exiting."
            exit 1
        fi
    done

    # Waits an additional 10 seconds after SQL Server starts for it to fully initialize.
    echo "############################### SQL Server started, waiting 30 seconds to allow things to fully warm up"
    sleep 30
}

# Function to install a certificate if the required variables are set.
install_certificate() {
    # Checks if certificate file, private key file, and password are provided.
    if [ -n "$CERTIFICATE_FILE" ] && [ -n "$PRIVATE_KEY_FILE" ] && [ -n "$CERTIFICATE_PASSWORD" ]; then
        # Checks if the master key already exists in the master database.
        echo "############################### Checking for existing master key..."
        if /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -Q "USE master; SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##';" | grep -q "##MS_DatabaseMasterKey##"; then
            echo "############################### Master Key already exists, skipping creation."
        else
            # Creates the master key if it does not already exist.
            echo "############################### Creating master key..."
            /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -Q "USE master; CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$CERTIFICATE_PASSWORD';"
        fi

        # Checks if the certificate already exists.
        echo "############################### Checking for existing certificate..."
        if /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -Q "USE master; SELECT * FROM sys.certificates WHERE name = 'TDE_Certificate';" | grep -q "TDE_Certificate"; then
            echo "############################### Certificate 'TDE_Certificate' already exists, skipping installation."
        else
            # Installs the certificate if it does not already exist.
            echo "############################### Installing certificate from $CERTIFICATE_FILE..."
            /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -Q "USE master; CREATE CERTIFICATE TDE_Certificate FROM FILE = '$CERTIFICATE_FILE' WITH PRIVATE KEY (FILE = '$PRIVATE_KEY_FILE', DECRYPTION BY PASSWORD = '$CERTIFICATE_PASSWORD');"
        fi
    else
        echo "############################### Certificate file, private key file, or password not set, skipping certificate installation."
    fi
}

# Function to adjust SQL Server's maximum memory limit based on an environment variable.
adjust_memory_limit() {
    # Checks if the memory limit environment variable is set.
    if [ -z "$MSSQL_MAX_MEMORYLIMIT_MB" ]; then
        echo "############################### MSSQL_MAX_MEMORYLIMIT_MB is not set. Skipping."
    else
        # Sets the maximum server memory in SQL Server to the specified limit.
        echo "############################### MSSQL_MAX_MEMORYLIMIT_MB is set. Setting max server memory to $MSSQL_MAX_MEMORYLIMIT_MB MB"
        /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -Q "EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'max server memory', $MSSQL_MAX_MEMORYLIMIT_MB; RECONFIGURE;"
    fi
}

# Function to run a bootstrap script if provided.
run_bootstrp_script() {
    # Checks if the bootstrap script environment variable is set.
    if [ -z "$BOOTSTRAP_SCRIPT" ]; then
        echo "############################### BOOTSTRAP_SCRIPT is not set. Starting SQL Server."
    else
        # Checks if the bootstrap script has been run previously to avoid re-running it.
        if [ -f "/var/opt/mssql/data/bootstrap_started" ]; then
            echo "############################### Bootstrap script has been started before, skipping."
        else
            echo "############################### BOOTSTRAP_SCRIPT is set."

            # Creates a file indicating the bootstrap script has started.
            touch /var/opt/mssql/data/bootstrap_started

            # Delays the execution of the bootstrap script based on BOOTSTRAP_DELAY.
            echo "############################### Waiting for $BOOTSTRAP_DELAY seconds before running bootstrap script"
            sleep ${BOOTSTRAP_DELAY}

            # Determines how to run the bootstrap script based on its file extension.
            if [[ "$BOOTSTRAP_SCRIPT" == *".ps1" ]]; then
                echo "############################### Running bootstrap script with PowerShell..."
                pwsh ${BOOTSTRAP_SCRIPT}
            elif [[ "$BOOTSTRAP_SCRIPT" == *".sh" ]]; then
                echo "############################### Running bootstrap script with Bash..."
                bash ${BOOTSTRAP_SCRIPT}
            else
                echo "############################### No specific script extension detected for BOOTSTRAP_SCRIPT. Attempting to run directly..."
                ${BOOTSTRAP_SCRIPT}
            fi

            # Marks the completion of the bootstrap script.
            touch /var/opt/mssql/data/bootstrap_done
        fi
    fi
}

# Executing the functions in order.
start_sql_server
adjust_memory_limit
install_certificate
run_bootstrp_script

# Keep script running
wait