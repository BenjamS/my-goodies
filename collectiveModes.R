collectiveModes <- function(mat_diff, datevec, df_group,
                            Contrib_as_ModeSq = T,
                            AggregateContributions = T){
  
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
  n_collModes <- ncol(collModes)
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
  df_collModes <- data.frame(ts_id = col_order, Contribution)
  mode_id <- c(1:n_collModes)
  colnames(df_collModes)[2:(n_collModes + 1)] <- mode_id
  gathercols <- mode_id
  df_collModes <- gather_(df_collModes, "Mode", "Contribution", gathercols)
  n_ts <- ncol(mat_diff)
  n_group_types <- ncol(df_group) - 1
  group_types <- colnames(df_group)[2:(n_group_types + 1)]
  ind_group_types <- (ncol(df_collModes) + 1):(ncol(df_collModes) + n_group_types)
  df_plot <- cbind(df_collModes, df_group[, c(2:ncol(df_group))])
  colnames(df_plot)[ind_group_types] <- group_types
  #gg_list <- list()
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
  #-----------------------------
  # Collective mode time series
  mat_cmts <- mat_diff %*% collModes
  ts_avg <- mat_diff %*% rep(1, n_ts) * 1 / n_ts
  # class(mat_cmts)
  # class(ts_avg)
  df_plot <- as.data.frame(mat_cmts)
  colnames(df_plot) <- mode_id
  df_plot$`ts Avg.` <- ts_avg
  df_plot$Date <- date_vec
  if(class(df_plot$Date) == "character"){
    df_plot$Date <- as.Date(df_plot$Date)
  }
  df_cmts <- df_plot
  gathercols <- colnames(df_plot)[c(1:(ncol(df_plot) - 1))]
  df_plot <- df_plot %>% gather_("Mode", "Value", gathercols)
  df_plot$Lambda <- 0.5
  u <- df_plot$Mode
  lam_cor_scaled <- lam_cor / max(lam_cor)
  for(i in 1:n_collModes){
    df_plot$Lambda[which(u == i)] <- lam_cor_scaled[i]
  }
  zdf_plot <- df_plot %>% group_by(Mode) %>% mutate(Value = scale(Value))
  #--
  gg <- ggplot(zdf_plot, aes(x = Date, y = Value,
                             group = Mode, color = Mode,
                             size = Lambda))
  gg <- gg + geom_line()
  print(gg)
  #-----------------------------
  outlist <- list(as.data.frame(collModes), df_cmts)
  return(outlist)
}