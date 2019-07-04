#!/bin/bash
set -xeuo pipefail

#Default values for human (for mouse use -genomeBase and -genome on command line)
GENOME='GRCh38'
GENOMEBASE='/sw/data/uppnex/ToolBox/hg38bundle'
CONTAINERPATH='/sw/data/uppnex/ToolBox/sarek'
SAREKSIMG=$CONTAINERPATH'/sarek-2.3.simg'
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
    -t|--tools) 
    *) # unknown option
    shift # past argument
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

#Mutect2 filtering
for filename in $SAMPLEDIR/VariantCalling/MuTect2/mutect2*vcf.gz; do echo "singularity exec $SAREKSIMG gatk FilterMutectCalls -V $filename -O ${filename%.vcf.gz}.filtered.vcf.gz"; done

#Merge callers
#The script below assumes results files for the same tumor/normal pairs for MuTect2 and Strelka
#Parsing tumor and normal sample ids based on available results files for MuTect 
#(it is possible to have several tumor files for the same normal, for example in case of relapsed tumors)
for filename in $SAMPLEDIR/VariantCalling/MuTect2/mutect2*.filtered.vcf.gz; do name=${filename##*/mutect2_} name=${name%.vcf.gz} tumor=${name%_vs_*} normal=${name##*_vs_} echo "$SAREKPATH/scripts/merge_callers.py --tumorid $tumor --normalid $normal --mutect2vcf filename --strelkavcf $SAMPLEDIR/VariantCalling/Strelka_$tumor_vs_normal_somatic_snvs.vcf.gz --strelkaindelvcf $SAMPLEDIR/VariantCalling/Strelka_$tumor_vs_normal_somatic_indels.vcf.gz  --genomeindex $GENOMEBASE/GRCm38_68.fa.fai"; done

#Grep all "PASS" variants in Manta:
for filename in $SAMPLEDIR/VariantCalling/Manta/Manta_*.somaticSV.vcf.gz; do name=${filename##*/Manta_} name=${name%.somaticSV.vcf.gz} tumor=${name%_vs_*} grep "^#" filename > $SAMPLEDIR/VariantCalling/$tumor.svs.vcf grep "PASS" filename >> $SAMPLEDIR/VariantCalling/$tumor.SVs.vcf ; done

#MultiQC
#Will generate a html report in /Reports/MultiQC/
echo "$NXFPATH/nextflow run $SAREKPATH/runMultiQC.nf -profile $PROFILE --project $PROJECT"
$NXFPATH/nextflow run $SAREKPATH/runMultiQC.nf -profile $PROFILE --project $PROJECT
	
