#!/bin/env bash
. ./cmd.sh
. ./path.sh

tasks="task1 task2 task5"
#DIR=/media/Windows/root/AusKidTalk/annotate1/
DIR=$1
MDL=$2
ngr=3

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
        if [ $task_stage -eq 4 ]; then
            utils/mkgraph.sh --self-loop-scale 1.0 $LOCAL_OUT_DIR/asr/data_${task}/lang_test3gr/ $MDL/ $LOCAL_OUT_DIR/asr/data_${task}/lang_test3gr/graph_decode/ || { all_tasks=false && continue; }
            task_stage=5
            echo $task_stage > $LOCAL_OUT_DIR/asr/data_$task/stage
        fi

        if [ $task_stage -eq 5 ]; then
            steps/online/nnet3/decode.sh \
                --acwt 1.0 --post-decode-acwt 10.0 \
                --nj 1 --cmd "$decode_cmd" \
                --skip_scoring true \
                $LOCAL_OUT_DIR/asr/data_${task}/lang_test3gr/graph_decode/ \
                $LOCAL_OUT_DIR/asr/data_${task}/ $MDL/${childID}_${task}_decode || { all_tasks=false && continue; }
            task_stage=6
            mv $MDL/${childID}_${task}_decode $LOCAL_OUT_DIR/asr/data_${task}/${childID}_${task}_decode
            echo $task_stage > $LOCAL_OUT_DIR/asr/data_$task/stage
        fi

        if [ $task_stage -eq 6 ]; then
            mkdir -p $LOCAL_OUT_DIR/asr/data_${task}/kws
            
            cat $LOCAL_OUT_DIR/asr/data_${task}/text | cut -d' ' -f2- | tr [:lower:] [:upper:] | sort -u > $LOCAL_OUT_DIR/asr/data_${task}/kws/raw_keywords.txt || { all_tasks=false && continue; }
            
            ./local/kws_data_prep.sh $LOCAL_OUT_DIR/asr/data_${task}/lang $LOCAL_OUT_DIR/asr/data_${task}/ $LOCAL_OUT_DIR/asr/data_${task}/kws || { all_tasks=false && continue; }
            
            ./steps/make_index.sh $LOCAL_OUT_DIR/asr/data_${task}/kws/ $LOCAL_OUT_DIR/asr/data_${task}/lang_test3gr/ $LOCAL_OUT_DIR/asr/data_${task}/${childID}_${task}_decode $LOCAL_OUT_DIR/asr/data_${task}/kws/ || { all_tasks=false && continue; }
            
            ./steps/search_index.sh $LOCAL_OUT_DIR/asr/data_${task}/kws/ $LOCAL_OUT_DIR/asr/data_${task}/kws || { all_tasks=false && continue; }
            
            gunzip -c $LOCAL_OUT_DIR/asr/data_${task}/kws/result.*.gz > $LOCAL_OUT_DIR/asr/data_${task}/kws/results || { all_tasks=false && continue; }

            task_stage=7

            echo $task_stage > $LOCAL_OUT_DIR/asr/data_$task/stage
            
        fi
        if [ $task_stage -eq 7 ]; then

            local/kws_to_txtgrid.py -tg $LOCAL_OUT_DIR/txtgrids/primary_16b_${task}.txtgrid $LOCAL_OUT_DIR/asr/data_${task}/kws/results $LOCAL_OUT_DIR/asr/data_${task}/ $LOCAL_OUT_DIR/asr/data_${task}/kws/ $LOCAL_OUT_DIR/txtgrids/primary_16b_${task}.wav  $LOCAL_OUT_DIR/txtgrids/primary_16b_${task}_kws2.txtgrid || { all_tasks=false && continue; }

            task_stage=8
            echo $task_stage > $LOCAL_OUT_DIR/asr/data_$task/stage
            
        fi
    done
    $all_tasks && echo 8 > $LOCAL_OUT_DIR/stage 
done