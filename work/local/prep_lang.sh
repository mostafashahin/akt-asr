#Get master dictionary
#Get lm_train unique words
#Check if not exist in dict 
#Do g2p
#Create dict 
#Train LM
#Create lang dir
#check phone list compatibility
#generate graph

tasks="task1 task2 task5"
#DIR=/media/Windows/root/AusKidTalk/annotate1/
DIR=$1
ngr=3

set -e
#Get aus_dict last version
wget -O lexicon_au_sampa.dict https://raw.githubusercontent.com/mostafashahin/aus_lexicon/main/dicts/lexicon_au_sampa.txt

cat lexicon_au_sampa.dict | cut -f1 > lexicon_words.list
cat lexicon_au_sampa.dict | sort -u | docker run -i -w /opt/aus_lexicon g2p ./dict_tool/convert_dict.sh sampa asr > lexicon_au_asr.dict

for direct in `ls $DIR`
do
    stage=0

    childID=$direct

    LOCAL_OUT_DIR=$DIR/$direct

    [ -f $LOCAL_OUT_DIR/stage ] && stage=`cat $LOCAL_OUT_DIR/stage`

    [ $stage -ne 3 ] && continue

    #Fix data dir
    ./utils/data/fix_data_dir.sh $LOCAL_OUT_DIR/asr/data/

    #Split data dir into tasks
    for task in $tasks
    do
        grep $task $LOCAL_OUT_DIR/asr/data/segments | cut -d' ' -f1 > list_$task
        
        ./utils/data/subset_data_dir.sh --utt-list list_$task $LOCAL_OUT_DIR/asr/data $LOCAL_OUT_DIR/asr/data_$task
        
        rm list_$task
        
        #Get unique set of words

        cat $LOCAL_OUT_DIR/asr/data_$task/text | cut -d' ' -f2- | tr [:lower:] [:upper:] | xargs | tr [' '] ['\n'] > $LOCAL_OUT_DIR/asr/data_$task/words
        #Get OOV words

        set +e
        grep -xf $LOCAL_OUT_DIR/asr/data_$task/words lexicon_words.list | grep -xvf - $LOCAL_OUT_DIR/asr/data_$task/words > $LOCAL_OUT_DIR/asr/data_$task/oov_words
        set -e

        mkdir -p $LOCAL_OUT_DIR/asr/data_$task/dict
        if [ -s $LOCAL_OUT_DIR/asr/data_$task/oov_words ]; then
        #Get dict
            if [ "$(docker images -q g2p:latest)" = "" ]; then
                echo "g2p image not found!"
                exit 1
            fi
            
            cat $LOCAL_OUT_DIR/asr/data_$task/oov_words | docker run -i -w /opt/aus_lexicon/g2p/phonetisaurus g2p ./get_dict.sh | docker run -i -w /opt/aus_lexicon g2p ./dict_tool/convert_dict.sh sampa asr > $LOCAL_OUT_DIR/asr/data_$task/dict/oov_dict
            cat $LOCAL_OUT_DIR/asr/data_$task/dict/oov_dict lexicon_au_asr.dict | sort -u  > $LOCAL_OUT_DIR/asr/data_$task/dict/au_dict
        else
            cat lexicon_au_asr.dict | sort -u > $LOCAL_OUT_DIR/asr/data_$task/dict/au_dict
        fi
        ./local/prep_dict_dir.sh $LOCAL_OUT_DIR/asr/data_$task/dict/au_dict $LOCAL_OUT_DIR/asr/data_$task/dict
        ./utils/prepare_lang.sh $LOCAL_OUT_DIR/asr/data_$task/dict "<UNK>" $LOCAL_OUT_DIR/asr/data_$task/local/lang $LOCAL_OUT_DIR/asr/data_$task/lang
        ./local/prep_lm.sh $LOCAL_OUT_DIR/asr/data_$task $ngr
        echo 4 > $LOCAL_OUT_DIR/stage
    done
done



