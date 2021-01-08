#!/bin/env python3
import pandas as pd
import  numpy as np
from os.path import join, basename, splitext
import txtgrid_master.TextGrid_Master as tg
from scipy.ndimage.interpolation import shift
import wave
import argparse


def ArgParser():
    parser = argparse.ArgumentParser(description="Code to convert kws results out from search_index script to text grid format", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('kwsFile', help="The kws results from search_index script", type=str)
    parser.add_argument('dataDir', help="kaldi data dir contains: segments and text files", type=str)
    parser.add_argument('kwsDir', help="kaldi kws dir contains: keywords.txt and utter_id files", type=str)
    #TODO handle multiple speech files
    parser.add_argument('sSpeechFile', help="speech file, needed for computing the total duration", type=str)
    parser.add_argument('outFile', help="Output txtgrid file", type=str)
    parser.add_argument('-tg', '--InTxtGrid', help="Textgrid to merge the output one to", type=str)

    return parser.parse_args()

    #Handle overlap
def filterOverlap(dfIN):
    #Sort datafram
    #print(type(dfIN))
    dfIN_sorted = dfIN.sort_values('kws_start_time').reset_index()
    selected = []
    indexs = [0]
    for i in range(1,len(dfIN_sorted)):
        if dfIN_sorted.iloc[i].kws_start_time < dfIN_sorted.iloc[i-1].kws_end_time:
            indexs.append(i)
        else:
            selected.append(dfIN_sorted.iloc[indexs].sort_values('score').iloc[0])
            indexs = [i]
    selected.append(dfIN_sorted.iloc[indexs].sort_values('score').iloc[0])
    return pd.DataFrame(selected)

def main():
    args = ArgParser()
    sKwsFile = args.kwsDir
    sDataDir = args.dataDir
    sKwsDir = args.kwsDir
    sSpeechFile = args.sSpeechFile
    sInTxtGrid = args.InTxtGrid
    sOutTxtGrid = args.outFile

    offset = 0
    segm_file = join(sDataDir,'segments')
    text_file = join(sDataDir,'text')
    kw_id_file = join(sKwsDir,'keywords.txt')
    segm_id_file = join(sKwsDir,'utter_id')
    kws_res_file = join(sKwsDir,'results')
    

    pd_segm = pd.read_csv(segm_file, delim_whitespace=True, names=['segm_id','record_id','seg_start_time','seg_end_time'])
    pd_kws_segm_id = pd.read_csv(segm_id_file, delim_whitespace=True, names=['segm_id', 'segm_kws_id'])
    pd_kws_res = pd.read_csv(kws_res_file, delim_whitespace=True  ,names=['kws_out_prompt_id', 'segm_kws_id', 'kws_start_time', 'kws_end_time', 'score'])
    pd_kws_res['kws_start_time'] = pd_kws_res['kws_start_time']*0.01
    pd_kws_res['kws_end_time'] = pd_kws_res['kws_end_time']*0.01

    #Load keywords.txt Aand text to handle spces inside 
    with open(kw_id_file) as f:
        lines = [l.split() for l in f.read().splitlines()]
    d = {'kws_prompt_id':[],'prompt':[]}
    [(d['kws_prompt_id'].append(l[0]),d['prompt'].append(' '.join(l[1:]))) for l in lines]
    pd_kws_id = pd.DataFrame.from_dict(d)

    with open(text_file) as f:
        lines = [l.split() for l in f.read().splitlines()]
    d = {'segm_id':[],'prompt':[]}
    [(d['segm_id'].append(l[0]),d['prompt'].append(' '.join(l[1:]).upper())) for l in lines]
    pd_text = pd.DataFrame.from_dict(d)

    df_merg1 = pd_segm.merge(pd_text,how='left',on='segm_id')
    df_merg2 = df_merg1.merge(pd_kws_segm_id, how='left', on='segm_id')
    df_merg3 = df_merg2.merge(pd_kws_id, how='left', on='prompt')
    df_merg4 = pd_kws_res.merge(df_merg3, how='left', on='segm_kws_id')
    result = df_merg4[df_merg4['kws_out_prompt_id']==df_merg4['kws_prompt_id']]
    result_filtered = result.groupby('kws_out_prompt_id').apply(filterOverlap)
    
    dTier = {'kws':[(result_filtered['seg_start_time'] + result_filtered['kws_start_time']).values - offset, 
    (result_filtered['seg_start_time'] + result_filtered['kws_end_time']).values + offset,
    result_filtered['prompt'].values]}

    dTier = tg.SortTxtGridDict(dTier)

    #get speech file duration
    with wave.open(sSpeechFile) as f:
        ET = f.getnframes() / f.getframerate()
    
    tg.WriteTxtGrdFromDict(sOutTxtGrid, dTier, 0.0, ET, sFilGab="")
    
    if sInTxtGrid:
        sMergedTxtGrid = splitext(sInTxtGrid)[0]+'_merged.txtgrid'
        tg.MergeTxtGrids([sOutTxtGrid,sInTxtGrid], sMergedTxtGrid, sWavFile=sSpeechFile)

if __name__ == '__main__':
    main()




