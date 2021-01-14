data_dir=$1
target_case=$2

if [ $target_case == 'upper' ]; then
    awk '{printf $1 " "; for (i=2; i<=NF; i++) printf toupper($i) " "; printf "\n"}' $data_dir/text > tmp && mv tmp $data_dir/text
else
    awk '{printf $1 " "; for (i=2; i<=NF; i++) printf tolower($i) " "; printf "\n"}' $data_dir/text > tmp && mv tmp $data_dir/text
fi