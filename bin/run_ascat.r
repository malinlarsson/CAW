#!/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
if(length(args)<6){
    stop("No input files supplied\n\nUsage:\nRscript run_ascat.r tumor_baf tumor_logr normal_baf normal_logr tumor_sample_name baseDir\n\n")
} else{
    tumorbaf = args[1]
    tumorlogr = args[2]
    normalbaf = args[3]
    normallogr = args[4]
    tumorname = args[5]
    baseDir = args[6]

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

#First use default gamma (0.55)
ascat.output <- ascat.runAscat(ascat.bc)
#Write out CNVs in bed format
cnvs=ascat.output$segments[ascat.output$segments[,"nMajor"]!=1 | ascat.output$segments[,"nMinor"]!=1,2:6]
write.table(cnvs, file=paste(tumorname,".gamma0.55.cnvs.txt",sep=""), sep="\t", quote=F, row.names=F, col.names=T)
#Write out purity and ploidy info
if (length(ascat.output$aberrantcellfraction)>0 & length(ascat.output$ploidy)>0) {
    summary <- matrix(c(ascat.output$aberrantcellfraction, ascat.output$ploidy), ncol=2, byrow=TRUE)
    colnames(summary) <- c("AberrantCellFraction","Ploidy")
    write.table(summary, file=paste(tumorname,".gamma0.55.purityploidy.txt",sep=""), sep="\t", quote=F, row.names=F, col.names=T)
}

#Then use gamma optimised for NGS data (0.8)
ascat.output <- ascat.runAscat(ascat.bc, gamma=0.8)
#Write out CNVs in bed format
cnvs=ascat.output$segments[ascat.output$segments[,"nMajor"]!=1 | ascat.output$segments[,"nMinor"]!=1,2:6]
write.table(cnvs, file=paste(tumorname,".gamma0.8.cnvs.txt",sep=""), sep="\t", quote=F, row.names=F, col.names=T)
#Write out purity and ploidy info
if (length(ascat.output$aberrantcellfraction)>0 & length(ascat.output$ploidy)>0) {
    summary <- matrix(c(ascat.output$aberrantcellfraction, ascat.output$ploidy), ncol=2, byrow=TRUE)
    colnames(summary) <- c("AberrantCellFraction","Ploidy")
    write.table(summary, file=paste(tumorname,".gamma0.8.purityploidy.txt",sep=""), sep="\t", quote=F, row.names=F, col.names=T)
}
