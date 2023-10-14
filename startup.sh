#!/bin/bash

# Check if BOOTSTRAP_DELAY is set and is a valid integer. If not, default to 30 seconds.
if [[ -z "$BOOTSTRAP_DELAY" || ! "$BOOTSTRAP_DELAY" =~ ^[0-9]+$ ]]; then
    BOOTSTRAP_DELAY=30
fi

# Check for the environment variable
if [ -z "$BOOTSTRAP_SCRIPT" ]; then
    echo "BOOTSTRAP_SCRIPT is not set. Starting SQL Server."
    # Just start SQL Server if the environment variable is not present
    /opt/mssql/bin/sqlservr &

    #if the enviroment variable MemoryLimitsMB exists, then set the max server memory after we confirm sql is running
    if [ -z "$MSSQL_MAX_MEMORYLIMIT_MB" ]; then
        echo "MSSQL_MAX_MEMORYLIMIT_MB is not set. Skipping."
    else
        # Wait for SQL Server to start up
        echo "MSSQL_MAX_MEMORYLIMIT_MB is set, waiting for SQL Server to start..."
        counter=0
        while ! nc -z localhost 1433; do
            sleep 1
            counter=$((counter + 1))
            if [ $counter -ge 60 ]; then
                echo "SQL Server did not start within 60 seconds. Exiting."
                exit 1
            fi
        done
        echo "SQL Server started, waiting 60 seconds before attemptiong to adjust memory limits"
        sleep 60
        echo "MSSQL_MAX_MEMORYLIMIT_MB is set. Setting max server memory to $MSSQL_MAX_MEMORYLIMIT_MB MB"
        /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -Q "EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'max server memory', $MSSQL_MAX_MEMORYLIMIT_MB; RECONFIGURE;"
    fi

    # Keep script running
    wait

else

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

    if [ -z "$MSSQL_MAX_MEMORYLIMIT_MB" ]; then
        echo "MSSQL_MAX_MEMORYLIMIT_MB is not set. Skipping."
    else
        echo "SQL Server started, waiting 60 seconds before attemptiong to adjust memory limits"
        sleep 60
        echo "MSSQL_MAX_MEMORYLIMIT_MB is set. Setting max server memory. $MSSQL_MAX_MEMORYLIMIT_MB MB"
        /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -Q "EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'max server memory', $MSSQL_MAX_MEMORYLIMIT_MB; RECONFIGURE;"
    fi

    # Check if the bootstrap script has been run before
    if [ -f "/var/opt/mssql/data/bootstrap_started" ]; then
        echo "Bootstrap script has been started before, skipping."
    else
        echo "BOOTSTRAP_SCRIPT is set. Starting SQL Server and running bootstrap script."

        # Mark the bootstrap script as done
        touch /var/opt/mssql/data/bootstrap_started

        echo "Waiting for $BOOTSTRAP_DELAY seconds..."
        sleep ${BOOTSTRAP_DELAY}

        # Run the bootstrap script
        pwsh ${BOOTSTRAP_SCRIPT}

        touch /var/opt/mssql/data/bootstrap_done

    fi
    # Keep script running
    wait
fi
