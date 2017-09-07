#!/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
if(length(args)<6){
    stop("No input files supplied\n\nUsage:\nRscript run_ascat.r tumor_baf tumor_logr normal_baf normal_logr tumor_sample_name gamma_value\n\n")
} else{
    tumorbaf = args[1]
    tumorlogr = args[2]
    normalbaf = args[3]
    normallogr = args[4]
    tumorname = args[5]
    gamma_value = args[6]

}

source(paste(baseDir,"/scripts/ascat.R", sep=""))

if(!require(RColorBrewer)){
    source("http://bioconductor.org/biocLite.R")
    biocLite("RColorBrewer", suppressUpdates=TRUE, lib="$baseDir/scripts")
    library(RColorBrewer)
}
options(bitmapType='cairo')

#Load the  data
ascat.bc <- ascat.loadData(Tumor_LogR_file=tumorlogr, Tumor_BAF_file=tumorbaf, Germline_LogR_file=normallogr, Germline_BAF_file=normalbaf)

#Plot the raw data
ascat.plotRawData(ascat.bc)

#Segment the data
ascat.bc <- ascat.aspcf(ascat.bc)

#Plot the segmented data
ascat.plotSegmentedData(ascat.bc)

#Run ASCAT to fit every tumor to a model, inferring ploidy, normal cell contamination, and discrete copy numbers
#Use the gamma value sent in by user
ascat.output <- ascat.runAscat(ascat.bc, gamma=gamma_value)

#Write out segmented regions (including regions with one copy of each allele)
#write.table(ascat.output$segments, file=paste(tumorname, ".segments.txt", sep=""), sep="\t", quote=F, row.names=F)

#Write out CNVs in bed format
cnvs=ascat.output$segments[ascat.output$segments[,"nMajor"]!=1 | ascat.output$segments[,"nMinor"]!=1,2:6]
write.table(cnvs, file=paste(tumorname,".cnvs.txt",sep=""), sep="\t", quote=F, row.names=F, col.names=T)

#Write out purity and ploidy info
summary <- matrix(c(ascat.output$aberrantcellfraction, ascat.output$ploidy), ncol=2, byrow=TRUE)
colnames(summary) <- c("AberrantCellFraction","Ploidy")
write.table(summary, file=paste(tumorname,".purityploidy.txt",sep=""), sep="\t", quote=F, row.names=F, col.names=T)


