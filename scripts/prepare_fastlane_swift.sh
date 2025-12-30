#!/bin/sh

# echo "git branch"
# git branch
# echo "git branch --show-current"
# git branch --show-current

test_files=()
test_lists=()

for entry in $(find ./SendbirdChatTests -type f -name "*.swift")
do
    test_files+=("${entry}")
done

# Iterate through files
for file in "${test_files[@]}"; do
    current_class=""

    extracted_test_name=$(echo "$file" | awk -F'/' '{split($2, a, "/"); print a[1]}')

    # Iterate through each line in file
    while IFS= read -r line; do
        # Find the name of the class or extension
        if [[ $line =~ ^(class|final\ class)\ ([^:\ ]+) ]]; then
            current_class="${BASH_REMATCH[2]}"
            # Create a unique identifier for the class
            unique_id="${extracted_test_name}/${current_class}"
            # Check if this class is not already added to list
            if ! [[ " ${test_lists[*]} " =~ " ${unique_id} " ]]; then
                test_lists+=("${unique_id}")
                # echo "unique_id: ${unique_id}"
            fi
        fi
    done < "$file"
done

total_swift_file_count=5
num_test=${#test_lists[@]}
echo "number of test is ${num_test}"
test_num_for_container=$(($num_test / total_swift_file_count))

# Function to separate swift tests
separate_swift_tets() {
    local start_index=$1
    local end_index=$2
    local container_name=$3

    count=0
    local container_content=""

    for (( c=start_index; c<end_index; c++ ))
    do
        ((count=count+1))
        container_content+="${test_lists[$c]},"
    done

    echo "test ${container_name} contains ${count}"
    echo $container_content > "./tests/swift-test-${container_name}.tests"
    # echo "tests in ${container_name}:${container_content}"
}

mkdir -p ./tests

# Main loop to create test lists
for (( i=0; i<total_swift_file_count; i++ ))
do
    start=$(( $i * $test_num_for_container ))
    end=$(( $start + $test_num_for_container ))
    end=$(( $i == (total_swift_file_count-1) ? $num_test : $end )) # Adjust end index for the last container

    separate_swift_tets $start $end $((i+1))
done
