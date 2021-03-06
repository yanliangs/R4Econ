---
title: "Joint Quantiles from Multiple Continuous Variables as a Categorical Variable with Linear Index"
titleshort: "Quantiles from Multiple Variables"
description: |
  Dataframe of Variables' Quantiles by Panel Groups, and quantile categorical variables for panel within Group Observations
  Quantile cut variable suffix and quantile labeling, and Joint Quantile Categorical Variable with Linear Index.
core:
  - package: dplyr
    code: |
      group_by()
      slice(1L)
      lapply(enframe(quantiles()))
      reduce(full_join)
      mutate_at(funs(q=f_cut(.,cut))))
      levels()
      rename_at()
      unlist(lapply)
      mutate(!!var.jnt.quantile := group_indices(., !!!syms(quantile.cut)))
date: 2020-04-01
output:
  pdf_document:
    pandoc_args: '../../_output_kniti_pdf.yaml'
    includes:
      in_header: '../../preamble.tex'
  html_document:
    pandoc_args: '../../_output_kniti_html.yaml'
    includes:
      in_header: "../../hdga.html"
always_allow_html: true
urlcolor: blue
---

### Joint Quantiles from Continuous

```{r global_options, include = FALSE}
try(source("../../.Rprofile"))
```

`r text_shared_preamble_one`
`r text_shared_preamble_two`
`r text_shared_preamble_thr`

There are multiple or a single continuous variables. Find which quantile each observation belongs to for each of the variables. Then also generate a joint/interaction variable of all combinations of quantiles from different variables.

The program has these features:

1. Quantiles breaks are generated based on group_by characteristics, meaning quantiles for individual level characteristics when data is panel
2. Quantiles variables apply to full panel at within-group observation levels.
3. Robust to non-unique breaks for quantiles (non-unique grouped together)
4. Quantile categories have detailed labeling (specifying which non-unique groupings belong to quantile)

When joining multiple quantile variables together:

1. First check if only calculate quantiles at observations where all quantile base variables are not null
2. Calculate Quantiles for each variable, with different quantile levels for sub-groups of variables
3. Summary statistics by mulltiple quantile-categorical variables, summary

#### Build Program

##### Support Functions

```{r}
# Quantiles for any variable
gen_quantiles <- function(var, df, prob=c(0.25, 0.50, 0.75)) {
  enframe(quantile(as.numeric(df[[var]]), 
                   prob, na.rm=TRUE), 'quant.perc', var)
}
# Support Functions for Variable Suffix
f_Q_suffix <- function(seq.quantiles) {
  quantile.suffix <- paste0('Qs', min(seq.quantiles),
                            'e', max(seq.quantiles),
                            'n', (length(seq.quantiles)-1))
}
# Support Functions for Quantile Labeling
f_Q_label <- function(arr.quantiles,
                      arr.sort.unique.quantile,
                      seq.quantiles) {
  paste0('(',
         paste0(which(arr.quantiles %in% 
                        arr.sort.unique.quantile), collapse=','),
         ') of ', f_Q_suffix(seq.quantiles))
}
# Generate New Variable Names with Quantile Suffix
f_var_rename <- function(name, seq.quantiles) {
  quantile.suffix <- paste0('_', f_Q_suffix(seq.quantiles))
  return(sub('_q', quantile.suffix, name))
}

# Check Are Values within Group By Unique? If not, STOP
f_check_distinct_ingroup <- 
  function(df, vars.group_by, vars.values_in_group) {
  
  df.uniqus.in.group <- df %>% group_by(!!!syms(vars.group_by)) %>%
    mutate(quant_vars_paste = 
             paste(!!!(syms(vars.values_in_group)), sep='-')) %>%
    mutate(unique_in_group = n_distinct(quant_vars_paste)) %>%
    slice(1L) %>%
    ungroup() %>%
    group_by(unique_in_group) %>%
    summarise(n=n())
  
  if (sum(df.uniqus.in.group$unique_in_group) > 1) {
    print(df.uniqus.in.group)
    print(paste('vars.values_in_group', vars.values_in_group, sep=':'))
    print(paste('vars.group_by', vars.group_by, sep=':'))
    stop(paste0("The variables for which quantiles are to be',
                'taken are not identical within the group variables"))
  }
}
```

##### Data Slicing and Quantile Generation

- Function 1: generate quantiles based on group-specific characteristics. the groups could be at the panel observation level as well.

```{r}
# First Step, given groups, generate quantiles based on group characteristics
# vars.cts2quantile <- c('wealthIdx', 'hgt0', 'wgt0')
# seq.quantiles <- c(0, 0.3333, 0.6666, 1.0)
# vars.group_by <- c('indi.id')
# vars.arrange <- c('indi.id', 'svymthRound')
# vars.continuous <- c('wealthIdx', 'hgt0', 'wgt0')
df_sliced_quantiles <- function(df, vars.cts2quantile, seq.quantiles,
                                vars.group_by, vars.arrange) {

    # Slicing data
    df.grp.L1 <- df %>% group_by(!!!syms(vars.group_by)) %>% 
      arrange(!!!syms(vars.arrange)) %>% slice(1L) %>% ungroup()

    # Quantiles based on sliced data
    df.sliced.quantiles <- 
      lapply(vars.cts2quantile, gen_quantiles, df=df.grp.L1, prob=seq.quantiles) %>% 
      reduce(full_join)

    return(list(df.sliced.quantiles=df.sliced.quantiles,
                df.grp.L1=df.grp.L1))
}
```

##### Data Cutting

- Function 2: cut groups for full panel dataframe based on group-specific characteristics quantiles.

```{r}
# Cutting Function, Cut Continuous Variables into Quantiles with labeing
f_cut <- function(var, df.sliced.quantiles, seq.quantiles, 
                  include.lowest=TRUE, fan.labels=TRUE, print=FALSE) {
  
  # unparsed string variable name
  var.str <- substitute(var)
  
  # Breaks
  arr.quantiles <- df.sliced.quantiles[[var.str]]
  arr.sort.unique.quantiles <- sort(unique(arr.quantiles))
  if (print) {
    print(arr.sort.unique.quantiles)
  }
  
  # Regular cutting With Standard Labels
  # TRUE, means the lowest group has closed bracket left and right
  var.quantile <- cut(var, breaks=arr.sort.unique.quantiles, 
                      include.lowest=include.lowest)
  
  # Use my custom labels
  if (fan.labels) {
    levels.suffix <- 
      lapply(arr.sort.unique.quantiles[1:(length(arr.sort.unique.quantiles)-1)],
             f_Q_label,
             arr.quantiles=arr.quantiles,
             seq.quantiles=seq.quantiles)
    if (print) {
      print(levels.suffix)
    }
    levels(var.quantile) <- paste0(levels(var.quantile), '; ', levels.suffix)
  }
  
  # Return
  return(var.quantile)
}
```

```{r}
# Combo Quantile Function
# vars.cts2quantile <- c('wealthIdx', 'hgt0', 'wgt0')
# seq.quantiles <- c(0, 0.3333, 0.6666, 1.0)
# vars.group_by <- c('indi.id')
# vars.arrange <- c('indi.id', 'svymthRound')
# vars.continuous <- c('wealthIdx', 'hgt0', 'wgt0')
df_cut_by_sliced_quantiles <- function(df, vars.cts2quantile, seq.quantiles,
                                       vars.group_by, vars.arrange) {
  
  
  # Check Are Values within Group By Unique? If not, STOP
  f_check_distinct_ingroup(df, vars.group_by, vars.values_in_group=vars.cts2quantile)
  
  # First Step Slicing
  df.sliced <- df_sliced_quantiles(df, vars.cts2quantile, 
                                   seq.quantiles, vars.group_by, vars.arrange)
  
  # Second Step Generate Categorical Variables of Quantiles
  df.with.cut.quant <- df %>% 
    mutate_at(vars.cts2quantile,
              funs(q=f_cut(., df.sliced$df.sliced.quantiles,
                           seq.quantiles=seq.quantiles,
                           include.lowest=TRUE, fan.labels=TRUE)))
  
  if (length(vars.cts2quantile) > 1) {
    df.with.cut.quant <- 
      df.with.cut.quant %>%
      rename_at(vars(contains('_q')), 
                funs(f_var_rename(., seq.quantiles=seq.quantiles)))
  } else {
    new.var.name <- paste0(vars.cts2quantile[1], '_', f_Q_suffix(seq.quantiles))
    df.with.cut.quant <- df.with.cut.quant %>% rename(!!new.var.name := q)
  }
  
  # Newly Generated Quantile-Cut Variables
  vars.quantile.cut <- df.with.cut.quant %>%
    select(matches(paste0(vars.cts2quantile, collapse='|'))) %>%
    select(matches(f_Q_suffix(seq.quantiles)))
  
  # Return
  return(list(df.with.cut.quant = df.with.cut.quant,
              df.sliced.quantiles=df.sliced$df.sliced.quantiles,
              df.grp.L1=df.sliced$df.grp.L1,
              vars.quantile.cut=vars.quantile.cut))
  
}
```

##### Different Vars Different Probabilities Joint Quantiles

- Accomondate multiple continuousv ariables
- Different percentiles
- list of lists
- generate joint categorical variables
- keep only values that exist for all quantile base vars

```{r}
# Function to handle list inputs with different quantiles vars and probabilities
df_cut_by_sliced_quantiles_grps <- 
  function(quantile.grp.list, df, vars.group_by, vars.arrange) {
    vars.cts2quantile <- quantile.grp.list$vars
    seq.quantiles <- quantile.grp.list$prob
    return(df_cut_by_sliced_quantiles(
      df, vars.cts2quantile, seq.quantiles, vars.group_by, vars.arrange))
  }
# Show Results
df_cut_by_sliced_quantiles_joint_results_grped <- 
  function(df.with.cut.quant.all, vars.cts2quantile, vars.group_by, vars.arrange,
           vars.quantile.cut.all, var.qjnt.grp.idx) {
    # Show ALL
    df.group.panel.cnt.mean <- df.with.cut.quant.all %>% 
      group_by(!!!syms(vars.quantile.cut.all), 
               !!sym(var.qjnt.grp.idx)) %>%
      summarise_at(vars.cts2quantile, funs(mean, n()))
    
    # Show Based on SLicing first
    df.group.slice1.cnt.mean <- df.with.cut.quant.all %>% 
      group_by(!!!syms(vars.group_by)) %>% 
      arrange(!!!syms(vars.arrange)) %>% slice(1L) %>%
      group_by(!!!syms(vars.quantile.cut.all), !!sym(var.qjnt.grp.idx)) %>%
      summarise_at(vars.cts2quantile, funs(mean, n()))
    
    return(list(df.group.panel.cnt.mean=df.group.panel.cnt.mean,
                df.group.slice1.cnt.mean=df.group.slice1.cnt.mean))
  }
```

```{r}
# # Joint Quantile Group Name
# var.qjnt.grp.idx <- 'group.index'
# # Generate Categorical Variables of Quantiles
# vars.group_by <- c('indi.id')
# vars.arrange <- c('indi.id', 'svymthRound')
# # Quantile Variables and Quantiles
# vars.cts2quantile.wealth <- c('wealthIdx')
# seq.quantiles.wealth <- c(0, .5, 1.0)
# vars.cts2quantile.wgthgt <- c('hgt0', 'wgt0')
# seq.quantiles.wgthgt <- c(0, .3333, 0.6666, 1.0)
# drop.any.quantile.na <- TRUE
# # collect to list
# list.cts2quantile <- list(list(vars=vars.cts2quantile.wealth,
#                                prob=seq.quantiles.wealth),
#                           list(vars=vars.cts2quantile.wgthgt,
#                                prob=seq.quantiles.wgthgt))

df_cut_by_sliced_quantiles_joint <- 
  function(df, var.qjnt.grp.idx,
           list.cts2quantile,
           vars.group_by, vars.arrange,
           drop.any.quantile.na = TRUE,
           toprint = TRUE) {
    
    #  Original dimensions
    if(toprint) {
      print(dim(df))
    }
    
    # All Continuous Variables from lists
    vars.cts2quantile <- unlist(lapply(list.cts2quantile, 
                                       function(elist) elist$vars))
    vars.cts2quantile
    
    # Keep only if not NA for all Quantile variables
    if (drop.any.quantile.na) {
      df.select <- df %>% drop_na(c(vars.group_by, vars.arrange, vars.cts2quantile))
    } else {
      df.select <- df
    }
    
    if(toprint) {
      print(dim(df.select))
    }
    
    # Apply qunatile function to all elements of list of list
    df.cut.list <- 
      lapply(list.cts2quantile, df_cut_by_sliced_quantiles_grps,
             df=df.select, vars.group_by=vars.group_by, vars.arrange=vars.arrange)
    
    # Reduce Resulting Core Panel Matrix Together
    df.with.cut.quant.all <- 
      lapply(df.cut.list, function(elist) elist$df.with.cut.quant) %>% reduce(left_join)
    df.sliced.quantiles.all <- 
      lapply(df.cut.list, function(elist) elist$df.sliced.quantiles)
    
    if(toprint) {
      print(dim(df.with.cut.quant.all))
    }
    
    # Obrain Newly Created Quantile Group Variables
    vars.quantile.cut.all <- 
      unlist(lapply(df.cut.list, function(elist) names(elist$vars.quantile.cut)))
    if(toprint) {
      print(vars.quantile.cut.all)
      print(summary(df.with.cut.quant.all %>% select(one_of(vars.quantile.cut.all))))
    }
    
    # Generate Joint Quantile Index Variable
    df.with.cut.quant.all <- df.with.cut.quant.all %>% 
      mutate(!!var.qjnt.grp.idx := group_indices(., !!!syms(vars.quantile.cut.all)))
    
    # Quantile Groups
    arr.group.idx <- t(sort(unique(df.with.cut.quant.all[[var.qjnt.grp.idx]])))
    
    # Results Display
    df.group.print <- df_cut_by_sliced_quantiles_joint_results_grped(
      df.with.cut.quant.all, vars.cts2quantile,
      vars.group_by, vars.arrange,
      vars.quantile.cut.all, var.qjnt.grp.idx)
    
    # list to Return
    # These returns are the same as returns earlier: df_cut_by_sliced_quantiles
    # Except that they are combined together
    return(list(df.with.cut.quant = df.with.cut.quant.all,
                df.sliced.quantiles = df.sliced.quantiles.all,
                df.grp.L1 = (df.cut.list[[1]])$df.grp.L1,
                vars.quantile.cut = 
                  vars.quantile.cut.all,
                df.group.panel.cnt.mean = 
                  df.group.print$df.group.panel.cnt.mean,
                df.group.slice1.cnt.mean = 
                  df.group.print$df.group.slice1.cnt.mean))
    
}
```

#### Program Testing

Load Data

```{r}
# Library
library(tidyverse)

# Load Sample Data
setwd('C:/Users/fan/R4Econ/_data/')
df <- read_csv('height_weight.csv')
```

##### Hgt0 3 Groups

```{r}
# Joint Quantile Group Name
var.qjnt.grp.idx <- 'group.index'
list.cts2quantile <- list(list(vars=c('hgt0'), prob=c(0, .3333, 0.6666, 1.0)))
results <- df_cut_by_sliced_quantiles_joint(
  df, var.qjnt.grp.idx, list.cts2quantile,
  vars.group_by = c('indi.id'), vars.arrange = c('indi.id', 'svymthRound'),
  drop.any.quantile.na = TRUE, toprint = FALSE)
# Show Results
results$df.group.slice1.cnt.mean
```

##### Wealth 5 Groups Guatemala

```{r}
# Joint Quantile Group Name
var.qjnt.grp.idx <- 'wltQuintle.index'
list.cts2quantile <- list(list(vars=c('wealthIdx'), prob=seq(0, 1.0, 0.20)))
results <- df_cut_by_sliced_quantiles_joint((
  df %>% filter(S.country == 'Guatemala')),
  var.qjnt.grp.idx, list.cts2quantile,
  vars.group_by = c('indi.id'), vars.arrange = c('indi.id', 'svymthRound'),
  drop.any.quantile.na = TRUE, toprint = FALSE)
# Show Results
results$df.group.slice1.cnt.mean
```

##### Hgt0 2 groups, Wgt0 2 groups too

```{r}
# Joint Quantile Group Name
var.qjnt.grp.idx <- 'group.index'
list.cts2quantile <- list(list(vars=c('hgt0', 'wgt0'), prob=c(0, .5, 1.0)))
results <- df_cut_by_sliced_quantiles_joint(
  df, var.qjnt.grp.idx, list.cts2quantile,
  vars.group_by = c('indi.id'), vars.arrange = c('indi.id', 'svymthRound'),
  drop.any.quantile.na = TRUE, toprint = FALSE)
# Show Results
results$df.group.slice1.cnt.mean
```

##### Hgt0 2 groups, Wealth 2 groups, Cebu Only

```{r}
# Joint Quantile Group Name
var.qjnt.grp.idx <- 'group.index'
list.cts2quantile <- list(
  list(vars=c('wealthIdx'), prob=c(0, .5, 1.0)), 
  list(vars=c('hgt0'), prob=c(0, .333, 0.666, 1.0)))
results <- df_cut_by_sliced_quantiles_joint(
  (df %>% filter(S.country == 'Cebu')),
  var.qjnt.grp.idx, list.cts2quantile,
  vars.group_by = c('indi.id'), vars.arrange = c('indi.id', 'svymthRound'),
  drop.any.quantile.na = TRUE, toprint = FALSE)
# Show Results
results$df.group.slice1.cnt.mean
```

##### Results of income + Wgt0 + Hgt0 joint Gruops in Cebu

Weight at month 0 below and above median, height at month zero into three terciles.

```{r}
# Joint Quantile Group Name
var.qjnt.grp.idx <- 'wltHgt0Wgt0.index'
list.cts2quantile <- list(
  list(vars=c('wealthIdx'), prob=c(0, .5, 1.0)), 
  list(vars=c('hgt0', 'wgt0'), prob=c(0, .5, 1.0)))
results <- df_cut_by_sliced_quantiles_joint(
  (df %>% filter(S.country == 'Cebu')),
  var.qjnt.grp.idx, list.cts2quantile,
  vars.group_by = c('indi.id'), vars.arrange = c('indi.id', 'svymthRound'),
  drop.any.quantile.na = TRUE, toprint = FALSE)
# Show Results
results$df.group.slice1.cnt.mean
```

#### Line by Line--Quantiles Var by Var

The idea of the function is to generate quantiles levels first, and then use those to generate the categories based on quantiles. Rather than doing this in one step. These are done in two steps, to increase clarity in the quantiles used for quantile category generation. And a dataframe with these quantiles are saved as a separate output of the function.

##### Dataframe of Variables' Group-by Level Quantiles

Quantiles from Different Variables. Note that these variables are specific to the individual, not individual/month. So we need to first slick the data, so that we only get the first rows.

Do this in several steps to clarify group_by level. No speed loss.

```{r}
# Selected Variables, many Percentiles
vars.group_by <- c('indi.id')
vars.arrange <- c('indi.id', 'svymthRound')
vars.cts2quantile <- c('wealthIdx', 'hgt0', 'wgt0')
seq.quantiles <- c(0, 0.3333, 0.6666, 1.0)
df.sliced <- df_sliced_quantiles(
  df, vars.cts2quantile, seq.quantiles, vars.group_by, vars.arrange)
df.sliced.quantiles <- df.sliced$df.sliced.quantiles
df.grp.L1 <- df.sliced$df.grp.L1
```

```{r}
df.sliced.quantiles
```

```{r}
# Quantiles all Variables
suppressMessages(lapply(
  names(df), gen_quantiles, df=df.grp.L1, 
  prob=seq(0.1,0.9,0.10)) %>% reduce(full_join)) %>% 
  kable() %>% kable_styling_fc_wide()
```

##### Cut Quantile Categorical Variables

Using the Quantiles we have generate, cut the continuous variables to generate categorical quantile variables in the full dataframe.

Note that we can only cut based on unique breaks, but sometimes quantile break-points are the same if some values are often observed, and also if there are too few observations with respect to quantile groups.

To resolve this issue, we only look at unique quantiles.

We need several support Functions:
1. support functions to generate suffix for quantile variables based on quantile cuts
2. support for labeling variables of resulting quantiles beyond bracketing

```{r}
# Function Testing
arr.quantiles <- df.sliced.quantiles[[substitute('wealthIdx')]]
arr.quantiles
arr.sort.unique.quantiles <- 
  sort(unique(df.sliced.quantiles[[substitute('wealthIdx')]]))
arr.sort.unique.quantiles
f_Q_label(arr.quantiles, arr.sort.unique.quantiles[1], seq.quantiles)
f_Q_label(arr.quantiles, arr.sort.unique.quantiles[2], seq.quantiles)
lapply(arr.sort.unique.quantiles[1:(length(arr.sort.unique.quantiles)-1)],
       f_Q_label,
       arr.quantiles=arr.quantiles,
       seq.quantiles=seq.quantiles)
```

```{r}
# Generate Categorical Variables of Quantiles
vars.group_by <- c('indi.id')
vars.arrange <- c('indi.id', 'svymthRound')
vars.cts2quantile <- c('wealthIdx', 'hgt0', 'wgt0')
seq.quantiles <- c(0, 0.3333, 0.6666, 1.0)
df.cut <- df_cut_by_sliced_quantiles(
  df, vars.cts2quantile, seq.quantiles, vars.group_by, vars.arrange)
vars.quantile.cut <- df.cut$vars.quantile.cut
df.with.cut.quant <- df.cut$df.with.cut.quant
df.grp.L1 <- df.cut$df.grp.L1
```

```{r}
# Cut Variables Generated
names(vars.quantile.cut)
summary(vars.quantile.cut)
```

```{r}
# options(repr.matrix.max.rows=50, repr.matrix.max.cols=20)
# df.with.cut.quant
```

##### Individual Variables' Quantile Cuts Review Results

```{r}
# Group By Results
f.count <- function(df, var.cts, seq.quantiles) {
    df %>% select(S.country, indi.id, 
                  svymthRound, matches(paste0(var.cts, collapse='|'))) %>%
        group_by(!!sym(f_var_rename(paste0(var.cts,'_q'), seq.quantiles))) %>%
        summarise_all(funs(n=n()))
}
```

```{r}
# Full Panel Results
lapply(vars.cts2quantile, f.count, 
       df=df.with.cut.quant, seq.quantiles=seq.quantiles)
```

```{r}
# Results Individual Slice
lapply(vars.cts2quantile, f.count,
       df=(df.with.cut.quant %>% 
             group_by(!!!syms(vars.group_by)) %>% 
             arrange(!!!syms(vars.arrange)) %>% slice(1L)),
       seq.quantiles = seq.quantiles)
```

#### Differential Quantiles for Different Variables Then Combine to Form New Groups

Collect together different quantile base variables and their percentile cuttings quantile rules. Input Parameters.

```{r}
# Generate Categorical Variables of Quantiles
vars.group_by <- c('indi.id')
vars.arrange <- c('indi.id', 'svymthRound')
```

```{r}
# Quantile Variables and Quantiles
vars.cts2quantile.wealth <- c('wealthIdx')
seq.quantiles.wealth <- c(0, .5, 1.0)
vars.cts2quantile.wgthgt <- c('hgt0', 'wgt0')
seq.quantiles.wgthgt <- c(0, .3333, 0.6666, 1.0)
drop.any.quantile.na <- TRUE
# collect to list
list.cts2quantile <- list(list(vars=vars.cts2quantile.wealth,
                               prob=seq.quantiles.wealth),
                          list(vars=vars.cts2quantile.wgthgt,
                               prob=seq.quantiles.wgthgt))
```

#### Check if Within Group Variables Are The Same

Need to make sure quantile variables are unique within groups

```{r}
vars.cts2quantile <- unlist(lapply(list.cts2quantile, function(elist) elist$vars))
f_check_distinct_ingroup(df, vars.group_by, vars.values_in_group=vars.cts2quantile)
```

##### Keep only non-NA for all Quantile Variables

```{r}
# Original dimensions
dim(df)
# All Continuous Variables from lists
vars.cts2quantile <- unlist(lapply(list.cts2quantile, function(elist) elist$vars))
vars.cts2quantile
# Keep only if not NA for all Quantile variables
if (drop.any.quantile.na) {
    df.select <- df %>% drop_na(c(vars.group_by, vars.arrange, vars.cts2quantile))
}
dim(df.select)
```

##### Apply Quantiles for Each Quantile Variable

```{r}
# Dealing with a list of quantile variables
df.cut.wealth <- df_cut_by_sliced_quantiles(
  df.select, vars.cts2quantile.wealth, seq.quantiles.wealth, vars.group_by, vars.arrange)
summary(df.cut.wealth$vars.quantile.cut)
# summary((df.cut.wealth$df.with.cut.quant)[['wealthIdx_Qs0e1n2']])
# df.cut.wealth$df.with.cut.quant %>% filter(is.na(wealthIdx_Qs0e1n2))
# df.cut.wealth$df.with.cut.quant %>% filter(indi.id == 500)
```

```{r}
df.cut.wgthgt <- df_cut_by_sliced_quantiles(
  df.select, vars.cts2quantile.wgthgt, seq.quantiles.wgthgt, vars.group_by, vars.arrange)
summary(df.cut.wgthgt$vars.quantile.cut)
```

##### Apply Quantiles Functionally

```{r}
# Function to handle list inputs with different quantiles vars and probabilities
df_cut_by_sliced_quantiles_grps <- 
  function(quantile.grp.list, df, vars.group_by, vars.arrange) {
    vars.cts2quantile <- quantile.grp.list$vars
    seq.quantiles <- quantile.grp.list$prob
    return(df_cut_by_sliced_quantiles(
      df, vars.cts2quantile, seq.quantiles, vars.group_by, vars.arrange))
}
```

```{r}
# Apply function
df.cut.list <- lapply(
  list.cts2quantile, df_cut_by_sliced_quantiles_grps,
  df=df.select, vars.group_by=vars.group_by, vars.arrange=vars.arrange)
```

```{r}
# Reduce Resulting Matrixes Together
df.with.cut.quant.all <- lapply(
  df.cut.list, function(elist) elist$df.with.cut.quant) %>% reduce(left_join)
dim(df.with.cut.quant.all)
```

```{r}
# Obrain Newly Created Quantile Group Variables
vars.quantile.cut.all <- unlist(
  lapply(df.cut.list, function(elist) names(elist$vars.quantile.cut)))
vars.quantile.cut.all
```

##### Summarize by Groups

Summarize by all groups.

```{r}
summary(df.with.cut.quant.all %>% select(one_of(vars.quantile.cut.all)))
```

```{r}
# df.with.cut.quant.all %>%
#     group_by(!!!syms(vars.quantile.cut.all)) %>%
#     summarise_at(vars.cts2quantile, funs(mean, n()))
```

##### Generate Joint Quantile Vars Unique Groups

```{r}
# Generate Joint Quantile Index Variable
var.qjnt.grp.idx <- 'group.index'
df.with.cut.quant.all <- df.with.cut.quant.all %>% 
  mutate(!!var.qjnt.grp.idx := group_indices(., !!!syms(vars.quantile.cut.all)))
```

```{r}
arr.group.idx <- t(sort(unique(df.with.cut.quant.all[[var.qjnt.grp.idx]])))
arr.group.idx
```

```{r}
head(df.with.cut.quant.all %>% 
  group_by(!!!syms(vars.quantile.cut.all), !!sym(var.qjnt.grp.idx)) %>%
  summarise_at(vars.cts2quantile, funs(mean, n())), 10) %>% 
  kable() %>% kable_styling_fc_wide()
```

```{r}
head(df.with.cut.quant.all %>% 
  group_by(!!!syms(vars.group_by)) %>% 
  arrange(!!!syms(vars.arrange)) %>% slice(1L) %>%
  group_by(!!!syms(vars.quantile.cut.all), !!sym(var.qjnt.grp.idx)) %>%
  summarise_at(vars.cts2quantile, funs(mean, n())), 10) %>% 
  kable() %>% kable_styling_fc_wide()
```

##### Change values Based on Index

Index from 1 to 18, change input values based on index

```{r}
# arr.group.idx.subsidy <- arr.group.idx*2 - ((arr.group.idx)^2)*0.01
arr.group.idx.subsidy <- arr.group.idx*2
head(df.with.cut.quant.all %>%
        mutate(more_prot = prot + arr.group.idx.subsidy[!!sym(var.qjnt.grp.idx)]) %>%
        group_by(!!!syms(vars.quantile.cut.all), !!sym(var.qjnt.grp.idx))  %>%
        summarise_at(c('more_prot', 'prot'), funs(mean(., na.rm=TRUE))), 10) %>% 
  kable() %>% kable_styling_fc_wide()
```
