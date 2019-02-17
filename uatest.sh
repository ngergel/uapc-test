#!/bin/bash

# Script that tests a given contest problem from Kattis.
# This script supports C, C++, and Python 3.

# Global variables.
SOURCE_PATH="$(find ~/ -name "uapsc-test" 2> >(grep -v 'Permission denied' >&2))"
DIR="${SOURCE_PATH}/tmp"
CONFIG="${DIR}/prob.conf"
ARGS=("$@")

# Argument iterator.
i="0"

# Flags to compile C/C++ programs with.
CFLAGS="-Wall"

# https://unix.stackexchange.com/questions/12068/how-to-measure-time-of-program-execution-and-store-that-inside-a-variable
# https://stackoverflow.com/questions/16548528/command-to-get-time-in-milliseconds
# https://www.tecmint.com/find-directory-in-linux/
# https://stackoverflow.com/questions/762348/how-can-i-exclude-all-permission-denied-messages-from-find
# https://stackoverflow.com/questions/10307280/how-to-define-a-shell-script-with-variable-number-of-arguments

# Prints correct usage. Takes in an argument as the error message.
usage() {
	echo -e "Error: Please specify a $1."
	echo "Usage: ./uatest.sh [options] <command> [-p problem] [file-name]"
	exit 2
}

# Verify a command or option is given.
test $# -eq 0 && usage command

# Help option.
if [ $1 = "-h" ] || [ $1 = "--help" ] || [ $1 = "help" ]
then
	cat $SOURCE_PATH/src/help.txt && exit 0 || exit 1
fi

# Clean command.
test $1 = "clean" && rm -rf $DIR && exit 0

# Check for options.
test $i -lt $# && test ${ARGS[$i]} = "-o" && output_flag="1" && (( i++ ))

# Verify a command is given after the options.
test ! $i -lt $# && usage command

# Test command.
if [ ${ARGS[$i]} = "test" ]
then
	(( i++ ))

	# Get problem id from file if possible.
	test -f $CONFIG && . $CONFIG
	
	# If problem id and file is given as arguments.
	if [ $((i + 2)) -lt $# ]
	then
		new_prob="${ARGS[$(( ++i ))]}"
		new_file="${ARGS[$(( ++i ))]}"
	fi

	# If arguments differ from config data, download new test cases.
	if [ $new_prob ] && { [ -z $PROB ] || [ $new_prob != $PROB ]; }
	then
		printf "Downloading test cases..."
		PROB="$new_prob" && FILE="$new_file"

		# Download sample test cases.
		mkdir -p $DIR
		wget -q -O $DIR/samples.zip https://open.kattis.com/problems/$PROB/file/statement/samples.zip > /dev/null

		# Catch when not downloadable.
		if [ $? -ne 0 ]; then
			echo -e "\nUnable to download sample test cases from Kattis."
			rm -f $DIR/samples.zip
			exit 1
		else
			echo "downloaded!"
			rm -f $DIR/*.in $DIR/*.ans
			unzip -q $DIR/samples.zip -d $DIR
			rm -f $DIR/samples.zip
		fi
	elif [ $new_file ]
	then
		# Update file if it has changed but the problem has not.
		FILE="$new_file"
	fi

	# Check if problem id or file has been given.
	test -z $PROB$FILE && usage "problem id and file"
	test -z $PROB && usage "problem id"
	test -z $FILE && usage file

	# Catch non-supported languages.
	if [[ $FILE != *".c" ]] && [[ $FILE != *".cpp" ]] && [[ $FILE != *".py" ]]
	then
		echo "This script only supports C, C++, and Python 3."
		exit 2
	fi

	# Update config file.
	echo -e "PROB=$PROB\nFILE=$FILE" > $CONFIG

	# Tells the player what problem they are testing incase of issues.
	echo -e "Problem id: $PROB\nFile: $FILE\n"

	# Compile C or C++.
	if [[ $FILE == *".c" ]] || [[ $FILE == *".cpp" ]]
	then
		# Compile the program.
		g++ $FILE $CFLAGS -o $DIR/a.out
		
		# Exit on a compile error.
		if [ $? -ne 0 ]
		then
			echo -e "Failed tests: \033[31mCompile Error\033[m"
			exit 1
		fi
	fi

	# Run against test cases.
	for i in $DIR/*.in
	do
		# Run the program against the test case.
		if [[ $FILE == *".c" ]] || [[ $FILE == *".cpp" ]]
		then
			START=$(date +%s%3N)
			$DIR/a.out < $i > ${i%.*}.test
			COMP=$?
			TIME=$(($(date +%s%3N)-START))
		elif [[ $FILE == *".py" ]]
		then
			START=$(date +%s%3N)
			python3 $FILE < $i > ${i%.*}.test
			COMP=$?
			TIME=$(($(date +%s%3N)-START))
		else
			echo "This script only supports C, C++, and Python 3."
			exit 2
		fi

		# See what the result was.
		if diff ${i%.*}.test ${i%.*}.ans > /dev/null
		then
			echo -e "${i##*/}: \033[32mCorrect Answer\033[m...${TIME}ms"
		elif [ $COMP -eq 0 ]
		then
			echo -e "${i##*/}: \033[31mWrong Answer\033[m...${TIME}ms"
		else
			echo -e "${i##*/}: \033[31mRuntime Error\033[m...${TIME}ms\n"
		fi

		# If the output flag was set, print the output.
		if [ $output_flag ] && [ $COMP -eq 0 ]
		then
			cat ${i%.*}.test && echo
		fi

		# Remove the produced output file.
		rm -f ${i%.*}.test
	done
	
	# Remove C/C++ binary and exit.
	rm -f $DIR/a.out
	exit 0
fi

# Submit command.
if [ ${ARGS[$i]} = "submit" ]
then
	(( i++ ))
	
	# Get problem id from file if possible.
	test -f $CONFIG && . $CONFIG
	
	# If problem id and file is given as arguments.
	if [ $((i + 2)) -lt $# ]
	then
		PROB="${ARGS[$(( ++i ))]}"
		FILE="${ARGS[$(( ++i ))]}"
	fi

	# Check if problem id or file has been given.
	test -z $PROB$FILE && usage "problem id and file"
	test -z $PROB && usage "problem id"
	test -z $FILE && usage file

	# Submit the file to Kattis, clean, and exit.
	python3 src/submit.py -p $PROB $FILE -f
	rm -rf $DIR
	exit 0
fi