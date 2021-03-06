##############################################################################
## ----- filtering_sim_plots_run
## <<filtering_sim_plots_run.R>>

# BioC 3.2
# Created 1 Dec 2015 
# Modified 18 Dec 2015

##############################################################################

Sys.time()

##############################################################################

library(ggplot2)
library(reshape2)
library(tools)
library(limma)
library(plyr)
library(DRIMSeq)

##############################################################################
# Arguments for testing the code
##############################################################################

# rwd='/home/gosia/multinomial_project/simulations_dm/drimseq'
# sim_name=''
# n=c(3,6)
# nm=c(10000,100000)
# nd=0
# prop='prop_q20_kim_kallisto_fcutoff'
# disp='disp_common_kim_kallisto'
# out_suffix='filtering'
# pdf_width=7 
# pdf_height=7
# strip_text_size=16
# text_size=16


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
print(sim_name)
print(n)
print(nm)
print(nd)
print(prop)
print(disp)
print(out_suffix)

##############################################################################

setwd(rwd)

out_dir_res <- "filtering/run/"
out_dir_plots <- "filtering/"




##############################################################################
### Merge all results into one data frame
##############################################################################


res_list <- list()
mse_list <- list()
fp_list <- list()

ix <- 1

for(ix_n in 1:length(n)){
  
  for(ix_nm in 1:length(nm)){
    
    for(ix_prop in 1:length(prop)){
      
      for(ix_disp in 1:length(disp)){
        # ix_n=1; ix_nm=2; ix_prop=1; ix_disp=1
        
        out_name <- paste0(sim_name, "n", n[ix_n], "_nm", nm[ix_nm], "_nd", nd, "_", prop[ix_prop], "_", disp[ix_disp], "_")
        out_name

        pattern <- gsub("\\+", "\\\\+", paste0(out_name, "est_", out_suffix))
        pattern
        
        files <- list.files(path = out_dir_res, pattern = pattern)
        files
        
        if(length(files) > 0){
          
          res_tmp_list <- list()
          mse_tmp_list <- list()
          
          for(i in 1:length(files)){
            # i = 1
            rr <- read.table(paste0(out_dir_res, files[i]), header = TRUE, sep = "\t", as.is = TRUE)
            head(rr)
            
            rr$run <- i
            res_tmp_list[[i]] <- rr
            
            # calculate mse
            rr$error_abs <- abs(rr$est - rr$true)
            rr$error <- rr$est - rr$true
            rr$max_features <- factor(rr$max_features)
            
            out_mean <- aggregate(. ~ max_features, rr[, c("max_features", "error_abs")], mean)
            colnames(out_mean) <- c( "max_features", "mean_error_abs")
            
            out_median <- aggregate(. ~ max_features, rr[, c("max_features", "error_abs")], median)
            colnames(out_median) <- c("max_features", "median_error_abs")
            
            out_median_raw <- aggregate(. ~ max_features, rr[, c("max_features", "error")], median)
            colnames(out_median_raw) <- c("max_features", "median_error")
            
            out <- merge(out_mean, out_median, by = c("max_features"), sort = FALSE)
            out <- merge(out, out_median_raw, by = c("max_features"), sort = FALSE)
            
            
            mse_tmp_list[[i]] <- out
            
          }
          
          res_tmp <- rbind.fill(res_tmp_list)
          res_tmp$n <- n[ix_n]
          res_tmp$nm <- nm[ix_nm]
          res_tmp$prop <- prop[ix_prop]
          res_tmp$disp <- disp[ix_disp]
          res_list[[ix]] <- res_tmp
          
          mse_tmp <- rbind.fill(mse_tmp_list)
          mse_tmp$n <- n[ix_n]
          mse_tmp$nm <- nm[ix_nm]
          mse_tmp$prop <- prop[ix_prop]
          mse_tmp$disp <- disp[ix_disp]
          mse_list[[ix]] <- mse_tmp
          
        }
        
#         files <- list.files(out_dir_res, pattern = paste0(out_name, "fp_", out_suffix))
#         files
        
        pattern <- gsub("\\+", "\\\\+", paste0(out_name, "fp_", out_suffix))
        pattern
        
        files <- list.files(path = out_dir_res, pattern = pattern)
        files
        
        
        if(length(files) > 0){
          
          fp_tmp_list <- list()
          
          for(i in 1:length(files)){
            # i = 1
            rr <- read.table(paste0(out_dir_res, files[i]), header = TRUE, sep = "\t", as.is = TRUE)
            
            rr$disp_estimator <- "disp_est"
            fp_tmp_list[[paste0("disp_est", i)]] <- rr
            
          }
          
#           files <- list.files(out_dir_res, pattern = paste0(out_name, "fptruedisp_", out_suffix))
#           files
          
          pattern <- gsub("\\+", "\\\\+", paste0(out_name, "fptruedisp_", out_suffix))
          pattern
          
          files <- list.files(path = out_dir_res, pattern = pattern)
          files
          
          if(length(files) > 0){
            
            for(i in 1:length(files)){
              # i = 1
              rr <- read.table(paste0(out_dir_res, files[i]), header = TRUE, sep = "\t", as.is = TRUE)
              
              rr$disp_estimator <- "disp_true"
              fp_tmp_list[[paste0("disp_true", i)]] <- rr
              
            }
          }
          
          fp_tmp <- rbind.fill(fp_tmp_list)
          fp_tmp$n <- n[ix_n]
          fp_tmp$nm <- nm[ix_nm]
          fp_tmp$prop <- prop[ix_prop]
          fp_tmp$disp <- disp[ix_disp]
          fp_list[[ix]] <- fp_tmp
          
        }
        
        
        ix <- ix + 1
      }
    }
  }
}

res <- rbind.fill(res_list)
mse <- rbind.fill(mse_list)
fp <- rbind.fill(fp_list)


##############################################################################
### Panel plots
##############################################################################


gg_color_hue <- function(n) {
  hues = seq(15, 375, length=n+1)
  hcl(h=hues, l=65, c=100)[1:n]
}


whisker_upper <- function(x) boxplot.stats(x)$stats[5]
whisker_lower <- function(x) boxplot.stats(x)$stats[1]



max_features_levels <- sort(unique(res$max_features), decreasing = TRUE)
max_features_levels


### Adjust the order of the variables for plotting

res$max_features <- factor(res$max_features, levels = max_features_levels)

res$prop <- factor(res$prop, levels = prop)
res$n <- factor(res$n, levels = n, labels = paste0("n=", n))
res$nm <- factor(res$nm, levels = nm, labels = paste0("m=", nm))

res$n_nm <- interaction(res$n, res$nm, lex.order = TRUE)
levels(res$n_nm)

res$all_interactions <- res$n_nm

### Absolute error

error <- res[complete.cases(res), ]
error$error <- abs(error$est - error$true)

ylim <- c(min(aggregate(. ~ all_interactions, error[, c("error", "all_interactions")], whisker_lower)[, "error"]) - 1, max(aggregate(. ~ all_interactions, error[, c("error", "all_interactions")], whisker_upper)[, "error"]) + 1)


ggp <- ggplot(data = error, aes(y = error, x = max_features)) + 
  geom_boxplot(outlier.size = 0.1, fill = gg_color_hue(1), outlier.colour = "black") +
  theme_bw() +
  ylab("Absolute error") +
  xlab("Max features") +
  coord_cartesian(ylim = ylim) +
  theme(axis.text = element_text(size = text_size), axis.text.x = element_text(size = text_size), axis.title.y = element_text(size = text_size, face = "bold"), axis.title.x = element_text(size = text_size, face = "bold"), legend.position = "bottom", legend.title = element_blank(), legend.text = element_text(size = text_size), strip.text = element_text(size = strip_text_size)) +
  facet_grid(nm ~ n)


pdf(paste0(out_dir_plots, out_suffix, "_error_absolute_boxplot.pdf"), width = pdf_width, height = pdf_height)
print(ggp)
dev.off()

png(paste0(out_dir_plots, out_suffix, "_error_absolute_boxplot.png"), width = 70*pdf_width, height = 70*pdf_height)
print(ggp)
dev.off()


ggp <- ggplot(data = error, aes(y = log10(error), x = max_features)) + 
  geom_violin(trim = TRUE, fill = gg_color_hue(1), colour = gg_color_hue(1)) +
  geom_boxplot(outlier.size = NA, alpha = 0, width = 0.5, outlier.colour = NULL) +
  theme_bw() +
  ylab("Log10 of absolute error") +
  xlab("Max features") +
  theme(axis.text = element_text(size = text_size), axis.text.x = element_text(size = text_size), axis.title.y = element_text(size = text_size, face = "bold"), axis.title.x = element_text(size = text_size, face = "bold"), legend.position = "bottom", legend.title = element_blank(), legend.text = element_text(size = text_size), strip.text = element_text(size = strip_text_size)) +
  facet_grid(nm ~ n)


pdf(paste0(out_dir_plots, out_suffix, "_error_absolute_log_violin.pdf"), width = pdf_width, height = pdf_height)
print(ggp)
dev.off()


### Estimates

true_disp <- res$true[1]

ggp <- ggplot(data = res, aes(y = log10(est), x = max_features)) + 
  geom_violin(trim = TRUE, fill = gg_color_hue(1), colour = gg_color_hue(1)) +
  geom_boxplot(outlier.size = NA, alpha = 0, width = 0.5) +
  geom_hline(yintercept = log10(true_disp), color="black", linetype = 2, size = 0.5) +
  theme_bw() +
  ylab("Log 10 of gamma_+") +
  xlab("Max features") +
  theme(axis.text = element_text(size = text_size), axis.text.x = element_text(size = text_size), axis.title.y = element_text(size = text_size, face = "bold"), axis.title.x = element_text(size = text_size, face = "bold"), legend.position = "bottom", legend.title = element_blank(), legend.text = element_text(size = text_size), strip.text = element_text(size = strip_text_size)) +
  facet_grid(nm ~ n)


pdf(paste0(out_dir_plots, out_suffix, "_est_log_violin.pdf"),width = pdf_width, height = pdf_height)
print(ggp)
dev.off()



###### Plots of MSE (or mean absolute error)

### Adjust the order of the variables for plotting

mse$max_features <- factor(mse$max_features, levels = max_features_levels)
levels(mse$max_features)

mse$prop <- factor(mse$prop, levels = prop)
mse$n <- factor(mse$n, levels = n, labels = paste0("n=", n))
mse$nm <- factor(mse$nm, levels = nm, labels = paste0("m=", nm))

mse$n_nm <- interaction(mse$n, mse$nm, lex.order = TRUE)
levels(mse$n_nm)


### plot mean 

ggp <- ggplot(data = mse, aes(y = mean_error_abs, x = max_features)) + 
  geom_boxplot(outlier.size = 1, fill = gg_color_hue(1), width = 0.5, outlier.colour = NULL) +
  theme_bw() +
  ylab("Mean absolute error") +
  xlab("Max features") +
  theme(axis.text = element_text(size = text_size), axis.text.x = element_text(size = text_size), axis.title.y = element_text(size = text_size, face = "bold"), axis.title.x = element_text(size = text_size, face = "bold"), legend.position = "bottom", legend.title = element_blank(), legend.text = element_text(size = text_size), strip.text = element_text(size = strip_text_size)) +
  facet_grid(nm ~ n)

pdf(paste0(out_dir_plots, out_suffix, "_error_mean_absolute_boxplot.pdf"), width = pdf_width, height = pdf_height)
print(ggp)
dev.off()





### plot median 

ggp <- ggplot(data = mse, aes(y = median_error_abs, x = max_features)) + 
  geom_boxplot(outlier.size = 1, fill = gg_color_hue(1), width = 0.5, outlier.colour = NULL) +
  theme_bw() +
  ylab("Median absolute error") +
  xlab("Max features") +
  theme(axis.text = element_text(size = text_size), axis.text.x = element_text(size = text_size), axis.title.y = element_text(size = text_size, face = "bold"), axis.title.x = element_text(size = text_size, face = "bold"), legend.position = "bottom", legend.title = element_blank(), legend.text = element_text(size = text_size)) +
  facet_grid(nm ~ n)

pdf(paste0(out_dir_plots, out_suffix, "_error_median_absolute_boxplot.pdf"), width = pdf_width, height = pdf_height)
print(ggp)
dev.off()


### plot median of raw error

ggp <- ggplot(data = mse, aes(y = median_error, x = max_features)) + 
  geom_boxplot(outlier.size = 1, fill = gg_color_hue(1), width = 0.5, outlier.colour = NULL) +
  geom_hline(yintercept = 0, color="black", linetype = 2, size = 0.5) +
  theme_bw() +
  ylab("Median error") +
  xlab("Max features") +
  theme(axis.text = element_text(size = text_size), axis.text.x = element_text(size = text_size), axis.title.y = element_text(size = text_size, face = "bold"), axis.title.x = element_text(size = text_size, face = "bold"), legend.position = "bottom", legend.title = element_blank(), legend.text = element_text(size = text_size), strip.text = element_text(size = strip_text_size)) +
  facet_grid(nm ~ n)

pdf(paste0(out_dir_plots, out_suffix, "_error_median_raw_boxplot.pdf"), width = pdf_width, height = pdf_height)
print(ggp)
dev.off()





### False positives


fp$max_features <- factor(fp$max_features, levels = max_features_levels)
levels(fp$max_features)

fp$prop <- factor(fp$prop, levels = prop)
fp$n <- factor(fp$n, levels = n, labels = paste0("n=", n))
fp$nm <- factor(fp$nm, levels = nm, labels = paste0("m=", nm))

fp$n_nm <- interaction(fp$n, fp$nm, lex.order = TRUE)
levels(fp$n_nm)


fp$disp_estimator <- factor(fp$disp_estimator)
fp$disp_estimator <- revalue(fp$disp_estimator, c("disp_est"="moderation_none", "disp_true"="true"))
fp$disp_estimator <- relevel(fp$disp_estimator, ref = "true")


ylim <- c(0, max(fp$fp, na.rm = TRUE) + 0.01)


ggp <- ggplot(data = fp, aes(y = fp, x = max_features, fill = disp_estimator)) + 
  geom_boxplot(outlier.size = 1) +
  geom_hline(yintercept = 0.05, color="black", linetype = 2, size = 0.3) +
  theme_bw() +
  ylab("FP rate") +
  xlab("Max features") +
  coord_cartesian(ylim = ylim) +
  theme(axis.text = element_text(size = text_size), axis.text.x = element_text(size = text_size), axis.title.y = element_text(size = text_size, face = "bold"), axis.title.x = element_text(size = text_size, face = "bold"), legend.position = "bottom", legend.title = element_blank(), legend.text = element_text(size = text_size), strip.text = element_text(size = strip_text_size)) +
  scale_fill_manual(values = c("grey", gg_color_hue(nlevels(fp$disp_estimator) - 1))) +
  facet_grid(nm ~ n)

pdf(paste0(out_dir_plots, out_suffix, "_fp_boxplot.pdf"), width = pdf_width, height = pdf_height)
print(ggp)
dev.off()




























