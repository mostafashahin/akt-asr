#!/bin/bash

AUSDICT=$1
DICT_DIR=$2

[ -f $AUSDICT ] || exit 1

mkdir -p $DICT_DIR

cp $AUSDICT $DICT_DIR/lexicon.tmp

cat $DICT_DIR/lexicon.tmp | sort -u > $DICT_DIR/lexicon.txt

cat $DICT_DIR/lexicon.txt | cut -f2- | tr ' ' '\n' | sort -u > $DICT_DIR/nonsilence_phones.txt


echo '<UNK> SPN' >> $DICT_DIR/lexicon.txt

echo "SIL" > $DICT_DIR/optional_silence.txt

(echo SIL; echo SPN; echo NSN) > $DICT_DIR/silence_phones.txt
