# Processes Borrow + Save + Capital Investment Model

# Required Packages
# library(tidyverse)
# library(AER)
# library(R.matlab)



#' Merge mat files together
#'
#' Function that merges mat file from matlab to process in R
#'
#' @bl.get.vf ... vf files very large potentially, if false, do not save them
#' @examples
#' ff_dyna_combine_vfds(root = 'C:/Users/fan/ThaiForInfLuuRobFan/',
#'                                 folder = 'matlab/inf_az/_mat/svbr/',
#'                                 subfolder = 'gda_medium1',
#'                                 st.file.prefix.vf = 'vf_az_p_gb_sa',
#'                                 st.file.prefix.ds = 'ds_az_p_gb_sa',
#'                                 ar.it.pm.subset = c(110,112, 116,118,
#'                                                     150,152, 156,158),
#'                                 ar.it.inner.counter = 1:1:9,
#'                                 bl.txt.print = FALSE)
#'

ff_dyna_combine_sbkp <- function(root = 'C:/Users/fan/ThaiForInfLuuRobFan/',
                                 folder = 'matlab/inf_az/_mat/svbr/',
                                 subfolder = 'gda_medium1',
                                 st.file.prefix.vf = 'vf_az_p_gb_sa',
                                 st.file.prefix.ds = 'ds_az_p_gb_sa',
                                 ar.it.pm.subset = c(110,112, 116,118, 150,152, 156,158),
                                 ar.it.inner.counter = 1:1:9,
                                 bl.get.vf = TRUE,
                                 bl.txt.print = FALSE){
    # bl.get.ds
    # options(warn=-1) # Suppress Warning Messages
    # Load in Matlab Mat File from running vf_az

    # root <- 'C:/Users/fan/ThaiForInfLuuRobFan/'
    # folder <- 'matlab/inf_az/_mat/svbr/'
    # subfolder <- 'mat_grid_a_large1'
    # subfolder <- 'gda_medium1'
    # subfolder <- 'gda_small1'
    # st.file.prefix.vf <- 'vf_az_p_gb_sa'
    # st.file.prefix.ds <- 'ds_az_p_gb_sa'

    # ar.it.pm.subset <- c(110,112, 116,118,
    #                      150,152, 156,158)

    # ar.it.inner.counter <- 1:1:9

    # bl.txt.print <- TRUE

    list.ar.it <- list(ar.it.inner.counter, ar.it.pm.subset)
    mt.fl.expanded <- do.call(expand.grid, list.ar.it)

    df.slds <- tibble()
    df.dist.a <- tibble()
    df.dist.k <- tibble()
    df.dist.ak <- tibble()

    for (i in 1:dim(mt.fl.expanded)[1]) {

      # Counters
      it.inner.counter <- mt.fl.expanded[i, 1]
      it.pm.subset <- mt.fl.expanded[i, 2]

      print(paste0('COMBINING: i ', i, ' of ', dim(mt.fl.expanded)[1], ' simulated simulated set'))
      print(paste0('it.pm.subset=', it.pm.subset, ', it.inner.counter=', it.inner.counter))

      # Folder Names and Load .mat
      curfolder <- paste0(folder, subfolder, '/pm', it.pm.subset, '/')
      if (bl.get.vf) {
        st.vf.matfile <-
          paste0(st.file.prefix.vf,
                 it.pm.subset,
                 '_c',
                 it.inner.counter,
                 '.mat')
        vf.mat.out <- readMat(paste0(root, curfolder, st.vf.matfile))
      }
      st.ds.matfile <-
        paste0(st.file.prefix.ds,
               it.pm.subset,
               '_c',
               it.inner.counter,
               '.mat')
      ds.mat.out <- readMat(paste0(root, curfolder, st.ds.matfile))

      bl.has.fbis <- FALSE
      if ('mt.for.save' %in% names(ds.mat.out)) {
        bl.has.fbis <- TRUE
      }

      # From Distribution File
      mt.dist <- ds.mat.out$mt.dist.ak.z

      if (bl.get.vf) {
        # From VFI file
        mt.fin <- vf.mat.out$mt.pol.fin
        mt.kap <- vf.mat.out$mt.pol.kap
        mt.idx <- vf.mat.out$mt.pol.idx
        mt.val <- vf.mat.out$mt.val
        mt.con <- vf.mat.out$mt.cons
        mt.inc <- vf.mat.out$mt.incm

        if (bl.has.fbis) {
          mt.for.borr <- floor(vf.mat.out$mt.for.borr)
          mt.for.save <- vf.mat.out$mt.for.save
          mt.inf.borr <- vf.mat.out$mt.inf.borr
          mt.coh.add <- vf.mat.out$mt.coh.add
        }
      }

      # State Vectors
      ar.a <- ds.mat.out$ar.a
      ar.k <- ds.mat.out$ar.k
      ar.z <- ds.mat.out$ar.z

      # LParameters
      it.z.n <- ds.mat.out$it.z.n
      it.a.n <- ds.mat.out$it.a.n
      it.k.n <- ds.mat.out$it.k.n
      fl.sig <- ds.mat.out$fl.sig
      if (bl.get.vf) {
        fl.crra <- vf.mat.out$fl.crra
        fl.rho <- vf.mat.out$fl.rho
      }

      if (bl.has.fbis) {
        # these parameters exist in fibs models only
        fl.r.inf <- ds.mat.out$fl.r.inf
        fl.r.fsv <- ds.mat.out$fl.r.fsv
        fl.r.fbr <- ds.mat.out$fl.r.fbr
        fl.for.br.block <- ds.mat.out$fl.for.br.block
      }

      #######################################
      ### Column Appending Functions
      #######################################
      ff_add_simu_params_as_vars <- function(df) {

        df <- df %>% mutate(
          it.pm.subset = it.pm.subset,
          it.inner.counter = it.inner.counter,
          it.z.n = it.z.n,
          it.a.n = it.a.n,
          fl.crra = fl.crra,
          fl.rho = fl.rho,
          fl.sig = fl.sig)

        if (bl.get.vf) {
          df <- df %>% mutate(
            fl.crra = fl.crra,
            fl.rho = fl.rho)
        }

        if (bl.has.fbis) {
          # these parameters exist in fibs models only
          df <- df %>% mutate(
            fl.r.inf = fl.r.inf,
            fl.r.fsv = fl.r.fsv,
            fl.r.fbr = fl.r.fbr,
            fl.for.br.block = fl.for.br.block)
        }

        return(df)
      }


      #######################################
      ### combine a by z matrixes together
      #######################################
      # Combine to Dataframe Full Matrix
      ar.st.vars <- c('a', 'k', 'z')
      list.ar.fl <- list(ar.a, ar.k, paste0('z=', round(ar.z, 3)))

      list.ts.valpolmat <- tibble(
        val = as.numeric(mt.val),
        aprime = as.numeric(mt.fin),
        kprime = as.numeric(mt.kap),
        con = as.numeric(mt.con),
        inc = as.numeric(mt.inc),
        prob = as.numeric(mt.dist)
      )
      if (bl.has.fbis) {
        list.ts.valpolmat <- tibble(
          val = as.numeric(mt.val),
          aprime = as.numeric(mt.fin),
          kprime = as.numeric(mt.kap),
          con = as.numeric(mt.con),
          inc = as.numeric(mt.inc),
          prob = as.numeric(mt.dist),
          fbr=as.numeric(mt.for.borr),
          fsv=as.numeric(mt.for.save),
          ifb=as.numeric(mt.inf.borr),
          cdd=as.numeric(mt.coh.add),
        )
      }

      # Expand
      df.slds.cur <- ff_dyna_sup_expand_grids(ar.st.vars, list.ar.fl, list.ts.valpolmat)
      # Append more stats
      df.slds.cur <- ff_add_simu_params_as_vars(df.slds.cur)

      #######################################
      ### combine marrginals integrated over z
      #   also integrated over both z and k or both z and b
      #######################################

      ar.st.vars <- c('a')
      list.ar.a.fl <- list(ar.a)
      ar.dist.a <- ds.mat.out$ar.dist.a
      list.ar.prob.a <- tibble(proba = as.numeric(ar.dist.a), probz = 1)
      df.dist.a.cur <-
        ff_dyna_sup_expand_grids(ar.st.vars, list.ar.a.fl, list.ar.prob.a)
      df.dist.a.cur <- ff_add_simu_params_as_vars(df.dist.a.cur)

      ar.st.vars <- c('k')
      list.ar.k.fl <- list(ar.k)
      ar.dist.k <- ds.mat.out$ar.dist.k
      list.ar.prob.k <- tibble(probk = as.numeric(ar.dist.k), probz = 1)
      df.dist.k.cur <-
        ff_dyna_sup_expand_grids(ar.st.vars, list.ar.k.fl, list.ar.prob.k)
      df.dist.k.cur <- ff_add_simu_params_as_vars(df.dist.k.cur)

      ar.st.vars <- c('a', 'k')
      list.ar.ak.fl <- list(ar.a, ar.k)
      ar.dist.ak <- ds.mat.out$ar.dist.ak
      list.ar.prob.ak <-
        tibble(probak = as.numeric(ar.dist.ak), probz = 1)
      df.dist.ak.cur <-
        ff_dyna_sup_expand_grids(ar.st.vars, list.ar.ak.fl, list.ar.prob.ak)
      df.dist.ak.cur <- ff_add_simu_params_as_vars(df.dist.ak.cur)

      # Print if need to
      if (bl.txt.print) {
        print(dim(df.slds.cur))
      }

      # Stack Dataframes together
      df.slds    <- bind_rows(df.slds, df.slds.cur)
      df.dist.a  <- bind_rows(df.dist.a, df.dist.a.cur)
      df.dist.k  <- bind_rows(df.dist.k, df.dist.k.cur)
      df.dist.ak <- bind_rows(df.dist.ak, df.dist.ak.cur)

      if (bl.txt.print) {
        print(dim(df.slds))
        print(dim(df.dist))
      }
    }

    #######################################
    ### Column Appending Functions
    #######################################
    ff_add_simu_joinedparams_as_vars <- function(df) {
      df <- df %>% mutate(it.z.n_str = sprintf("%02d", it.z.n),
                          it.a.n_str = sprintf("%04d", it.a.n)) %>%
        mutate(
          st_pm_zan = paste0(
            'crra=',
            fl.crra,
            ',rho=',
            fl.rho,
            ',sig=',
            fl.sig,
            '\nan=',
            it.a.n_str,
            ',zn=',
            it.z.n_str
          ),
          st_zan = paste0('an=', it.a.n_str,
                          ',zn=', it.z.n_str),
          st_crra_zan = paste0('crra=', fl.crra,
                               '\nan=', it.a.n_str,
                               ',zn=', it.z.n_str),
          st_crrarhosig = paste0('crra=', fl.crra,
                                 ',rho=', fl.rho,
                                 ',sig=', fl.sig),
          rho_sig = paste0('rho=', fl.rho, ',sig=', fl.sig),
          z_n_a_n = paste0('an=', it.a.n_str,
                           ',zn=', it.z.n_str),
          st_it_pm = paste0('pm=', it.pm.subset,
                            ',i=', it.inner.counter)
        )
    }

    # Generate Additional Variables
    df.slds <- df.slds %>% mutate(wealth = inc + a,
                                  bl.borr = if_else(aprime < 0, 1, 0),
                                  bl.none = if_else(aprime == 0, 1, 0),
                                  bl.save = if_else(aprime > 0, 1, 0))
    if (bl.has.fbis) {
      df.slds <- df.slds %>% mutate(wealth = inc + a,
                                    bl.borr = if_else(aprime < 0, 1, 0),
                                    bl.none = if_else(aprime == 0, 1, 0),
                                    bl.save = if_else(aprime > 0, 1, 0),
                                    bl.forborr.forsave = if_else((fbr < 0 & fsv > 0), 1, 0),
                                    bl.infborr.onlyinf = if_else((ifb < 0 & fbr == 0), 1, 0),
                                    bl.forborr.infborr = if_else((ifb < 0 & fbr < 0), 1, 0))

      df.slds <- df.slds %>% mutate(formal.borrowing.amount = fbr,
                                    informal.borrowi.amount = ifb,
                                    forsave.whenForBorr.amt = fsv,
                                    total.net.borr.save.all = a)
    }

    # Add Parameter Categorical Variables
    df.slds <- ff_add_simu_joinedparams_as_vars(df.slds)
    df.dist.a <- ff_add_simu_joinedparams_as_vars(df.dist.a)
    df.dist.k <- ff_add_simu_joinedparams_as_vars(df.dist.k)
    df.dist.ak <- ff_add_simu_joinedparams_as_vars(df.dist.ak)

    # Captioning Texts
    st.caption <-
      paste0(
        paste0(
          folder,
          ';',
          subfolder,
          ';',
          st.file.prefix.vf,
          ';',
          st.file.prefix.ds
        ),
        '\n',
        paste0(
          'ar.it.inner.counter:',
          paste0(ar.it.inner.counter, collapse = '-'),
          ';'
        ),
        paste0('ar.it.pm.subset:', paste0(ar.it.pm.subset, collapse =
                                            '-'))
      )

    #################################################
    ### Main File
    # This is the densest grid result, other results less grid points
    # Dense grid results include multiple crra and shock parameters
    #################################################
    df.slds.main <- df.slds %>% filter(it.inner.counter == 1)
    df.dist.ak.main <- df.dist.ak %>% filter(it.inner.counter == 1)

    #################################################
    ### Main File Results for DIST, additional results for df.dist.main
    #################################################
    vars.group.by <- 'st_crrarhosig'
    # more detailed files for df.dist.main
    st.main.grid <-
      paste0(
        'A grid count = ',
        unique(df.dist.ak.cur$it.a.n),
        ', z grid count = ',
        unique(df.dist.ak.cur$it.z.n)
      )

    # # a readable csv file with aprob across parameters for main-dense, ignore other numbers
    # df.dist.main.aprob <-
    #   df.dist.main %>% select(a, z, proba, one_of(vars.group.by)) %>% spread(a, proba) %>% mutate_if(is.numeric, round, 4)
    #
    # # a simple percentile file checking on discrete proabiliy distribution, does not make sense, but useful.
    # df.dist.main.aprob.dist <-
    #   df.dist.main %>% select(a, proba, vars.group.by) %>% group_by(!!!syms(vars.group.by)) %>%
    #   do(data.frame(f.summ.percentiles(.) %>% mutate_if(is.numeric, round, 4)))

    return(list(df_slds = df.slds,
                df_dist_a = df.dist.a,
                df_dist_k = df.dist.k,
                df_dist_ak = df.dist.ak,
                df_slds_main=df.slds.main, df_dist_ak_main = df.dist.ak.main ,
                st_caption=st.caption, st_main_grid=st.main.grid))

                # df_dist_main_aprob=df.dist.main.aprob, df_dist_main_aprob_dist=df.dist.main.aprob.dist,

}
