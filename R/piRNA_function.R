#' run the piRNA function
#' processes forward and reverse reads according to piRNA algorithm
#' outputs plots, heat results, and zdf
#' @param chrom_name a string
#' @param reg_start a whole number
#' @param reg_stop a whole number
#' @param input_file a string
#' @param logfile a string
#' @param dir a string
#' @param pal a string
#' @param plot_output a string, 'T' or 'F', default = 'T
#' @return plots, heat results, and zdf
#' @export
#' 
piRNA_function <- function(chrom_name, reg_start, reg_stop, input_file, logfile, dir, pal, plot_output){
  
  bam_obj <- OpenBamFile(input_file, logfile)
  bam_header <- Rsamtools::scanBamHeader(bam_obj)
  
  bam_header <- NULL
  
  chromP <- getChrPlus(bam_obj, chrom_name, reg_start, reg_stop)
  chromM <- getChrMinus(bam_obj, chrom_name, reg_start, reg_stop)
  
  forward_dt <- data.table::setDT(makeBamDF(chromP)) %>%
    subset(width <= 32 & width >= 15) %>% 
    dplyr::mutate(start = pos, end = pos + width - 1) %>% dplyr::distinct() %>%
    dplyr::select(-c(pos))
  
  reverse_dt <- data.table::setDT(makeBamDF(chromM)) %>%
    subset(width <= 32 & width >= 15) %>%
    dplyr::mutate(start = pos, end = pos + width - 1) %>% dplyr::distinct() %>%
    dplyr::select(-c(pos))
  
  read_dist <- get_read_dist(chromM, chromP)
  
  ##calculate read density by size
  data <- read_densityBySize(bam_obj, chrom_name, reg_start, reg_stop, input_file, dir)
  
  chromP <- NULL
  chromM <- NULL
  
  
  cat(file = paste0(dir, logfile), paste0("chrom_name: ", chrom_name, " reg_start: ", reg_start, " reg_stop: ", reg_stop, "\n"), append = TRUE)
  cat(file = paste0(dir, logfile), paste0("Filtering forward and reverse reads by length", "\n"), append = TRUE)
  
  
  #### if no forward reads are appropriate length delete df and print error message
  if (nrow(forward_dt) == 0 || nrow(reverse_dt) == 0){    
    cat(file = paste0(dir, logfile), paste0("Zero forward reads of correct length detected", "\n"), append = TRUE)
    z_df <- NA
    heat_results <- NA
  }
  
  z_res <- make_count_table(forward_dt$start, forward_dt$end, forward_dt$width, 
                            reverse_dt$start, reverse_dt$end, reverse_dt$width)
  
  
  heat_results <- get_pi_overlaps(forward_dt$start, forward_dt$end, forward_dt$width, 
                                  reverse_dt$end, reverse_dt$start, reverse_dt$width)
  
  
  row.names(heat_results) <- c('15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31','32')
  colnames(heat_results) <- c('15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31','32')
  
  prefix <- paste0(chrom_name, "_", reg_start, "_", reg_stop)
  output <- t(c(prefix, as.vector(heat_results)))
  
  suppressWarnings(
    if(!file.exists("piRNA_heatmap.txt")){
      write.table(output, file = paste0(dir, "piRNA_heatmap.txt"), sep = "\t", quote = FALSE, append = T, col.names = F, na = "NA", row.names = F)
    } else {
      write.table(output, file = paste0(dir, "piRNA_heatmap.txt"), quote = FALSE, sep = "\t", col.names = F, append = TRUE, na = "NA", row.names = F)
    }
  )
  
  z_df <- data.frame("Overlap" = z_res[ ,1], "Z_score" = calc_zscore(z_res$count))
  #write.table(z_df, file = paste0(chrom_name, "_", reg_start, "-", reg_stop, "_zscore.txt"), row.names = FALSE, quote = FALSE)
  plot_pi_zresults <- function(z_df){
    p <- ggplot2::ggplot(z_df, ggplot2::aes(x = Overlap, y = Z_score)) +
      ggplot2::geom_line(color= "black", linewidth = 1.5) +
      ggplot2::theme(axis.title.x = ggplot2::element_text(size = 13, angle = 45))+
      ggplot2::theme(axis.title.y = ggplot2::element_text(size = 13))+
      ggplot2::scale_x_continuous("Overlap", breaks = seq(0,32,5), labels = seq(0,32,5)) +
      ggplot2::theme_classic()
    return(p)
  }
  
  if(sum(heat_results != 0) && plot_output == 'T'){
    z <- plot_pi_zresults(z_df)
    dist_plot <- plot_sizes(read_dist)
    heat_plot <- plot_si_heat(heat_results, chrom_name, reg_start, reg_stop, dir, pal = pal)
    
    density_plot <- plot_density(data, reg_start, reg_stop)
    
    
    top <- cowplot::plot_grid(density_plot, ggplotify::as.grob(heat_plot), ncol = 2, rel_widths = c(1, 1), align = "vh")
    bottom <- cowplot::plot_grid(dist_plot, NULL, z, rel_widths = c(1,0.1,1), nrow = 1, ncol = 3, align = "vh", axis = "lrtb")
    
    
    all_plot <- cowplot::plot_grid(top, NULL, bottom, ncol = 1, rel_widths = c(1.5, 0.3, 0.5), rel_heights = c(1.5,0.2,1))
    pdf(file = paste0(dir, chrom_name,"_", reg_start,"-", reg_stop, "_pi-zscore.pdf"), height = 5, width = 7)
    print(all_plot)
    dev.off()  
  } else {
    print("sum_results == 0")
  }
  
  return(list(heat_results, z_df))
}

