#!/bin/sh

# echo "git branch"
# git branch
# echo "git branch --show-current"
# git branch --show-current

test_files=()
test_lists=()

for entry in $(find ./SendbirdChatObjcTests -type f -name "*.m")
do
	test_files+=("${entry}")
done

prefix="./"
suffix=".m"

for test_file in "${test_files[@]}"
do
	test_cases=(`cat $test_file | grep ^"- (void)test" | awk '{split($2, a, ")"); print a[2]}'`)
	for test_case in "${test_cases[@]}"
	do
		if ! [ -z "$test_case" ]; then
			tmp_test_class=${test_file#$prefix}
			tmp_test_class2=${tmp_test_class%$suffix}
			test_class=`echo ${tmp_test_class2} | awk '{split($0, a, "/"); print a[1]"/"a[length(a)]}'`
			test_item="$test_class/$test_case"
			test_lists+=("${test_item}")
			# echo "test item: $test_item"
		fi
	done
done

num_test=${#test_lists[@]}
echo "number of test is ${num_test}"
num_containers=4
total_shares=9
declare -a test_counts

for (( i=0; i<num_containers; i++ )); do
  if [ "$i" -eq "$((num_containers - 1))" ]; then
    # Last container gets 1.5
    test_counts[$i]=$(( num_test * 3 / total_shares ))
  else
    # Others get equal parts of 1
    test_counts[$i]=$(( num_test * 2 / total_shares ))
  fi
done

total_assigned=0
for count in "${test_counts[@]}"; do
  total_assigned=$(( total_assigned + count ))
done

# Distribute any remaining tests
remaining=$(( num_test - total_assigned ))
echo "Remaining tests after initial distribution: $remaining"
for (( i=0; i<remaining; i++ )); do
  test_counts[$i]=$(( test_counts[$i] + 1 ))
done

declare -a test_containers

index=0
for (( i=0; i<num_containers; i++ )); do
  count=${test_counts[$i]}
  test_containers[$i]=""
  for (( j=0; j<$count && $index<$num_test; j++ )); do
    test_containers[$i]+="${test_lists[$index]},"
    ((index++))
  done
done

mkdir -p ./tests
for (( i=0; i<$num_containers; i++ )); do
  ordinal=$(($i+1))
  if [ "$ordinal" -eq 1 ]; then
    suffix="st"
  elif [ "$ordinal" -eq 2 ]; then
    suffix="nd"
  elif [ "$ordinal" -eq 3 ]; then
    suffix="rd"
  else
    suffix="th"
  fi
  echo "Container $((i+1)) has $(echo "${test_containers[$i]}" | tr ',' '\n' | grep -c .) tests"
  echo "${test_containers[$i]}" > ./tests/${ordinal}${suffix}.tests
done
