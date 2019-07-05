#!/bin/bash
set -xeuo pipefail

USAGE="wrapper.sh -j project -i sample.tsv -d sampleDir optional: -g genome -b genomeBase -s sarekpaht -n nxfpath  \n\n"

#Default values for human (for mouse use -genomeBase and -genome on command line)
GENOME='GRCh38'
GENOMEBASE='/sw/data/uppnex/ToolBox/hg38bundle'
CONTAINERPATH='/sw/data/uppnex/ToolBox/sarek'
PROFILE='slurm'

#These paths needs to be modified for Bianca, or use -nxfpaht and -sarekpath on command line
NXFPATH='/proj/uppstore2019024/private/nextflow'
SAREKPATH='/proj/uppstore2019024/private/Sarek/Sarek'


while [[ $# -gt 0 ]]
do
  key=$1
  case $key in
    -b|--genomeBase)
    GENOMEBASE=${2%/}
    shift # past argument
    shift # past value
    ;;
    -d|--sampleDir)
    SAMPLEDIR=$2
    shift # past argument
    shift # past value
    ;;
    -g|--genome)
    GENOME=$2
    shift # past argument
    shift # past value
    ;;
    -i|--sample)
    SAMPLETSV=$2
    shift # past argument
    shift # past value
    ;;
    -j|--project)
    PROJECT=$2
    shift # past argument
    shift # past value
    ;;
    -n|--nxfpath)
    NXFPATH=$2
    shift # past argument
    shift # past value
    ;;
    -s|--sarekpath)
    SAREKPATH=$2
    shift # past argument
    shift # past value
    ;;
  esac
done

RECAL_SAMPLE=$SAMPLEDIR'/Preprocessing/Recalibrated/recalibrated.tsv'
echo "Recal tsv: $RECAL_SAMPLE"

echo $GENOMEBASE

