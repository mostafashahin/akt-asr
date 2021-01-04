#!/bin/bash

#This code for preparing the data/l/dict dirictory of OGI kids data for kaldi ASR training
#Should be run from s5 directory

. ./path.sh
. ./cmd.sh
if [ $# != 2 ]; then
        echo "Usage: $(basename $0) /path/to/data_dir ngr"
        exit 1;
fi
DIR=$1

oov_symbol="<UNK>"
suffix=
lm_dir=$DIR/local/srilm
ngr=$2
langdir=$DIR/lang

mkdir -p $lm_dir

./utils/parse_options.sh

lm=${lm_dir}/${ngr}gram.gz
#Make sure that srilm installed
echo $KALDI_ROOT/tools/srilm/bin/i686-m64
which ngram-count
if [ $? -ne 0 ]; then
    if [ -d $KALDI_ROOT/tools/srilm/bin/i686-m64 ]; then
        export PATH=$PATH:$KALDI_ROOT/tools/srilm/bin/i686-m64
    fi
fi

cat $DIR/text | tr '\t' ' ' | cut -d' ' -f2- | tr [:lower:] [:upper:] > $lm_dir/train.txt

ngram-count -text $lm_dir/train.txt -order ${ngr} -lm - -unk -sort -maxent -maxent-convert-to-arpa |\
     ngram -lm - -order ${ngr} -unk -map-unk "$oov_symbol" -prune-lowprobs -write-lm - |\
     sed 's/<unk>/'${oov_symbol}'/g' | gzip -c > $lm

./utils/format_lm.sh $langdir $lm $DIR/dict/lexicon.txt $DIR/lang_test${ngr}gr

