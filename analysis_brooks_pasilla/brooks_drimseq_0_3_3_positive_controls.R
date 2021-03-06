######################################################
## ----- brooks_drimseq_0_3_3_positive_controls
## <<brooks_drimseq_0_3_3_positive_controls.R>>

# BioC 3.2
# Created 15 Jan 2015 

##############################################################################

Sys.time()

##############################################################################

library(plyr)
library(ggplot2)
library(rtracklayer)
library(DRIMSeq)
library(iCOBRA)

##############################################################################
# Test arguments
##############################################################################

# rwd='/home/Shared/data/seq/brooks_pasilla'
# count_method=c('htseq','kallisto','kallistofiltered5','htseqprefiltered5')[2]
# model=c('model_full','model_full_glm','model_full_paired')[1]
# valid_path='5_validation/brooks_validated_genes.txt'
# method_out='drimseq_0_3_3'
# comparison_out='drimseq_0_3_3_positive_controls'

##############################################################################
# Read in the arguments
##############################################################################

## Read input arguments
args <- (commandArgs(trailingOnly = TRUE))
for (i in 1:length(args)) {
  eval(parse(text = args[[i]]))
}


print(rwd)
print(model)
print(count_method)

##############################################################################

setwd(rwd)

comparison_out <- paste0(comparison_out, "/")

dir.create(comparison_out, showWarnings = FALSE, recursive = TRUE)

dir.create(paste0(comparison_out, "figures/"), showWarnings = FALSE, recursive = TRUE)


##############################################################################
# metadata
##############################################################################


metadata <- read.table("3_metadata/metadata.xls", stringsAsFactors=F, sep="\t", header=T) 

metadata

##############################################################################
# colors
##############################################################################


load(paste0(rwd, "/", "drimseq_0_3_3_comparison", "/colors.Rdata"))
colors
colors_df

colors_df$methods <- as.character(colors_df$methods)


##############################################################################
# validated genes
##############################################################################


valid <- read.table(valid_path, header = TRUE, sep = "\t", as.is = TRUE) 



#######################################################
# merge results 
#######################################################


results_padj <- list()

####################### results from DEXSeq

rt <- read.table(paste0("4_results/dexseq_1_10_8/", model,"/", count_method, "/dexseq_gene_results.txt"), header = TRUE, as.is = TRUE)
head(rt)

colnames(rt) <- c("gene_id", "dexseq")
head(rt)

results_padj[["dexseq"]] <- rt


####################### results from DRIMSeq

res_path <- paste0(method_out, "/",  model, "/", count_method, "/")
files <- list.files(path = res_path, pattern = "_results.txt" )
files

if(length(files) > 0){
  for(i in 1:length(files)){
    # i = 1
    method_name <- gsub(pattern = "_results.txt", replacement = "", x = files[i])
    
    rt <- read.table(paste0(res_path, files[i]), header = TRUE, as.is = TRUE)
    head(rt)
    
    rt <- rt[,c("gene_id","adj_pvalue")]
    colnames(rt) <- c("gene_id", method_name)
    
    results_padj[[method_name]] <- rt 
    
  }
}


####################### Merge results

results_padj <- Reduce(function(...) merge(..., by = "gene_id", all=TRUE, sort = FALSE), results_padj)
rownames(results_padj) <- results_padj$gene_id


results_padj <- results_padj[, !grepl("gene_id", colnames(results_padj)), drop = FALSE]



############################################################################
# Check if all validated genes are significant 
############################################################################

all(valid$gene_id %in% rownames(results_padj))



results_padj_valid <- results_padj[valid$gene_id, , drop = FALSE]

rownames(results_padj_valid) <- valid$gene_id

results_padj_valid

out <-  data.frame(valid, model = model , count_method = count_method, results_padj_valid, stringsAsFactors = FALSE)

write.table(out, file = paste0(comparison_out, model, "_", count_method, "_validation.txt"), quote = FALSE, sep = "\t", row.names = FALSE, col.names = TRUE)




number_sign_valid <- matrix(colSums(results_padj_valid[-which(valid$brooks_gene_id == "Ant2"), , drop = FALSE] < 0.05, na.rm = TRUE), nrow = 1)
colnames(number_sign_valid) <- colnames(results_padj_valid)


out_summary <- data.frame(model = model , count_method = count_method, number_sign_valid)
out_summary

write.table(out_summary, file = paste0(comparison_out, model, "_", count_method, "_validation_summary.txt"), quote = FALSE, sep = "\t", row.names = FALSE, col.names = TRUE)


############################################################################
# DRIMSeq plots of proportions - counts from DRIMSeq, may be with filtering
############################################################################


res_path <- paste0(method_out, "/",  model, "/", count_method, "/")
files <- list.files(path = res_path, pattern = "_d.Rdata" )
files


if(length(files) > 0){
  for(i in 1:length(files)){
    # i = 1
    method_name <- gsub(pattern = "_d.Rdata", replacement = "", x = files[i])
    
    load(paste0(res_path, files[i]))
    
    out_dir <- paste0(comparison_out, model, "_", count_method)
    dir.create(out_dir, showWarnings = FALSE)
    
    for(j in 1:nrow(valid)){
      # j = 1
      
      if(!valid$gene_id[j] %in% names(d@counts))
        next
      
      ggp <- plotFit(d, gene_id = valid$gene_id[j], order = FALSE)
      
      pdf(paste0(out_dir, "/", method_name, "_", valid$brooks_gene_id[j], ".pdf"), 10, 5)
      print(ggp)
      dev.off()
      
    }
    
  }
}


############################################################################
# DRIMSeq plots of proportions - based on raw counts
############################################################################



res_path <- paste0(method_out, "/",  model, "/", count_method, "/")
files <- paste0(res_path, "d.Rdata")

files

if(file.exists(files)){
  
  out_dir <- paste0(comparison_out, model, "_", count_method)
  dir.create(out_dir, showWarnings = FALSE)
  
  load(files)
  
  for(j in 1:nrow(valid)){
    # j = 1
    
    if(!valid$gene_id[j] %in% names(d@counts))
      next
    
    counts <- d@counts[[valid$gene_id[j]]]
    group <- d@samples$group
    
    ggp <- DRIMSeq:::dm_plotProportions(counts, group, pi_full = NULL, pi_null = NULL, main = NULL, plot_type = "barplot", order = FALSE) 
    
    ggp <- ggp +
      theme(axis.text.x = element_text(angle = 90, vjust = 0.5), axis.text=element_text(size=16), axis.title=element_text(size=14, face="bold"), plot.title = element_text(size=14)) 
    
    
    pdf(paste0(out_dir, "/", "raw_proportions","_", valid$brooks_gene_id[j], ".pdf"), 10, 5)
    print(ggp)
    dev.off()
    
  }
  
}








sessionInfo()























