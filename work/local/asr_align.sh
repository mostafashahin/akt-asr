#!/bin/env bash
. ./cmd.sh
. ./path.sh

tasks="task1 task2 task5"
#DIR=/media/Windows/root/AusKidTalk/annotate1/
DIR=$1
MDL=$2

set -e

for direct in `ls $DIR`
do
    stage=0
    task_stage=0
    all_tasks=true

    childID=$direct
    LOCAL_OUT_DIR=$DIR/$direct

    [ -f $LOCAL_OUT_DIR/stage ] && stage=`cat $LOCAL_OUT_DIR/stage`
    echo $stage
    [ $stage -eq 3 ] || [ $stage -eq 4 ] || { echo "Run prep_lang.sh first for child $childID" ; continue; }
    for task in $tasks
    do
        [ -f $LOCAL_OUT_DIR/asr/data_$task/stage ] && task_stage=`cat $LOCAL_OUT_DIR/asr/data_$task/stage`
        echo $task_stage
        [ ! $task_stage -ge 4 ] && { echo "Seems that prep_lang.sh faild for child $childID task $task" ; all_tasks=false; continue; }
        [ ! -f $LOCAL_OUT_DIR/asr/data_$task/align_stage ] && cp $LOCAL_OUT_DIR/asr/data_$task/stage $LOCAL_OUT_DIR/asr/data_$task/align_stage
        align_stage=`cat $LOCAL_OUT_DIR/asr/data_$task/align_stage`
        if [ $align_stage -eq 4 ]; then
            local/align_to_phone_ctm.sh  $LOCAL_OUT_DIR/asr/data_$task $MDL || { all_tasks=false && continue; }
            align_stage=5
            echo $align_stage > $LOCAL_OUT_DIR/asr/data_$task/align_stage
        fi

        if [ $align_stage -eq 5 ]; then
            wget -O asr2sampa.map https://raw.githubusercontent.com/mostafashahin/aus_lexicon/main/data/asr2sampa.map
            python3 local/ctm_to_txtgrid.py -tg $LOCAL_OUT_DIR/txtgrids/primary_16b_$task.txtgrid -p -w -l $LOCAL_OUT_DIR/asr/data_$task/dict/au_dict -m asr2sampa.map $LOCAL_OUT_DIR/asr/data_$task/align/ $LOCAL_OUT_DIR/asr/data_$task/ $LOCAL_OUT_DIR/txtgrids/primary_16b_$task.wav
            align_stage=6
            echo $align_stage > $LOCAL_OUT_DIR/asr/data_$task/align_stage
        fi
    done
    #$all_tasks && echo 8 > $LOCAL_OUT_DIR/stage 
done