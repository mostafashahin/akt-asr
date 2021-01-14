import pandas as pd
import re
from collections import defaultdict
import wave
import txtgrid_master.TextGrid_Master as tg
import argparse
from os.path import join, basename, splitext

def RemovePositionalSymbl(symb):
    posSymbls = ['_I', '_B', '_E', '_S']
    return re.sub('|'.join(posSymbls),'',symb)

def MapSymb(symb, mapFile):
    #Load map file
    with open(mapFile,'r') as fIn:
        dMap = dict([tuple(line.split()) for line in fIn.read().splitlines()])
    maped_symb = dMap[symb] if symb in dMap else symb
    return maped_symb

def GetWordsFromCTM(pd_ctm_seg, lexiconFile):
    #Load lexicon
    dMap = defaultdict(list)
    with open(lexiconFile,'r') as fIn:
        for line in fIn.read().splitlines():
            lineS = line.split()
            dMap[''.join(lineS[1:])].append(lineS[0])
    words = [] ; stTimes = []; edTimes = []; absStTimes = []; absEdTimes = []
    cPhoneSeq = ''
    for i,r in pd_ctm_seg.iterrows():
        if '_B' in r.symb:
            cPhoneSeq = ''
            stTimes.append(r.symb_start_time)
            absStTimes.append(r.abs_start_time)
            cPhoneSeq += r.symb_NoPos
        elif '_I' in r.symb or '_S' in r.symb:
            cPhoneSeq += r.symb_NoPos
        elif '_E' in r.symb:
            cPhoneSeq += r.symb_NoPos
            for wrd in dMap[cPhoneSeq]:
                if wrd in r.prompt:
                    words.append(wrd)
                    break
            edTimes.append(r.symb_end_time)
            absEdTimes.append(r.abs_end_time)
            cPhoneSeq = ''
    d = {'word':words, 'start_time':stTimes, 'end_times':edTimes, 'abs_start_time':absStTimes, 'abs_end_time':absEdTimes}
    return pd.DataFrame(data=d)

def ArgParser():
    parser = argparse.ArgumentParser(description="This code convert phoneme ctm to txtgrid for AusKidTalk project", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('alignDir', help="Dir contains ctm file/s", type=str)
    parser.add_argument('dataDir', help="Dir contains segments and text files", type=str)
    parser.add_argument('speechFile', help="The task wave file")
    parser.add_argument('-p', '--phoneCTM', dest='bPhoneCTM', default=False, action='store_true', help="True if Input CTM is phone ctm")
    parser.add_argument('-w', '--wordCTM', dest='bWordCTM', default=False, action='store_true', help="True if Input CTM is word ctm or if with -p create word from phone ctm\ndictionary is needed and phones should have positional symbols")
    parser.add_argument('-l', '--lexicon', dest='lexiconFile', type=str, help="path to lexicon file nedded if -p and -w")
    parser.add_argument('-m', '--mapFile', dest='mapFile', type=str, help="map phoneme symbol to other phoneme symbols, only in case of -p")
    parser.add_argument('-tg', '--InTxtGrid', help="Textgrid to merge the output one to", type=str)

    return parser.parse_args()

def main():
    args = ArgParser()
    alignDir, dataDir, speechFile = args.alignDir, args.dataDir, args.speechFile
    bPhoneCTM = args.bPhoneCTM
    bWordCTM = args.bWordCTM
    lexiconFile, mapFile = args.lexiconFile, args.mapFile
    InTxtGrid = args.InTxtGrid

    if not bPhoneCTM and not bWordCTM:
        print("you have to specify either -p or -w or both")
        exit(1)
    
    #Get end time of speech file needed for writeTxtGrid function
    with wave.open(speechFile) as f:
        ET = f.getnframes() / f.getframerate()

    if bPhoneCTM:
        ctmFile = join(alignDir,'ali.1.ctm')
        segmFile = join(dataDir,'segments') #TODO check if file exist
        textFile = join(dataDir,'text') #TODO check if file exist
        
        #load ctm file
        ctmNames = ['segm_id', 'chnl_id', 'symb_start_time', 'symb_dur', 'symb']
        pd_ctm = pd.read_csv(ctmFile, delim_whitespace=True, names = ctmNames)
        pd_ctm['symb_end_time'] = pd_ctm.symb_start_time + pd_ctm.symb_dur
        
        #load segment file
        sgmNames = ['segm_id','record_id','seg_start_time','seg_end_time']
        pd_segm = pd.read_csv(segmFile, delim_whitespace=True, names= sgmNames)
        
        #Load Text File
        with open(textFile) as f:
            lines = [l.split() for l in f.read().splitlines()]
        d = {'segm_id':[],'prompt':[]}
        [(d['segm_id'].append(l[0]),d['prompt'].append(' '.join(l[1:]).upper())) for l in lines]
        pd_text = pd.DataFrame.from_dict(d)
            
        
        #Add symb without podsitional symb (to be ignored if word ctm)
        pd_ctm['symb_NoPos'] = pd_ctm.symb.map(RemovePositionalSymbl)

        #Merge ctm & segment & text
        pd_ctm_seg = pd_ctm.merge(pd_segm, how='left', on='segm_id')
        pd_ctm_seg = pd_ctm_seg.merge(pd_text, how='left', on='segm_id')
        
        #Get absolute start and end time
        pd_ctm_seg['abs_start_time'] = pd_ctm_seg['symb_start_time'] + pd_ctm_seg['seg_start_time']
        pd_ctm_seg['abs_end_time'] = pd_ctm_seg['symb_end_time'] + pd_ctm_seg['seg_start_time']
       
        #Map if nedded
        if mapFile:
            pd_ctm_seg['out_symb'] = pd_ctm_seg['symb_NoPos'].apply(MapSymb, args=(mapFile,))
        else:
            pd_ctm_seg['out_symb'] = pd_ctm_seg['symb_NoPos']
        
        #Write phone txtgrid
        dTier = {'align-ph':[pd_ctm_seg.abs_start_time.values, pd_ctm_seg.abs_end_time.values, pd_ctm_seg.out_symb.values]}
        dTier = tg.SortTxtGridDict(dTier)
        outTxtgrid = ''.join([splitext(speechFile)[0],'_align_ph.txtgrid'])
        tg.WriteTxtGrdFromDict(outTxtgrid, dTier, 0.0, ET, sFilGab='UNK')

        if bWordCTM:
            if lexiconFile:
                pd_words = GetWordsFromCTM(pd_ctm_seg,lexiconFile)
                
                #Write words txtgrid
                dTier = {'align-wrd':[pd_words.abs_start_time.values, pd_words.abs_end_time.values, pd_words.word.values]}
                dTier = tg.SortTxtGridDict(dTier)
                outTxtgrid = ''.join([splitext(speechFile)[0],'_align_wrd.txtgrid'])
                tg.WriteTxtGrdFromDict(outTxtgrid, dTier, 0.0, ET, sFilGab='UNK')

                #Write phone and word txtgrids
                dTier = {'align-ph':[pd_ctm_seg.abs_start_time.values, pd_ctm_seg.abs_end_time.values, pd_ctm_seg.out_symb.values], 'align-wrd':[pd_words.abs_start_time.values, pd_words.abs_end_time.values, pd_words.word.values]}
                dTier = tg.SortTxtGridDict(dTier)
                outTxtgrid = ''.join([splitext(speechFile)[0],'_align.txtgrid'])
                tg.WriteTxtGrdFromDict(outTxtgrid, dTier, 0.0, ET, sFilGab='UNK')
                if InTxtGrid:
                    sMergedTxtGrid = splitext(InTxtGrid)[0]+'_align_merged.txtgrid'
                    tg.MergeTxtGrids([outTxtgrid,InTxtGrid], sMergedTxtGrid, sWavFile=speechFile)
            else:
                print('Convert to word requested but lexicon file not given!')
        else:
            if InTxtGrid:
                sMergedTxtGrid = splitext(InTxtGrid)[0]+'_align_merged.txtgrid'
                tg.MergeTxtGrids([outTxtgrid,InTxtGrid], sMergedTxtGrid, sWavFile=speechFile)
    else:
        print('WORD CTM NOT SUPPORETED YET!')

if __name__=='__main__':
    main()
