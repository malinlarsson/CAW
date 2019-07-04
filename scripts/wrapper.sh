#!/bin/bash
set -xeuo pipefail

ANNOTATE=false
ANNOTATEVCF=''
GENOME=GRCh38
#for human and GRCh38 we can use the central genome base on Uppmax (for mouse use --genomeBase on command line)
#GENOMEBASE='/sw/data/uppnex/ToolBox/hg38bundle'
CONTAINERPATH='/sw/data/uppnex/ToolBox/sarek'
GERMLINE=false
PROFILE=slurm
REPORTS=true
SAMPLEDIR=''
SAMPLETSV=''
SOMATIC=false
TAG='latest'
TOOLS='mutect2,strelka,manta,ascat'
VARIANTCALLING=false
CPUS=2
NXFPATH='/proj/uppstore2017171/staff/malin/nextflow'
SAREKPATH='/proj/uppstore2019024/private/Sarek/Sarek'

while [[ $# -gt 0 ]]
do
  key=$1
  case $key in
    -a|--annotate)
    ANNOTATE=true
    shift # past argument
    ;;
    -b|--genomeBase)
    GENOMEBASE=$2
    shift # past argument
    shift # past value
    ;;
    -s|--somatic)
    SOMATIC=true
    shift # past argument
    ;;
    -c|--cpus)
    CPUS=$2
    shift # past value
    ;;
    -d|--sampleDir)
    SAMPLEDIR=$2
    shift # past argument
    shift # past value
    ;;
    -e|--bed)
    TARGETBED=$2
    shift # past value
    ;;
    -f|--annotateVCF)
    ANNOTATEVCF=$2
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
    -l|--germline)
    GERMLINE=true
    shift # past argument
    ;;
    -n|--noReports)
    REPORTS=false
    shift # past argument
    ;;
    -p|--profile)
    PROFILE=$2
    shift # past argument
    shift # past value
    ;;

    -j|--project)
    PROJECT=$2
    shift # past argument
    shift # past value
    ;;
    -s|--step)
    STEP=$2
    shift # past argument
    shift # past value
    ;;
    --tag)
    TAG=$2
    shift # past argument
    shift # past value
    ;;
    -t|--tools)
    TOOLS=$2
    shift # past argument
    shift # past value
    ;;
    -v|--variantCalling)
    VARIANTCALLING=true
    shift # past argument
    ;;
    *) # unknown option
    shift # past argument
    ;;
  esac
done

function run_sarek() {
	# https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
	 
	echo "$(tput setaf 1)nextflow run $@ -profile $PROFILE --project $PROJECT --genome $GENOME --genome_base $GENOMEBASE --containerpath $CONTAINERPATH"
	$NXFPATH/nextflow run $SAREKPATH/$@ -profile $PROFILE --project $PROJECT --genome $GENOME --genome_base $GENOMEBASE --containerpath $CONTAINERPATH
	
}

if [[ $GERMLINE == true ]] && [[ $SOMATIC == true ]]
then
  echo "$(tput setaf 1)Germline and Somatic$(tput sgr0)"
  exit
fi

if [[ $GERMLINE == true ]] && [[ $ANNOTATE == true ]]
then
  echo "$(tput setaf 1)Germline and Annotate$(tput sgr0)"
  exit
fi

if [[ $SOMATIC == true ]] && [[ $SAMPLEDIR != '' ]]
then
  echo "$(tput setaf 1)Directory defined for Somatic$(tput sgr0)"
  exit
fi

if [[ $GERMLINE == true ]] && [[ $SAMPLEDIR != '' ]]
then
  echo "$(tput setaf 1)Germline with SampleDir$(tput sgr0)"
  run_sarek main.nf --step $STEP --sampleDir $SAMPLEDIR
fi

if [[ $GERMLINE == true ]] && [[ $SAMPLETSV != '' ]]
then
  echo "$(tput setaf 1)Germline with TSV$(tput sgr0)"
  run_sarek main.nf --step $STEP --sample $SAMPLETSV
fi

if [[ $GERMLINE == true ]] && [[ $SAMPLETSV == '' ]] && [[ $SAMPLEDIR == '' ]] && [[ $STEP != 'mapping' ]]
then
  echo "$(tput setaf 1)Germline continue$(tput sgr0)"
  run_sarek main.nf --step $STEP
fi

if [[ $GERMLINE == true ]] && [[ $VARIANTCALLING == true ]]
then
  echo "$(tput setaf 1)GermlineVC$(tput sgr0)"
  run_sarek germlineVC.nf --tools $TOOLS
fi

if [[ $SOMATIC == true ]] && [[ $SAMPLETSV != '' ]]
then
  echo "$(tput setaf 1)Somatic with TSV$(tput sgr0)"
  run_sarek main.nf  --sample $SAMPLETSV
fi

if [[ $SOMATIC == true ]] && [[ $VARIANTCALLING == true ]]
then
  echo "$(tput setaf 1)SomaticVC$(tput sgr0)"
  run_sarek germlineVC.nf --tools $TOOLS
  run_sarek somaticVC.nf --tools $TOOLS
fi

if [[ $ANNOTATE == true ]]
then
  echo "$(tput setaf 1)Annotate$(tput sgr0)"
  run_sarek annotate.nf --tools $TOOLS --annotateVCF $ANNOTATEVCF
fi

if [[ $REPORTS == true ]]
then
  echo "$(tput setaf 1)Reports$(tput sgr0)"
  run_sarek runMultiQC.nf
fi
