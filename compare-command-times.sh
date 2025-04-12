#!/bin/bash

# Function to read .env file
get_env_value() {
    local key=$1
    if [ -f .env ]; then
        grep "^$key=" .env | cut -d '=' -f2
    else
        echo "Cannot find .env file or $key in .env file" >&2
        exit 1
    fi
}

# Store original location and change to script directory
ORIGINAL_DIR=$(pwd)
cd "$(dirname "$0")"

STORAGE_ACCOUNT_NAME=$(get_env_value "STORAGE_ACCOUNT_NAME")

# Define commands
declare -A commands
commands["dotnet run command"]="dotnet run"
commands["az command"]="az storage table list --account-name $STORAGE_ACCOUNT_NAME --auth-mode login"

echo -e "\e[36mStarting command execution time comparison...\e[0m"
echo -e "\e[36m=============================================\e[0m"

# Array to store results
declare -A execution_times
declare -A command_success
declare -A command_output
declare -A command_errors

for cmd_name in "${!commands[@]}"; do
    echo -e "\n\e[33mExecuting: $cmd_name\e[0m"
    echo "Command: ${commands[$cmd_name]}"
    
    start_time=$(date +%s.%N)
    
    if output=$(eval "${commands[$cmd_name]}" 2>&1); then
        end_time=$(date +%s.%N)
        execution_time=$(echo "$end_time - $start_time" | bc)
        execution_times[$cmd_name]=$execution_time
        command_success[$cmd_name]=true
        command_output[$cmd_name]=$output
    else
        end_time=$(date +%s.%N)
        execution_time=$(echo "$end_time - $start_time" | bc)
        execution_times[$cmd_name]=$execution_time
        command_success[$cmd_name]=false
        command_errors[$cmd_name]=$output
    fi
done

echo -e "\n\e[32mResults Summary:\e[0m"
echo -e "\e[32m================\e[0m"

for cmd_name in "${!commands[@]}"; do
    echo -e "\n\e[36mCommand Name: $cmd_name\e[0m"
    echo -e "\e[36mFull Command: ${commands[$cmd_name]}\e[0m"
    printf "Execution Time: %.3f seconds\n" "${execution_times[$cmd_name]}"
    
    if [ "${command_success[$cmd_name]}" = true ]; then
        echo -e "\e[32mStatus: Success\e[0m"
    else
        echo -e "\e[31mStatus: Failed\e[0m"
        echo "Error: ${command_errors[$cmd_name]}"
    fi
done

# Compare times if both commands succeeded
if [ "${command_success["dotnet run command"]}" = true ] && [ "${command_success["az command"]}" = true ]; then
    time_diff=$(echo "${execution_times["dotnet run command"]} - ${execution_times["az command"]}" | bc)
    if (( $(echo "$time_diff > 0" | bc -l) )); then
        faster_command="az command"
        difference=$time_diff
    else
        faster_command="dotnet run command"
        difference=$(echo "$time_diff * -1" | bc)
    fi
    
    echo -e "\n\e[35mComparison:\e[0m"
    echo -e "\e[35m===========\e[0m"
    printf "$faster_command was faster by %.3f seconds\n" $difference
    
    echo -e "\n\e[35mFull Command Details of Faster Operation:\e[0m"
    echo "${commands[$faster_command]}"
fi

# Restore original location
cd "$ORIGINAL_DIR"
