#!/bin/bash
set -xeuo pipefail


GENOME='GRCh38'
#for human and GRCh38 we can use the central genome base on Uppmax (for mouse use --genomeBase on command line)
#GENOMEBASE='/sw/data/uppnex/ToolBox/hg38bundle'
CONTAINERPATH='/sw/data/uppnex/ToolBox/sarek'
PROFILE='slurm'
TOOLS='mutect2,strelka,manta,ascat'
NXFPATH='/proj/uppstore2017171/staff/malin/nextflow'
SAREKPATH='/proj/uppstore2019024/private/Sarek/Sarek'

while [[ $# -gt 0 ]]
do
  key=$1
  case $key in
    -g|--genome)
    GENOME=$2
    shift # past argument
    shift # past value
    ;;
    -b|--genomeBase)
    GENOMEBASE=$2
    shift # past argument
    shift # past value
    ;;
    -i|--sample)
    SAMPLETSV=$2
    shift # past argument
    shift # past value
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

RECAL_TSV=$PWD

echo "Recal tsv: $RECAL_TSV"



#Preprocess the bam files
echo "$NXFPATH/nextflow run $SAREKPATH/main.nf -profile $PROFILE --project $PROJECT --sample $SAMPLETSV --genome $GENOME --genome_base $GENOMEBASE --containerPath $CONTAINERPATH"

#Run Haplotype caller for germline variants
echo "$NXFPATH/nextflow run $SAREKPATH/germlineVC.nf -profile $PROFILE --project $PROJECT --sample $RECAL_TSV --genome $GENOME --genome_base $GENOMEBASE --containerPath $CONTAINERPATH --tools HaplotypeCaller"


#run multiQC:
echo "$NXFPATH/nextflow run $SAREKPATH/runMultiQC.nf -profile $PROFILE --project $PROJECT"
#$NXFPATH/nextflow run $SAREKPATH/runMultiQC.nf -profile $PROFILE --project $PROJECT
	
