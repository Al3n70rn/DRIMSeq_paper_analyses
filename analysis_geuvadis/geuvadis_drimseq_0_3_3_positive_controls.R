##############################################################################
# <<geuvadis_drimseq_0_3_3_comparison_run.R>>

# BioC 3.2
# Created 29 Feb 2016 

# Merge results and recalculate adjusted p-values for drimseq and sqtlseeker
# Create a table with results for validated sQTLs
# Create a summary table with number of detected validated sQTLs
# Plot proportions for validated sQTLs

##############################################################################

Sys.time()

##############################################################################

library(DRIMSeq)
library(ggplot2)
library(iCOBRA)
library(plyr)
library(Gviz)
library(GenomicFeatures)
library(tools)
library(rtracklayer)
library(GenomicRanges)
library(limma)

##############################################################################
# Arguments for testing the code
##############################################################################

# rwd='/home/Shared/data/seq/geuvadis'
# population='CEU'
# valid_path='data/validation/glimmps/glimmps_valid_pcr.txt'
# plot_proportions=TRUE

##############################################################################
# Read in the arguments
##############################################################################

## Read input arguments
args <- (commandArgs(trailingOnly = TRUE))
for (i in 1:length(args)) {
  eval(parse(text = args[[i]]))
}

print(args)

print(rwd)
print(population)


##############################################################################

setwd(rwd)

method_out <- "drimseq_0_3_3_analysis/"

comparison_out <- paste0("drimseq_0_3_3_positive_controls/", basename(file_path_sans_ext(valid_path)), "/")

dir.create(comparison_out, recursive = TRUE, showWarnings = FALSE)

out_dir <- comparison_out

dir.create(paste0(out_dir, "figures/"), recursive = TRUE, showWarnings = FALSE)


##############################################################################
### colors
##############################################################################

load(paste0(rwd, "/", "drimseq_0_3_3_comparison/", "colors.Rdata"))
colors
colors_df

colors_df$methods <- as.character(colors_df$methods)

##############################################################################
# validated genes
##############################################################################


valid <- read.table(valid_path, header = TRUE, sep = "\t", as.is = TRUE) 




##############################################################################
# merge results 
##############################################################################


results <- list()

#####################################
### sqtlseeker results
#####################################


res_tmp <- read.table(paste0("sqtlseeker_2_1_analysis/results/", population, "_results_all.txt"), header = TRUE, as.is = TRUE)
head(res_tmp)

colnames(res_tmp) <- c("gene_id", "snp_id", "F", "nb.groups", "md", "tr.first", "tr.second", "nb.perms", "pvalue")
res_tmp <- unique(res_tmp)


res_tmp$gene_snp <- paste0(res_tmp$gene_id, ":", res_tmp$snp_id)

res_tmp$adj_pvalue <- qvalue::qvalue(res_tmp$pvalue)$qvalues



results[["sqtlseeker"]] <- res_tmp



# dim(results[["sqtlseeker"]])
# 
# table(duplicated(results[["sqtlseeker"]][, "gene_snp"]))



#####################################
### DRIMSeq results + adjust p-value
#####################################


res_list <- lapply(1:22, function(chr){
  # chr = 1
  
  res <- read.table(paste0(method_out, population, "_chr",chr, "_results.txt"), header = TRUE, sep = "\t", as.is = TRUE)
  
  return(res)
  
})


res <- rbind.fill(res_list)

res <- res[!is.na(res$pvalue), ]

res$gene_block <- paste0(res$gene_id, ":", res$block_id)
res$gene_snp <- paste0(res$gene_id, ":", res$snp_id)


res_uniq <- res[!duplicated(res$gene_block), ]
res_uniq$adj_pvalue <- p.adjust(res_uniq$pvalue, method = "BH")
mm <- match(res$gene_block, res_uniq$gene_block)
res$adj_pvalue <- res_uniq$adj_pvalue[mm]


results[["drimseq"]] <- res



#######################################################
# merge results for iCOBRA - results_padj
#######################################################


results_padj <- list()

padj_tmp <- results[["sqtlseeker"]][, c("gene_snp", "adj_pvalue")]
colnames(padj_tmp) <- c("gene_snp", "sqtlseeker")
results_padj[["sqtlseeker"]] <- padj_tmp


padj_tmp <- results[["drimseq"]][, c("gene_snp", "adj_pvalue")]
colnames(padj_tmp) <- c("gene_snp", "drimseq")
results_padj[["drimseq"]] <- padj_tmp


results_padj <- Reduce(function(...) merge(..., by = "gene_snp", all=TRUE, sort = FALSE), results_padj)
rownames(results_padj) <- results_padj$gene_snp


results_padj <- results_padj[, colnames(results_padj) %in% colors_df$methods, drop = FALSE]

keep_methods <- colors_df$methods %in% colnames(results_padj)

colors <- colors[keep_methods]
colors_df <- colors_df[keep_methods, , drop = FALSE]


############################################################################
# Check which validated sqtls are significant 
############################################################################

all(valid$gene_snp %in% rownames(results_padj))

valid_gene_snp <- valid$gene_snp[valid$gene_snp %in% rownames(results_padj)]

results_padj_valid <- data.frame(matrix(NA, nrow = nrow(valid), ncol = ncol(results_padj)))
rownames(results_padj_valid) <- valid$gene_snp
colnames(results_padj_valid) <- colnames(results_padj)

results_padj_valid[valid_gene_snp, ] <- results_padj[valid_gene_snp, ]

head(results_padj_valid)


out <- data.frame(valid[, c("gene_id", "gene_name", "snp_id", "snp_name", "gene_snp")], results_padj_valid, stringsAsFactors = FALSE)

write.table(out, file = paste0(comparison_out, "validation.txt"), quote = FALSE, sep = "\t", row.names = FALSE, col.names = TRUE)




number_sign_valid <- matrix(colSums(results_padj_valid < 0.05, na.rm = TRUE), nrow = 1)
colnames(number_sign_valid) <- colnames(results_padj_valid)


out_summary <- data.frame(number_sign_valid, all = nrow(results_padj_valid))
out_summary

write.table(out_summary, file = paste0(comparison_out, "validation_summary.txt"), quote = FALSE, sep = "\t", row.names = FALSE, col.names = TRUE)



##########################################################################
### Proportion plots of validated sQTLs
##########################################################################

if(plot_proportions){
  
  
  ### drimseq plots
  
  table(valid$gene_snp %in% results[["drimseq"]]$gene_snp)
  
  results[["drimseq"]][which(results[["drimseq"]]$gene_snp %in% valid$gene_snp), ]
  
  
  for(i in which(valid$gene_snp %in% results[["drimseq"]]$gene_snp)){
    # i = 1
    
    load(paste0(method_out, population, "_chr",valid$chr[i], "_d.Rdata"))
    
    plot_main <- paste0(valid$gene_name[i], " - ", valid$snp_name[i], "\n FDR = ", sprintf( "%.02e",results[["drimseq"]][which(results[["drimseq"]]$gene_snp == valid$gene_snp[i]), "adj_pvalue"]))
    
    
    ggp <- plotFit(d, gene_id = valid$gene_id[i], snp_id = valid$snp_id[i], plot_type = "boxplot1", order = FALSE)
    
    ggp <- ggp + ggtitle(plot_main)
    
    pdf(paste0(out_dir, "figures/drimseq_boxplot1_", i, "_", valid$gene_name[i], "_", valid$snp_name[i], ".pdf"), width = 12, height = 7)
    print(ggp)
    dev.off()
    
    
    ggp <- plotFit(d, gene_id = valid$gene_id[i], snp_id = valid$snp_id[i], plot_type = "boxplot1", order = TRUE)
    
    ggp <- ggp + ggtitle(plot_main)
    
    pdf(paste0(out_dir, "figures/drimseq_boxplot1order_", i, "_", valid$gene_name[i], "_", valid$snp_name[i], ".pdf"), width = 12, height = 7)
    print(ggp)
    dev.off()
    
    
  }
  
  
  
  ### sqtlseeker plots
  
  table(valid$gene_snp %in% results[["sqtlseeker"]]$gene_snp)
  
  results[["sqtlseeker"]][which(results[["sqtlseeker"]]$gene_snp %in% valid$gene_snp), ]
  
  
  sqtlseeker_counts <- read.table("sqtlseeker_2_1_analysis/data/trExpCount_CEU_sqtlseeker_ratios.tsv", header = TRUE, sep = "\t", as.is = TRUE)
  
  
  for(i in which(valid$gene_snp %in% results[["sqtlseeker"]]$gene_snp)){
    # i = 1
    
    load(paste0(method_out, population, "_chr",valid$chr[i], "_d.Rdata"))
    
    sqtlseeker_counts_tmp <- sqtlseeker_counts[sqtlseeker_counts$geneId == valid$gene_id[i], , drop = FALSE]
    
    counts <- as.matrix(sqtlseeker_counts_tmp[, -c(1, 2), drop = FALSE])
    rownames(counts) <- sqtlseeker_counts_tmp[, "trId"]
    
    block <- d@blocks[[valid$gene_id[i]]]
    block_id <- block[which(block[, "snp_id"] == valid$snp_id[i]), "block_id"]
    
    group <- factor(d@genotypes[[valid$gene_id[i]]][block_id, colnames(counts)])
    
    plot_main <- paste0(valid$gene_name[i], " - ", valid$snp_name[i], "\n FDR = ", sprintf( "%.02e",results[["sqtlseeker"]][which(results[["sqtlseeker"]]$gene_snp == valid$gene_snp[i]), "adj_pvalue"]))
    
    
    ggp <- DRIMSeq:::dm_plotProportions(counts, group, pi_full = NULL, pi_null = NULL, main = plot_main, plot_type = "boxplot1", order = FALSE)
    
    
    pdf(paste0(out_dir, "figures/sqtlseeker_boxplot1_", i, "_", valid$gene_name[i], "_", valid$snp_name[i], ".pdf"), width = 12, height = 7)
    print(ggp)
    dev.off()
    
    
  }
  
  
  
  
}



















