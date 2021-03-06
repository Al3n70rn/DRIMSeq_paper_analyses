######################################################
## <<sim5_drimseq_auto_moderation.R>>

# BioC 3.2
# Created 17 Apr 2016

##############################################################################
Sys.time()
##############################################################################

library(BiocParallel)
library(DRIMSeq)
library(limma)
library(ggplot2)

##############################################################################
# Test arguments
##############################################################################

# rwd='/home/gosia/multinomial_project/simulations_sim5'
# simulation='drosophila_node_nonull'
# workers=10
# count_method='kallisto'
# filter_method='filter0'
# method_out='drimseq_0_3_3'
# dmDS_auto_moderation_diagnostics_function_path='/home/gosia/R/drimseq_paper/help_functions/dmDS_auto_moderation_diagnostics.R'

##############################################################################
# Read in the arguments
##############################################################################

args <- (commandArgs(trailingOnly = TRUE))
for (i in 1:length(args)) {
  eval(parse(text = args[[i]]))
}

print(args)

print(rwd)
print(simulation)
print(workers)
print(count_method)
print(filter_method)
print(method_out)

##############################################################################

setwd(paste0(rwd, "/", simulation))

if(workers > 1){
  BPPARAM <- MulticoreParam(workers = workers)
}else{
  BPPARAM <- SerialParam()
}

out_dir <- paste0(method_out, "/", count_method, "/", filter_method, "/")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

out_dir_tmp <- paste0(out_dir, "auto_moderation/")
dir.create(out_dir_tmp, recursive = TRUE)


##########################################################################
# Load DRIMSeq data
##########################################################################

### Load object d
load(paste0(out_dir, "drimseq_genewise_grid_none_d.Rdata"))


common_disp <- as.numeric(read.table(paste0(out_dir, "common_dispersion.txt")))
common_disp


###########################################################################
### Automatic moderation
###########################################################################

source(dmDS_auto_moderation_diagnostics_function_path)

x <- d

dmDS_auto_moderation_diagnostics(x = x, common_disp = common_disp, out_dir_tmp = out_dir_tmp, BPPARAM = BPPARAM)





















