collectiveModes <- function(mat_diff, date_vec, df_group = NULL,
                            Contrib_as_ModeSq = F,
                            AggregateContributions = F,
                            plot_eigenportfolio_ts = F){
  
  n_ts <- ncol(mat_diff)
  col_order <- colnames(mat_diff)
  cormat <- cor(mat_diff)
  image(cormat)
  #-----------------------------
  eig_vectors <- eigen(cormat)$vectors
  lam_cor <- eigen(cormat)$values
  lamcor_max <- max(lam_cor)
  N_t <- nrow(mat_diff)
  N_c <- ncol(mat_diff)
  Q <- N_t / N_c
  s_sq <- 1 - lamcor_max / N_c
  #s_sq <- 1
  lamrand_max <- s_sq * (1 + 1 / Q + 2 / sqrt(Q))
  lamrand_min <- s_sq * (1 + 1 / Q - 2 / sqrt(Q))
  lam <- seq(lamrand_min, lamrand_max, 0.001)
  dens_rand <- Q / (2 * pi * s_sq) * sqrt((lamrand_max - lam) * (lam - lamrand_min)) / lam
  df_e <- data.frame(values = lam_cor)
  #--
  gg <- ggplot() +
    geom_density(data = df_e, aes(x = values, color = "Correlation Matrix")) +
    #geom_histogram(data = df_e, aes(x = values), alpha = 0.2) +
    geom_line(data = data.frame(x = lam, y = dens_rand), aes(x = x, y = y, color = "Random matrix")) +
    coord_cartesian(xlim = c(0, ceiling(lamcor_max))) +
    scale_colour_manual(name = "Eigenvalue density", 
                        values = c(`Correlation Matrix` = "blue", `Random matrix` = "orange"))
  
  print(gg)
  #-----------------------------
  # How many collective modes?
  ind_deviating_from_noise <- which(lam_cor > lamrand_max)
  collModes <- as.matrix(eig_vectors[, ind_deviating_from_noise])
  noiseModes <- as.matrix(eig_vectors[, -ind_deviating_from_noise])
  n_collModes <- ncol(collModes)
  #-----------------------------
  # Set sign of eigenvectors such that they
  # best conform to the input time series
  Modes <- mat_diff %*% collModes
  ts_avg <- mat_diff %*% rep(1, n_ts) * 1 / n_ts
  for(i in 1:n_collModes){
    sse <- sum((Modes[, i] - ts_avg)^2)
    sse_neg <- sum((-Modes[, i] - ts_avg)^2)
    sse_vec <- c(sse, sse_neg)
    if(which(sse_vec == min(sse_vec)) == 2){
      collModes[, i] <- -collModes[, i]
    }
  }
  #-----------------------------
  n_collModes_really <- n_collModes
  collModes_really <- collModes
  print(paste("Number of collective modes: ", n_collModes))
  if(ncol(collModes) > 6){
    collModes <- collModes[, 1:6]
    n_collModes <- 6
  }
  #-----------------------------
  # Contributions of items to each mode
  if(Contrib_as_ModeSq == T){
    Contribution <- (collModes)^2
  }else{
    Contribution <- collModes
  }
  df_contrib <- data.frame(ts_id = col_order, Contribution)
  df_contrib <- cbind(df_contrib, df_group[, c(2:ncol(df_group))])
  mode_id <- c(1:n_collModes)
  colnames(df_contrib)[2:(n_collModes + 1)] <- mode_id
  gathercols <- as.character(mode_id)
  df_contrib <- gather_(df_contrib, "Mode", "Contribution", gathercols)
  #-----------------------------
  if(is.null(df_group) == F){
    n_group_types <- ncol(df_group) - 1
    group_types <- colnames(df_group)[2:(n_group_types + 1)]
    ind_group_types <- 2:(n_group_types + 1)
    df_plot <- df_contrib
    #colnames(df_plot)[ind_group_types] <- group_types
    for(i in 1:n_group_types){
      ind_i <- i + 1
      this_group_label <- colnames(df_group)[ind_i]
      #df_plot <- df_plot[order(df_plot[, ind_group_types[i]]), ]
      group_label <- paste0("`", this_group_label, "`")
      #---
      if(AggregateContributions == F){
        #-----------------------
        xx <- df_plot[, ind_group_types[i]]
        df_plot$ts_id <- factor(df_plot$ts_id, levels = unique(df_plot$ts_id[order(xx)]))
        gg <- ggplot(df_plot, aes_string(x = "ts_id", y = "Contribution", fill = group_label)) +
          geom_bar(stat = "identity", position = "dodge") +
          #theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) +
          facet_wrap(~ Mode, nrow = round(n_collModes / 2))
        if(n_ts <= 50){
          gg <- gg + theme(axis.text.x = element_text(angle = 60, hjust = 1))
        }else{
          gg <- gg + theme(axis.text.x = element_blank(),
                           axis.title.x = element_blank())
        }
        print(gg)
        #-----------------------
      }else{
        #-----------------------
        N_in_group <- c()
        Pvec_list <- list()
        these_groups <- unique(df_group[, ind_i])
        n_groups <- length(these_groups)
        for(j in 1:n_groups){
          this_group <- these_groups[j]
          Pvec <- rep(0, n_ts)
          ind_this_group <- which(df_group[, ind_i] == this_group)
          ts_in_group <- df_group[ind_this_group, 1]
          n_in_group <- length(ts_in_group)
          Pvec[ind_this_group] <- 1 / n_in_group
          Pvec_list[[j]] <- Pvec
          N_in_group[j] <- n_in_group
        }
        Pmat <- as.matrix(do.call(cbind, Pvec_list))
        #--------------------------
        mat_groupContrib <- t(Pmat) %*% Contribution
        #--------------------------
        df_groupContrib <- as.data.frame(mat_groupContrib)
        colnames(df_groupContrib) <- c(1:n_collModes)
        df_groupContrib$Group <- these_groups
        gathercols <- colnames(df_groupContrib)[1:n_collModes]
        df_plot <- gather_(df_groupContrib, "Mode", "Contribution", gathercols)
        if(n_collModes == 1){
          df_plot <- df_groupContrib
          colnames(df_plot)[1] <- "Value"
          df_plot$Mode <- 1
        }
        gg <- ggplot(df_plot, aes(x = Group, y = Contribution)) +
          geom_bar(stat = "identity") +
          facet_wrap(~ Mode, nrow = floor(n_collModes / 2)) +
          theme(axis.text.x = element_text(angle = 60, hjust = 1))
        print(gg)
        #-----------------------
      }
    }
    
  }else{
    #-----------------------
    df_plot <- df_contrib
    gg <- ggplot(df_plot, aes_string(x = "ts_id", y = "Contribution")) +
      geom_bar(stat = "identity", position = "dodge") +
      #theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) +
      facet_wrap(~ Mode, nrow = round(n_collModes / 2))
    if(n_ts <= 50){
      gg <- gg + theme(axis.text.x = element_text(angle = 60, hjust = 1))
    }else{
      gg <- gg + theme(axis.text.x = element_blank(),
                       axis.title.x = element_blank())
    }
    print(gg)
    #-----------------------
    
  }
  #-----------------------------
  # Main contributors to each mode
  select_main_contributors <- function(colvec, col_order, p_thresh){
    abs_colvec <- abs(colvec)
    q <- quantile(abs_colvec, p = p_thresh)
    ind_main <- which(abs_colvec >= q)
    top_contrib_absval <- sort(abs_colvec[ind_main], decreasing = T)
    ind_match <- match(top_contrib_absval, abs_colvec)
    top_contrib_name <- col_order[ind_match]
    top_contrib_val <- colvec[ind_match]
    df_out <- data.frame(Top_contributor = top_contrib_name, Eigvec_value = top_contrib_val)
    return(df_out)
  }
  p_thresh <- .90
  mainContrib_list <- apply(collModes[, 2:ncol(collModes)], 2,
                            function(x) select_main_contributors(x, col_order, p_thresh))
  for(m in 1:(n_collModes - 1)){mainContrib_list[[m]]$Mode <- m + 1}
  df_mainContributors <- do.call(rbind, mainContrib_list)
  print("Main contributors to each non-leading mode:")
  print(df_mainContributors)
  #--
  df_plot <- df_mainContributors
  df_plot$Mode <- as.factor(df_plot$Mode)
  df_plot$Top_contributor <- factor(df_plot$Top_contributor, levels = unique(df_plot$Top_contributor))
  gg <- ggplot(df_plot, aes(x = Top_contributor, y = Eigvec_value, fill = Mode)) +
    geom_bar(aes(fill = Mode), position = "dodge", stat = "identity") +
    theme(axis.text.x = element_text(angle = 60, hjust = 1))
  print(gg)
  #-----------------------------
  # Plot collective and noise mode eigenvector densities and compare
  # to Porter-Thomas density
  PorterThomas <- rnorm(n_ts)
  df_plot_signal <- data.frame(collModes, PorterThomas)
  colnames(df_plot_signal) <- c(as.character(1:n_collModes), "Porter-Thomas")
  df_plot_signal$Type <- "Signal"
  gathercols <- colnames(df_plot_signal)[-ncol(df_plot_signal)]
  df_plot_signal <- df_plot_signal %>% gather_("Mode", "Value", gathercols)
  #--
  n_noiseModes <- ncol(noiseModes)
  ind_randomly_select <- sample.int(n_noiseModes, 5)
  df_plot_noise <- data.frame(noiseModes[, ind_randomly_select], PorterThomas)
  colnames(df_plot_noise) <- c(as.character(ind_randomly_select + n_collModes_really), "Porter-Thomas")
  df_plot_noise$Type <- "Noise"
  gathercols <- colnames(df_plot_noise)[-ncol(df_plot_noise)]
  df_plot_noise <- df_plot_noise %>% gather_("Mode", "Value", gathercols)
  #--
  df_plot <- rbind(df_plot_signal, df_plot_noise)
  df_plot$Mode <- as.factor(df_plot$Mode)
  gg <- ggplot(df_plot, aes(x = Value, group = Mode, color = Mode)) +
    geom_density() + facet_wrap(~Type, ncol = 2)
  print(gg)
  #-----------------------------
  # Plot Collective mode time series
  if(plot_eigenportfolio_ts == T){
    mat_cmts <- mat_diff %*% collModes_really
    n_cmts <- ncol(mat_cmts)
    lam_sigs <- lam_cor[1:n_collModes_really]
    mat_cmts <- mat_cmts %*% diag(1 / lam_sigs)
    ts_avg <- mat_diff %*% rep(1, n_ts) * 1 / n_ts
    df_cmts <- as.data.frame(mat_cmts)
    colnames(df_cmts) <- c(1:n_collModes_really) #mode_id
    df_cmts$`ts Avg.` <- ts_avg
    df_cmts$Date <- date_vec
    if(class(df_cmts$Date) == "character"){
      df_cmts$Date <- as.Date(df_cmts$Date)
    }
    df_cmts <- df_cmts[-nrow(df_cmts), ]
    df_cmts_wide <- df_cmts
    gathercols <- colnames(df_cmts)[c(1:(ncol(df_cmts) - 1))]
    df_cmts <- df_cmts %>% gather_("Mode", "Value", gathercols)
    #--------------------------------
    df_plot <- subset(df_cmts, Mode %in% c("1", "ts Avg."))
    gg <- ggplot(df_plot, aes(x = Date, y = Value,
                              group = Mode, color = Mode))
    gg <- gg + geom_line()
    print(gg)
    #--------------------------------
    omit <- as.character(c(1, 5:n_collModes_really))
    omit <- c(omit, "ts Avg.")
    df_plot <- subset(df_cmts, !(Mode %in% omit))
    gg <- ggplot(df_plot, aes(x = Date, y = Value,
                              group = Mode, color = Mode))
    gg <- gg + geom_line()
    print(gg)
  }
  #-----------------------------
  lam_signal <- lam_cor[1:n_collModes_really]
  outlist <- list(collModes_really, lam_signal, df_cmts_wide)
  return(outlist)
}
