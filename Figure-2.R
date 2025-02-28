## simulating datasets for: 
## 3 centers,
## 2 treatment groups,
## n=10/group/center, 
## control groups: normal distribution centered at 10, truncated at 0 (outcome can only be positive) and sd = 1
## treated groups: normal distribution centered within a range of 0 to 20 (considering only integers), truncated at 0 (outcome can only be positive) and sd = 1

library(truncnorm)
set.seed(200)

# Function to simulate data with positive values only
simulate_center_data_positive <- function(effect_sizes_row, center_names, pooled_sd, sample_size_per_group) {
  data_list <- list()
  
  for (i in seq_along(center_names)) {
    center_id <- center_names[i]
    effect_size <- effect_sizes_row[i]
    
    control_values <- rtruncnorm(n = sample_size_per_group, a = 0, b = Inf, mean = 10, sd = sd)
    treated_values <- rtruncnorm(n = sample_size_per_group, a = 0, b = Inf, mean = effect_size, sd = sd)

    data <- data.frame(
      EU_id = 1:(2 * sample_size_per_group),
      center = rep(center_id, each = 2 * sample_size_per_group),
      group_id = rep(c("Control", "Treated"), each = sample_size_per_group),
      values = c(control_values, treated_values)
    )
    
    data_list[[i]] <- data
  }
  
  return(data_list)
}

# Parameters
center_names <- c("Center1", "Center2", "Center3")
effect_sizes <- as.matrix(expand.grid(
  center1 = seq(from = 0, to = 20, by = 1),
  center2 = seq(from = 0, to = 20, by = 1),
  center3 = seq(from = 0, to = 20, by = 1)
))
sd <- 1.0
sample_size_per_group <- 10

# Loop through each row of the effect size matrix
simulated_datasets <- list()
for (row_index in 1:nrow(effect_sizes)) {
  effect_sizes_row <- effect_sizes[row_index, ]
  
  simulated_data_list <- simulate_center_data_positive(effect_sizes_row, center_names, sd, sample_size_per_group)
  
  simulated_datasets[[row_index]] <- simulated_data_list
}

# Combining data from all centers in a single dataframe
combined_datasets <- lapply(simulated_datasets, function(dataset_list) {
  do.call(rbind, dataset_list)
})

# getting ES in standardized mean difference (SMD)
library(metafor)
library(tidyr)
library(dplyr)

simulated_ES <- list()

for (i in 1:length(combined_datasets)) {
  example_df = combined_datasets[[i]]
example_summary = example_df %>% group_by(center, group_id) %>% summarize(mi = mean(values))
example_summary_wide <- spread(example_summary, group_id, mi)
example_overall = example_df %>% group_by(group_id) %>% summarize(mi = mean(values))
example_overall_wide <- spread(example_overall, group_id, mi)
example_means = rows_append(example_summary_wide, example_overall_wide) %>% rename(m1 = Control, m2 = Treated)

example_summary = example_df %>% group_by(center, group_id) %>% summarize(sdi = sd(values))
example_summary_wide <- spread(example_summary, group_id, sdi)
example_overall = example_df %>% group_by(group_id) %>% summarize(sdi = sd(values))
example_overall_wide <- spread(example_overall, group_id, sdi)
example_sds = rows_append(example_summary_wide, example_overall_wide)  %>% rename(sd1 = Control, sd2 = Treated)

example_means_sds = full_join(example_means, example_sds, by = "center")
example_means_sds$center[is.na(example_means_sds$center)] = "pooled"

example_ES = escalc(measure = "SMD", m1i = m1, m2i = m2, sd1i = sd1, sd2i = sd2, 
                    n1i = c(10,10,10,30), n2i = c(10,10,10,30), data = example_means_sds)

simulated_ES[[i]] = example_ES
i
}


# plots for SMD = 1
library(ggplot2)
library(ggbeeswarm)
library(viridis)

SMD_1_indices <- list()

row_index <- 4  
column_index <- 6

lower_bound <- 0.95
upper_bound <- 1.05

for (i in seq_along(simulated_ES)) {
  df <- simulated_ES[[i]]
  value <- df[row_index, column_index]
  
  if (value >= lower_bound && value <= upper_bound) {
    SMD_1_indices[[length(SMD_1_indices) + 1]] <- i
  }
}
  

for (i in seq_along(SMD_1_indices)) {
  element_index = as.numeric(SMD_1_indices[[i]])
  selected_example = combined_datasets[[element_index]]
  
  ReplicateAverages <- selected_example %>% group_by(group_id, center) %>% summarise(values=mean(values))
  
  selected_example_plot = 
    ggplot(selected_example, aes(x=group_id,y=values,color=factor(center))) + 
    geom_beeswarm(cex=3, alpha = 0.5) + 
    geom_beeswarm(data=ReplicateAverages, size=5) + 
    scale_color_viridis(discrete = T) +
    theme_classic() + 
    theme(legend.title = element_blank(), axis.title.x = element_blank()) + 
    scale_y_continuous(name = "outcome value") +
    labs(title = paste("Overall SMD =", round(simulated_ES[[element_index]][4,6], 1)), 
         subtitle = paste("Center1 =", round(simulated_ES[[element_index]][1,6], 1), 
                          "| Center2 =", round(simulated_ES[[element_index]][2,6], 1),
                          "| Center3 =", round(simulated_ES[[element_index]][3,6], 1)))
  
  ggsave(selected_example_plot, filename = paste("example", element_index, ".png"), path = "./figures-3Centers/SMD_1")
}

## after visual inspection of graphs, examples were selected:

# all centers have effects in the same direction
figA_data = combined_datasets[[4127]]

ReplicateAverages <- figA_data %>% group_by(group_id, center) %>% summarise(values=mean(values))
group_id_numeric <- c("Control" = 1, "Treated" = 2) 

figA_plot =
ggplot(figA_data, aes(x=group_id,y=values,color=factor(center))) + 
  geom_beeswarm(cex=3, alpha = 0.5) + 
  geom_segment(data = ReplicateAverages, aes(x = group_id_numeric[group_id]-0.2, xend = group_id_numeric[group_id] + 0.2, y = values, yend = values, color = center),
               linewidth = 1) +
  scale_color_viridis(discrete = T) +
  theme_classic() + 
  theme(legend.title = element_blank(), axis.title.x = element_blank()) + 
  scale_y_continuous(name = "outcome value", limits = c(0,18)) +
  labs(title = paste("Overall SMD =", round(simulated_ES[[4127]][4,6], 1)), 
       subtitle = paste("Center1 =", round(simulated_ES[[4127]][1,6], 1), 
                        "| Center2 =", round(simulated_ES[[4127]][2,6], 1),
                        "| Center3 =", round(simulated_ES[[4127]][3,6], 1)))

# 2 centers show almost no effect, 1 center has big effect
figB_data = combined_datasets[[1082]]

ReplicateAverages <- figB_data %>% group_by(group_id, center) %>% summarise(values=mean(values))
group_id_numeric <- c("Control" = 1, "Treated" = 2) 

figB_plot =
  ggplot(figB_data, aes(x=group_id,y=values,color=factor(center))) + 
  geom_beeswarm(cex=3, alpha = 0.5) + 
  geom_segment(data = ReplicateAverages, aes(x = group_id_numeric[group_id]-0.2, xend = group_id_numeric[group_id] + 0.2, y = values, yend = values, color = center),
               linewidth = 1) +
  scale_color_viridis(discrete = T) +
  theme_classic() + 
  theme(legend.title = element_blank(), axis.title.x = element_blank()) + 
  scale_y_continuous(name = "outcome value", limits = c(0,18)) +
  labs(title = paste("Overall SMD =", round(simulated_ES[[1082]][4,6], 1)), 
       subtitle = paste("Center1 =", round(simulated_ES[[1082]][1,6], 1), 
                        "| Center2 =", round(simulated_ES[[1082]][2,6], 1),
                        "| Center3 =", round(simulated_ES[[1082]][3,6], 1)))

# 2 centers have effect in one direction, 1 center in the opposite
figC_data = combined_datasets[[736]]

ReplicateAverages <- figC_data %>% group_by(group_id, center) %>% summarise(values=mean(values))
group_id_numeric <- c("Control" = 1, "Treated" = 2) 

figC_plot =
  ggplot(figC_data, aes(x=group_id,y=values,color=factor(center))) + 
  geom_beeswarm(cex=3, alpha = 0.5) + 
  geom_segment(data = ReplicateAverages, aes(x = group_id_numeric[group_id]-0.2, xend = group_id_numeric[group_id] + 0.2, y = values, yend = values, color = center),
               linewidth = 1) +
  scale_color_viridis(discrete = T) +
  theme_classic() + 
  theme(legend.title = element_blank(), axis.title.x = element_blank()) + 
  scale_y_continuous(name = "outcome value", limits = c(0,18)) +
  labs(title = paste("Overall SMD =", round(simulated_ES[[736]][4,6], 1)), 
       subtitle = paste("Center1 =", round(simulated_ES[[736]][1,6], 1), 
                        "| Center2 =", round(simulated_ES[[736]][2,6], 1),
                        "| Center3 =", round(simulated_ES[[736]][3,6], 1)))


# 2 center with similar effects, 1 center with no effect

figD_data = combined_datasets[[4170]]

ReplicateAverages <- figD_data %>% group_by(group_id, center) %>% summarise(values=mean(values))
group_id_numeric <- c("Control" = 1, "Treated" = 2) 

figD_plot =
  ggplot(figD_data, aes(x=group_id,y=values,color=factor(center))) + 
  geom_beeswarm(cex=3, alpha = 0.5) + 
  geom_segment(data = ReplicateAverages, aes(x = group_id_numeric[group_id]-0.2, xend = group_id_numeric[group_id] + 0.2, y = values, yend = values, color = center),
               linewidth = 1) +
  scale_color_viridis(discrete = T) +
  theme_classic() + 
  theme(legend.title = element_blank(), axis.title.x = element_blank()) + 
  scale_y_continuous(name = "outcome value", limits = c(0,18)) +
  labs(title = paste("Overall SMD =", round(simulated_ES[[4170]][4,6], 1)), 
       subtitle = paste("Center1 =", round(simulated_ES[[4170]][1,6], 1), 
                        "| Center2 =", round(simulated_ES[[4170]][2,6], 1),
                        "| Center3 =", round(simulated_ES[[4170]][3,6], 1)))

## combining all figure

ggpubr::ggarrange(figA_plot, figB_plot, figC_plot, figD_plot, labels = "AUTO")
ggsave("fig-2.png", units = "cm", width = 20, height = 15)


## updated datasets
# all centers have effects in the same direction
figA_data_n = combined_datasets[[4167]]

ReplicateAverages <- figA_data_n %>% group_by(group_id, center) %>% summarise(values=mean(values))
group_id_numeric <- c("Control" = 1, "Treated" = 2) 

figA_plot_n =
  ggplot(figA_data_n, aes(x=group_id,y=values,color=factor(center))) + 
  geom_beeswarm(cex=3, alpha = 0.5) + 
  geom_segment(data = ReplicateAverages, aes(x = group_id_numeric[group_id]-0.2, xend = group_id_numeric[group_id] + 0.2, y = values, yend = values, color = center),
               linewidth = 1) +
  scale_color_manual(values = c("#440154", "#21918c", "#edc12f")) +
  theme_classic() + 
  theme(legend.title = element_blank(), axis.title.x = element_blank()) + 
  scale_y_continuous(name = "outcome value", limits = c(0,18)) +
  labs(title = paste("Overall SMD =", round(simulated_ES[[4167]][4,6], 1)), 
       subtitle = paste("Center1 =", round(simulated_ES[[4167]][1,6], 1), 
                        "| Center2 =", round(simulated_ES[[4167]][2,6], 1),
                        "| Center3 =", round(simulated_ES[[4167]][3,6], 1)))

# 2 centers show almost no effect, 1 center has big effect
figB_data_n = combined_datasets[[1103]]

ReplicateAverages <- figB_data_n %>% group_by(group_id, center) %>% summarise(values=mean(values))
group_id_numeric <- c("Control" = 1, "Treated" = 2) 

figB_plot_n =
  ggplot(figB_data_n, aes(x=group_id,y=values,color=factor(center))) + 
  geom_beeswarm(cex=3, alpha = 0.5) + 
  geom_segment(data = ReplicateAverages, aes(x = group_id_numeric[group_id]-0.2, xend = group_id_numeric[group_id] + 0.2, y = values, yend = values, color = center),
               linewidth = 1) +
  scale_color_manual(values = c("#440154", "#21918c", "#edc12f")) +
  theme_classic() + 
  theme(legend.title = element_blank(), axis.title.x = element_blank()) + 
  scale_y_continuous(name = "outcome value", limits = c(0,18)) +
  labs(title = paste("Overall SMD =", round(simulated_ES[[1103]][4,6], 1)), 
       subtitle = paste("Center1 =", round(simulated_ES[[1103]][1,6], 1), 
                        "| Center2 =", round(simulated_ES[[1103]][2,6], 1),
                        "| Center3 =", round(simulated_ES[[1103]][3,6], 1)))

# 2 centers have effect in one direction, 1 center in the opposite
figC_data_n = combined_datasets[[296]]

ReplicateAverages <- figC_data_n %>% group_by(group_id, center) %>% summarise(values=mean(values))
group_id_numeric <- c("Control" = 1, "Treated" = 2) 

figC_plot_n =
  ggplot(figC_data_n, aes(x=group_id,y=values,color=factor(center))) + 
  geom_beeswarm(cex=3, alpha = 0.5) + 
  geom_segment(data = ReplicateAverages, aes(x = group_id_numeric[group_id]-0.2, xend = group_id_numeric[group_id] + 0.2, y = values, yend = values, color = center),
               linewidth = 1) +
  scale_color_manual(values = c("#440154", "#21918c", "#edc12f")) +
  theme_classic() + 
  theme(legend.title = element_blank(), axis.title.x = element_blank()) + 
  scale_y_continuous(name = "outcome value", limits = c(0,18)) +
  labs(title = paste("Overall SMD =", round(simulated_ES[[296]][4,6], 1)), 
       subtitle = paste("Center1 =", round(simulated_ES[[296]][1,6], 1), 
                        "| Center2 =", round(simulated_ES[[296]][2,6], 1),
                        "| Center3 =", round(simulated_ES[[296]][3,6], 1)))


# 2 center with similar effects, 1 center with no effect

figD_data_n = combined_datasets[[3707]]

ReplicateAverages <- figD_data_n %>% group_by(group_id, center) %>% summarise(values=mean(values))
group_id_numeric <- c("Control" = 1, "Treated" = 2) 

figD_plot_n =
  ggplot(figD_data_n, aes(x=group_id,y=values,color=factor(center))) + 
  geom_beeswarm(cex=3, alpha = 0.5) + 
  geom_segment(data = ReplicateAverages, aes(x = group_id_numeric[group_id]-0.2, xend = group_id_numeric[group_id] + 0.2, y = values, yend = values, color = center),
               linewidth = 1) +
  scale_color_manual(values = c("#440154", "#21918c", "#edc12f")) +
  theme_classic() + 
  theme(legend.title = element_blank(), axis.title.x = element_blank()) + 
  scale_y_continuous(name = "outcome value", limits = c(0,18)) +
  labs(title = paste("Overall SMD =", round(simulated_ES[[3707]][4,6], 1)), 
       subtitle = paste("Center1 =", round(simulated_ES[[3707]][1,6], 1), 
                        "| Center2 =", round(simulated_ES[[3707]][2,6], 1),
                        "| Center3 =", round(simulated_ES[[3707]][3,6], 1)))

## combining all figure

ggpubr::ggarrange(figA_plot_n, figB_plot_n, figC_plot_n, figD_plot_n, labels = "AUTO")
ggsave("fig-2_n.png", units = "cm", width = 20, height = 15)
