#!/bin/bash

log_file="/dev/null"

print_help() {
  echo "This script is for converting blu rays to compressed mkv files in order to save space"
  echo ""
  echo "Options:"
  echo ""
  echo "-f | --file         CSV file containing input and output file names (Required)."
  echo "                    Format of the csv file:"
  echo "                    input_path;output_path"
  echo "                    Use only full file paths!"
  echo "-l | --log-file     Path to the log file, default is /home/sams/custom_scripts/convert_videos.log." 
  echo "                    If no log file is speified, nothing gets logged"
  echo "-h | --help         Print this help message."
}

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -f|--file)
      i_o_csv="$2"
      shift # past argument
      shift # past value
      ;;
    -l|--log-file)
      log_file="$2"
      shift # past argument
      shift # past value
      ;;
    *)    # unknown option
      print_help
      exit 0
      ;;
  esac
done

if ! [[ -v i_o_csv ]]
then
  echo "Please specify the path to a csv file containing input and output file paths"
  echo "Exiting..."
  exit 0
fi

mkdir -p "$(dirname $log_file)"
echo -e "Starting Video Conversion Script\n" | tee $log_file

skipped_files=()
conversion_failed=()
conversion_succeeded=()
number_of_input_lines=$(wc -l $i_o_csv | cut -d" " -f1)
current_input_line=1

while IFS=";" read input_name output_name 
do
  echo "---------------------------"
  echo "Converting file ( $current_input_line / $number_of_input_lines ) "
  echo "---------------------------"
  current_input_line=$((current_input_line+1))
  
  # check if input file exists and is readable by the user
  if ! [[ -r $input_name ]]
  then
    echo "File '$input_name' does not exists or user has no permission to read it." | tee -a $log_file
    echo "Skipping File..." | tee -a $log_file
    skipped_files+=("\n$input_name")
    continue
  fi

  # check if input and output file names are the same (would result in strange overrides
  if [[ $input_name = $output_name ]]
  then
    echo "Input and output file names are the same. This is not allowed for this script." | tee -a $log_file
    echo "Skipping File..." | tee -a $log_file
    skipped_files+=("\n$input_name")
    continue
  fi
  
  # create output directory if it does not exist
  mkdir -p "$(dirname $output_name)" | tee -a $log_file

  # convert video file
  ffmpeg -i $input_name -c:v libx256 -map 0 -c:s dvd_subtitle -crf 20 $output_name | tee -a $log_file

  # check for the exit code of ffmpeg to determine success (=delete the source file) or failure (=delete destination)
  if [[ $? -eq 0 ]]
  then
    echo "Conversion succeeded. Deleting source file..." | tee -a $log_file
    rm -v $input_name | tee -a $log_file
    conversion_succeeded+=("\n$input_name")
  else
    echo "Conversion failed. Deleting destination file - might be incomplete or corrupt..." | tee -a $log_file
    rm -v $output_name | tee -a $log_file
    conversion_failed+=("\n$input_name")
  fi

  # removing input and output directories (and their parents) if they are empty
  rmdir -pv "$(dirname $output_name)" | tee -a $log_file
  rmdir -pv "$(dirname $input_name)" | tee -a $log_file
  echo "input: $input_name"
  echo "output: $output_name"
done < $i_o_csv

echo -e "\nExecution finished." | tee -a $log_file
echo -e "Skipped input files: ${skipped_files[*]}" | tee -a $log_file
echo -e "Failed input files: ${conversion_failed[*]}" | tee -a $log_file
echo -e "Successful input files: ${conversion_succeeded[*]}" | tee -a $log_file


