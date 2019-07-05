#!/bin/bash
set -xeuo pipefail

USAGE="wrapper.sh -j project -I sample.tsv -d sampleDir optional: -g genome -b genomeBase -s sarekpaht -n nxfpath  \n\n"

#Default values for human (for mouse use -genomeBase and -genome on command line)
GENOME='GRCh38'
GENOMEBASE='/sw/data/uppnex/ToolBox/hg38bundle'
CONTAINERPATH='/sw/data/uppnex/ToolBox/sarek'
VEPSIMG=
PROFILE='slurm'

#These paths needs to be modified for Bianca, or use -nxfpaht and -sarekpath on command line
NXFPATH='/proj/uppstore2019024/private/nextflow'
SAREKPATH='/proj/uppstore2019024/private/Sarek/Sarek'


while [[ $# -gt 0 ]]
do
  key=$1
  case $key in
    -b|--genomeBase)
    GENOMEBASE=$2
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


#Preprocessing
#From fastq files to analysis ready bam files. 
#This will generate the subdirectories "Reports" and "Preprocessing". 
#Final bam files, and a sampletsv that is used in variant calling, will be available in /Preprocessing/Realibrated
#echo "$NXFPATH/nextflow run $SAREKPATH/main.nf -profile $PROFILE --project $PROJECT --sample $SAMPLETSV --genome $GENOME --genome_base $GENOMEBASE --containerPath $CONTAINERPATH"
$NXFPATH/nextflow run $SAREKPATH/main.nf -profile $PROFILE --project $PROJECT --sample $SAMPLETSV --genome $GENOME --genome_base $GENOMEBASE --containerPath $CONTAINERPATH


#Germline variant calling
#This will generate the subdirectory /VariantCalling/HaplotypeCaller and /VariantCalling/HaplotypeCallerGVCF with vcf files and gvcf files.
#Note these are unfiltered so they need to be filtered with GATK (currently not included in Sarek) 
#echo "$NXFPATH/nextflow run $SAREKPATH/germlineVC.nf -profile $PROFILE --project $PROJECT --sample $RECAL_SAMPLE --genome $GENOME --genome_base $GENOMEBASE --containerPath $CONTAINERPATH --tools HaplotypeCaller"
$NXFPATH/nextflow run $SAREKPATH/germlineVC.nf -profile $PROFILE --project $PROJECT --sample $RECAL_SAMPLE --genome $GENOME --genome_base $GENOMEBASE --containerPath $CONTAINERPATH --tools HaplotypeCaller

#Somatic variant calling
#This will generate the subdirectories /VariantCalling/Strelka, /VariantCalling/MuTect2, /VariantCalling/Manta and /VariantCalling/Ascat with the results from respective caller.
#echo "$NXFPATH/nextflow run $SAREKPATH/somaticVC.nf -profile $PROFILE --project $PROJECT --sample $RECAL_SAMPLE --genome $GENOME --genome_base $GENOMEBASE --containerPath $CONTAINERPATH --tools mutect2,strelka,manta,ascat"
$NXFPATH/nextflow run $SAREKPATH/somaticVC.nf -profile $PROFILE --project $PROJECT --sample $RECAL_SAMPLE --genome $GENOME --genome_base $GENOMEBASE --containerPath $CONTAINERPATH --tools mutect2,strelka,manta,ascat

#Mutect2 filtering
for filename in $SAMPLEDIR/VariantCalling/MuTect2/mutect2*vcf.gz; do echo "singularity exec $CONTAINERPATH/sarek-2.3.simg gatk FilterMutectCalls -V $filename -O ${filename%.vcf.gz}.filtered.vcf.gz"; done

#Merge callers
#The script merge_callers.py assumes results files for the same tumor/normal pairs for MuTect2 and Strelka
#Parsing tumor and normal sample ids based on available results files for MuTect 
#(it is possible to have several tumor files for the same normal, for example in case of relapsed tumors)
#Output is written to current directory and therefore we move into /VariantCalling first
cd $SAMPLEDIR/VariantCalling
if test $? == 0;then
for filename in $SAMPLEDIR/VariantCalling/MuTect2/mutect2*.filtered.vcf.gz; do name=${filename##*/mutect2_} name=${name%.vcf.gz} tumor=${name%_vs_*} normal=${name##*_vs_} echo; echo; echo "$SAREKPATH/scripts/merge_callers.py --tumorid $tumor --normalid $normal --mutect2vcf $filename --strelkavcf $SAMPLEDIR/VariantCalling/Strelka/Strelka_"$tumor"_vs_"$normal"_somatic_snvs.vcf.gz --strelkaindelvcf $SAMPLEDIR/VariantCalling/Strelka/Strelka_"$tumor"_vs_"$normal"_somatic_indels.vcf.gz  --genomeindex $GENOMEBASE/GRCm38_68.fa.fai"; 
$SAREKPATH/scripts/merge_callers.py --tumorid $tumor --normalid $normal --mutect2vcf $filename --strelkavcf $SAMPLEDIR/VariantCalling/Strelka/Strelka_"$tumor"_vs_"$normal"_somatic_snvs.vcf.gz --strelkaindelvcf $SAMPLEDIR/VariantCalling/Strelka/Strelka_"$tumor"_vs_"$normal"_somatic_indels.vcf.gz  --genomeindex $GENOMEBASE/GRCm38_68.fa.fai; done
fi
cd $SAMPLEDIR

#Grep all "PASS" variants in Manta:
for filename in $SAMPLEDIR/VariantCalling/Manta/Manta_*.somaticSV.vcf.gz; do name=${filename##*/Manta_} name=${name%.somaticSV.vcf.gz} tumor=${name%_vs_*}; zcat $filename | grep "^#" > $SAMPLEDIR/VariantCalling/$tumor.SVs.vcf; zcat $filename | grep "PASS" >> $SAMPLEDIR/VariantCalling/$tumor.SVs.vcf ; done

#bgzip and tabix
module load bioinfo-tools
module load htslib/1.8
bgzip $SAMPLEDIR/VariantCalling/$tumor.SNVs.vcf
tabix $SAMPLEDIR/VariantCalling/$tumor.SNVs.vcf.gz
bgzip $SAMPLEDIR/VariantCalling/$tumor.INDELs.vcf
tabix $SAMPLEDIR/VariantCalling/$tumor.INDELs.vcf.gz
bgzip $SAMPLEDIR/VariantCalling/$tumor.SVs.vcf
tabix $SAMPLEDIR/VariantCalling/$tumor.SVs.vcf.gz

#Annotate with VEP (mouse annotation):
#singularity exec $CONTAINERPATH/vepgrch38-dev.simg vep -i $SAMPLEDIR/VariantCalling/$tumor.SNVs.vcf.gz --cache --species mouse --dir_cache /.vep --vcf -o $SAMPLEDIR/VariantCalling/$tumor.SNVs.VEP.vcf
#singularity exec $CONTAINERPATH/vepgrch38-dev.simg vep -i $SAMPLEDIR/VariantCalling/$tumor.INDELs.vcf.gz --cache --species mouse --dir_cache /.yep --vcf -o $SAMPLEDIR/VariantCalling/$tumor.INDELs.VEP.vcf
#singularity exec $CONTAINERPATH/vepgrch38-dev.simg vep -i $SAMPLEDIR/VariantCalling/$tumor.SVs.vcf.gz --cache --species mouse --dir_cache /.vep --vcf --format vcf -o $SAMPLEDIR/VariantCalling/$tumor.SVs.VEP.vcf

#Use this to annotate human vcfs files with VEP:
singularity exec $CONTAINERPATH/vepgrch38-2.3.simg vep -i $SAMPLEDIR/VariantCalling/$tumor.SNVs.vcf.gz --cache --species human --dir_cache /.vep --vcf -o $SAMPLEDIR/VariantCalling/$tumor.human.SNVs.VEP.vcf
singularity exec $CONTAINERPATH/vepgrch38-2.3.simg vep -i $SAMPLEDIR/VariantCalling/$tumor.INDELs.vcf.gz --cache --species human --dir_cache /.vep --vcf -o $SAMPLEDIR/VariantCalling/$tumor.human.INDELs.VEP.vcf
singularity exec $CONTAINERPATH/vepgrch38-2.3.simg vep -i $SAMPLEDIR/VariantCalling/$tumor.SVs.vcf.gz --cache --species human --dir_cache /.vep --vcf --format vcf -o $SAMPLEDIR/VariantCalling/$tumor.human.SVs.VEP.vcf

#MultiQC
#Will generate a html report in /Reports/MultiQC/
echo "$NXFPATH/nextflow run $SAREKPATH/runMultiQC.nf -profile $PROFILE --project $PROJECT"
$NXFPATH/nextflow run $SAREKPATH/runMultiQC.nf -profile $PROFILE --project $PROJECT
	
