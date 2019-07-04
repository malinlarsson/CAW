#!/bin/bash
set -xeuo pipefail

USAGE="wrapper.sh -j project -I sample.tsv -d sampleDir optional: -g genome -b genomeBase \n\n"

#Default values for human (for mouse use -genomeBase and -genome on command line)
GENOME='GRCh38'
GENOMEBASE='/sw/data/uppnex/ToolBox/hg38bundle'
CONTAINERPATH='/sw/data/uppnex/ToolBox/sarek'
VEPSIMG=
PROFILE='slurm'

#These paths needs to be modified for Bianca:
NXFPATH='/proj/uppstore2019024/private/nextflow/'
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
    -d|--sampleDir)
    SAMPLEDIR=$2
    shift # past argument
    shift # past value
    ;;
    -j|--project)
    PROJECT=$2
    shift # past argument
    shift # past value
    ;;
  esac
done

RECAL_SAMPLE=$SAMPLEDIR'/Preprocessing/Recalibrated/recalibrated.tsv'
echo "Recal tsv: $RECAL_SAMPLE"





#Preprocessing
#From fastq files to analysis ready bam files. 
#This will generate the subdirectories "Reports" and "Preprocessing". 
#Final bam files, and a sampletsv that is used in variant calling, will be available in /Preprocessing/Realibrated
echo "$NXFPATH/nextflow run $SAREKPATH/main.nf -profile $PROFILE --project $PROJECT --sample $SAMPLETSV --genome $GENOME --genome_base $GENOMEBASE --containerPath $CONTAINERPATH"

#Germline variant calling
#This will generate the subdirectory /VariantCalling/HaplotypeCaller and /VariantCalling/HaplotypeCallerGVCF with vcf files and gvcf files.
#Note these are unfiltered so they need to be filtered with GATK (currently not included in Sarek) 
echo "$NXFPATH/nextflow run $SAREKPATH/germlineVC.nf -profile $PROFILE --project $PROJECT --sample $RECAL_SAMPLE --genome $GENOME --genome_base $GENOMEBASE --containerPath $CONTAINERPATH --tools HaplotypeCaller"

#Somatic variant calling
#This will generate the subdirectories /VariantCalling/Strelka, /VariantCalling/MuTect2, /VariantCalling/Manta and /VariantCalling/Ascat with the results from respective caller.
echo "$NXFPATH/nextflow run $SAREKPATH/somaticVC.nf -profile $PROFILE --project $PROJECT --sample $RECAL_SAMPLE --genome $GENOME --genome_base $GENOMEBASE --containerPath $CONTAINERPATH --tools mutect2,strelka,manta,ascat"

