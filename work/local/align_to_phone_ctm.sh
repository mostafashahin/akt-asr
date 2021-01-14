#!/bin/env bash

data_dir=$1
MDL=$2

. ./path.sh

#Convert text words to upper case
local/convert_text_case.sh $data_dir upper

steps/make_mfcc.sh --mfcc-config $MDL/conf/mfcc.conf $data_dir
steps/compute_cmvn_stats.sh $data_dir
utils/fix_data_dir.sh $data_dir

steps/online/nnet2/extract_ivectors_online.sh --nj 1 $data_dir/ $MDL/ivector_extractor/ $data_dir/ivector
steps/nnet3/align.sh --online-ivector-dir $data_dir/ivector/ --use-gpu false --nj 1 $data_dir/ $data_dir/lang/ austalk_model_online_chain2/ $data_dir/align

ali-to-phones --ctm-output $MDL/final.mdl ark:"gunzip -c $data_dir/align/ali.1.gz |" - | utils/int2sym.pl -f 5 $MDL/phones.txt - > $data_dir/align/ali.1.ctm


