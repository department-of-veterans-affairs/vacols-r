source("R/vacolsConnect.R")

library(dplyr)
library(magrittr)
library(tidyr)
library(ggplot2)
library(scales)

con <- vacolsConnect()
query <- function (query) { return(dbGetQuery(con, query)) }


remands <- query("
select
  BFKEY,
  BFMPRO,
  TINUM,
  BFD19,
  (case when VACOLS.AOD_CNT(BFKEY) > 0 then 1 else 0 end) as AOD,
  ENTER_REM,
  EXIT_REM,
  CLOSE_REM

from BRIEFF

inner join FOLDER on BFKEY = TICKNUM

inner join (
  select LOCKEY,
    min(LOCDOUT) as ENTER_REM

  from PRIORLOC

  where LOCSTTO in ('50', '51', '54', '98')

  group by LOCKEY
) ENTER on BFKEY = ENTER.LOCKEY

left join (
  select LOCKEY,
    max(LOCDOUT) as EXIT_REM

  from PRIORLOC

  where LOCSTTO = '96'

  group by LOCKEY
) EXIT on BFKEY = EXIT.LOCKEY

left join (
  select LOCKEY,
    max(LOCDOUT) as CLOSE_REM

  from PRIORLOC

  where LOCSTTO = '99'

  group by LOCKEY
) CLOSE on BFKEY = CLOSE.LOCKEY and CLOSE_REM >= ENTER_REM

where BFMPRO in ('REM', 'HIS')
  and BFAC in ('1', '3')
  and BFDC in ('1', '3')
  and VACOLS.ISSUE_CNT_REMAND(BFKEY) > 0
  and BFDDEC >= date '2007-05-01'
  and (BFMPRO = 'REM' or CLOSE_REM >= date '2015-05-01' or EXIT_REM >= date '2015-05-01')
")

remands %>%
  mutate(BFD19 = as.Date(BFD19), end_date = as.Date(pmin(CLOSE_REM, EXIT_REM)), returned = !is.na(EXIT_REM)) %>%
  filter(as.Date(ENTER_REM) < as.Date('2017-05-01') & (BFMPRO == 'REM' | end_date >= as.Date('2017-05-01'))) %>%
  ggplot(aes(x = BFD19, fill = returned)) +
  scale_x_date(limits = c(as.Date('2002-05-01'), as.Date('2017-05-31'))) +
  scale_y_continuous(limits = c(0, 600)) +
  geom_histogram(binwidth = 30)

remands %>%
  mutate(BFD19 = as.Date(BFD19), end_date = as.Date(pmin(CLOSE_REM, EXIT_REM)), returned = !is.na(EXIT_REM) & as.Date(EXIT_REM) <= as.Date('2015-05-31')) %>%
  filter(as.Date(ENTER_REM) < as.Date('2015-05-01') & (BFMPRO == 'REM' | end_date >= as.Date('2015-05-01'))) %>%
  ggplot(aes(x = BFD19, fill = returned)) +
  scale_x_date(limits = c(as.Date('2002-05-01'), as.Date('2017-05-31'))) +
  scale_y_continuous(limits = c(0, 600)) +
  geom_histogram(binwidth = 30)

library(lubridate)

dates <- ymd("2015-05-01") + months(0:(12 * 2))

for (start_date in dates) {
  start_date <- as_date(start_date)
  end_date <- as_date(start_date + months(1))
  remands %>%
    mutate(BFD19 = as_date(BFD19), close_date = as_date(pmin(CLOSE_REM, EXIT_REM)), returned = !is.na(EXIT_REM) & as_date(EXIT_REM) < end_date & as_date(EXIT_REM) >= start_date) %>%
    filter(as_date(ENTER_REM) < end_date & (BFMPRO == 'REM' | close_date >= start_date)) %>%
    ggplot(aes(x = BFD19, fill = returned)) +
    scale_x_date(limits = c(as_date('2002-05-01'), as_date('2017-05-31'))) +
    scale_y_continuous(limits = c(0, 600)) +
    geom_histogram(binwidth = 30) +
    ggtitle(paste("Pending Remands -", format(as_date(start_date), '%b %Y'))) +
    labs(x = "Form 9 Date", y = "Number of Pending Remands")
  ggsave(paste0('remands-', format(as_date(start_date), '%Y-%m-%d'), '.png'))
}

remands %>%
    mutate(BFD19 = as_date(BFD19), close_date = as_date(pmin(CLOSE_REM, EXIT_REM)), returned = !is.na(EXIT_REM) & as_date(EXIT_REM) < as_date('2017-05-31') & as_date(EXIT_REM) >= as_date('2017-05-01')) %>%
    filter(as_date(ENTER_REM) < as_date('2017-05-31') & (BFMPRO == 'REM' | close_date >= as_date('2017-05-01'))) %>%
    ggplot(aes(x = BFD19, y = as_date(ENTER_REM), color = returned, alpha = returned)) +
    scale_alpha_manual(values = c(0.025, 0.25)) +
    scale_x_date(limits = c(as_date('2002-05-01'), as_date('2017-05-31'))) +
    geom_point() +
    geom_rug()

remands %>%
    mutate(BFD19 = as_date(BFD19), close_date = as_date(pmin(CLOSE_REM, EXIT_REM)), returned = !is.na(EXIT_REM) & as_date(EXIT_REM) < as_date('2017-05-31') & as_date(EXIT_REM) >= as_date('2017-05-01')) %>%
    filter(as_date(ENTER_REM) < as_date('2017-05-31') & (BFMPRO == 'REM' | close_date >= as_date('2017-05-01'))) %>%
    ggplot(aes(x = as_date(ENTER_REM), fill = returned)) +
    scale_y_continuous(limits = c(0, 600)) +
    geom_histogram(binwidth = 30)


assignments <- query("
select
  BFKEY,
  TINUM,
  BFD19,
  DEASSIGN,
  (case when VACOLS.AOD_CNT(BFKEY) > 0 then 1 else 0 end) as AOD,
  (case when BFHR in ('1', '2') then 1 else 0 end) as HEARING,
  (case when BFSSOC1 is not null then 1 else 0 end) as SSOC,
  BFSO

from BRIEFF

inner join FOLDER on BFKEY = TICKNUM

inner join (
  select
    min(DEASSIGN) as DEASSIGN,
    DEFOLDER
  from DECASS
  group by DEFOLDER
) on BFKEY = DEFOLDER

where BFAC = '1'
  and DEASSIGN >= date '2013-10-01'
") %>% mutate(
  AOD = as.logical(AOD),
  HEARING = as.logical(HEARING),
  SSOC = as.logical(SSOC),
  am_legion = BFSO == 'A',
  DEASSIGN = as.Date(DEASSIGN),
  BFD19 = as.Date(BFD19),
  age_at_pickup = as.numeric(DEASSIGN - BFD19)
)

ggplot(assignments, aes(x = DEASSIGN, y = age_at_pickup, color = AOD)) +
  scale_y_continuous(limits = c(0, 3500)) +
  geom_point(alpha = 0.02) +
  guides(color = guide_legend(override.aes = list(alpha = 1)))

ggsave('docket-aod.png', width = 8, height = 8)

ggplot(assignments, aes(x = DEASSIGN, y = age_at_pickup, color = HEARING)) +
  scale_y_continuous(limits = c(0, 3500)) +
  geom_point(alpha = 0.02) +
  guides(color = guide_legend(override.aes = list(alpha = 1)))

ggsave('docket-hearing.png', width = 8, height = 8)

ggplot(assignments, aes(x = DEASSIGN, y = age_at_pickup, color = SSOC)) +
  scale_y_continuous(limits = c(0, 3500)) +
  geom_point(alpha = 0.02) +
  guides(color = guide_legend(override.aes = list(alpha = 1)))

ggsave('docket-ssoc.png', width = 8, height = 8)

ggplot(assignments, aes(x = DEASSIGN, y = age_at_pickup, color = am_legion)) +
  scale_y_continuous(limits = c(0, 3500)) +
  geom_point(alpha = 0.02) +
  guides(color = guide_legend(override.aes = list(alpha = 1)))

ggsave('docket-american-legion.png', width = 8, height = 8)

ggplot(assignments, aes(x = DEASSIGN, y = BFD19, color = AOD)) +
  scale_y_date(limits = c(as.Date('2009-04-01'), as.Date('2017-04-17'))) +
  geom_point(alpha = 0.02) +
  guides(color = guide_legend(override.aes = list(alpha = 1)))

ggsave('docket-abs.png', width = 8, height = 8)

assignments.incl_postrem <- query("
select
  BFKEY,
  TINUM,
  BFD19,
  DEASSIGN,
  (case when VACOLS.AOD_CNT(BFKEY) > 0 then 1 else 0 end) as AOD,
  (case when BFHR in ('1', '2') then 1 else 0 end) as HEARING,
  (case when BFSSOC1 is not null then 1 else 0 end) as SSOC,
  BFSO,
  BFAC

from BRIEFF

inner join FOLDER on BFKEY = TICKNUM

inner join (
  select
    min(DEASSIGN) as DEASSIGN,
    DEFOLDER
  from DECASS
  group by DEFOLDER
) on BFKEY = DEFOLDER

where BFAC in ('1', '3')
  and DEASSIGN >= date '2014-06-01'
  and DEASSIGN < date '2017-06-01'
") %>% mutate(
  AOD = as.logical(AOD),
  HEARING = as.logical(HEARING),
  SSOC = as.logical(SSOC),
  am_legion = BFSO == 'A',
  post_rem = BFAC == '3',
  type = factor(ifelse(post_rem, "postrem", ifelse(AOD, "orig_aod", "orig_nonaod")), levels = c('orig_nonaod', 'orig_aod', 'postrem')),
  DEASSIGN = as.Date(DEASSIGN),
  BFD19 = as.Date(BFD19),
  age_at_pickup = as.numeric(DEASSIGN - BFD19),
  orig_aod = type == "orig_aod"
)

ggplot(assignments.incl_postrem, aes(x = DEASSIGN, y = age_at_pickup, color = type)) +
  scale_y_continuous(limits = c(0, 3500)) +
  geom_point(alpha = 0.04) +
  guides(color = guide_legend(override.aes = list(alpha = 1)))

ggsave('docket-postrem.png', width = 8, height = 8)

ggplot(assignments.incl_postrem, aes(x = DEASSIGN, y = BFD19, color = type)) +
  scale_y_date(limits = c(as.Date('2009-04-01'), as.Date('2017-05-31'))) +
  geom_point(alpha = 0.04) +
  guides(color = guide_legend(override.aes = list(alpha = 1)))

ggsave('docket-postrem-abs.png', width = 8, height = 8)


assignments.by_month <- assignments.incl_postrem %>%
  mutate(
    month = as.Date(paste0(substr(DEASSIGN, 1, 7), "-01"))
  ) %>%
  group_by(month) %>%
  summarise(
    postrem = sum(post_rem),
    orig_aod = sum(AOD & !post_rem),
    orig_nonaod = sum(!AOD & !post_rem),
    total = n()
  ) %>%
  gather(type, cnt, -month, -total) %>%
  mutate(type = factor(type, levels = rev(c('orig_nonaod', 'orig_aod', 'postrem')), ordered = TRUE))

dva_theme <- theme_light() +
  theme(
    panel.border = element_blank(),
    text = element_text(family = "Source Sans Pro"),
    axis.title = element_blank(),
    strip.background = element_blank(),
    strip.text = element_text(color = "black")
  )

ggplot(assignments.by_month, aes(x = month, y = cnt / total, fill = type)) +
  geom_area() +
  scale_y_continuous(labels = percent) +
  scale_fill_manual(values = rev(c("#0F2D52", "#256FB2", "#D5D9E0"))) +
  dva_theme

ggsave('docket-breakdown.png', width = 8, height = 8)



library(e1071)

assignments.all <- query("
select
  BFKEY,
  TINUM,
  BFD19,
  DEASSIGN,
  (case when VACOLS.AOD_CNT(BFKEY) > 0 then 1 else 0 end) as AOD,
  (case when BFHR in ('1', '2') then 1 else 0 end) as HEARING,
  (case when BFSSOC1 is not null then 1 else 0 end) as SSOC,
  BFSO,
  BFAC

from BRIEFF

inner join FOLDER on BFKEY = TICKNUM

inner join (
  select
    min(DEASSIGN) as DEASSIGN,
    DEFOLDER
  from DECASS
  group by DEFOLDER
) on BFKEY = DEFOLDER

where BFAC in ('1', '3')
  and DEASSIGN >= date '2014-10-01'
  and DEASSIGN < date '2017-04-17'
") %>% mutate(
  AOD = as.logical(AOD),
  HEARING = as.logical(HEARING),
  SSOC = as.logical(SSOC),
  am_legion = BFSO == 'A',
  post_rem = BFAC == '3',
  type = factor(ifelse(post_rem, "postrem", ifelse(AOD, "orig_aod", "orig_nonaod")), levels = c('orig_nonaod', 'orig_aod', 'postrem')),
  DEASSIGN = as.Date(DEASSIGN),
  BFD19 = as.Date(BFD19),
  age_at_pickup = as.numeric(DEASSIGN - BFD19),
  orig_aod = factor(ifelse(type == "orig_aod", "aod", "other"))
)

ggplot(sample_n(assignments.all, 5000), aes(x = DEASSIGN, y = BFD19, color = orig_aod)) +
  geom_point(alpha = 0.5) +
  guides(color = guide_legend(override.aes = list(alpha = 1)))

assignments.sample <- sample_n(assignments.all[complete.cases(assignments.all),], 25000)

wts <- setNames(c(4, 1), c("aod", "other"))

svm_model <- svm(orig_aod ~ DEASSIGN + BFD19, data = assignments.sample, cost = 10, gamma = 1, class.weights = wts)

summary(svm_model)
plot(svm_model, sample_n(assignments.all, 1000), BFD19 ~ DEASSIGN, grid = 100)

grid <- expand.grid(BFD19 = seq(as.Date('2009-04-01'), as.Date('2017-04-17'), 7), DEASSIGN = seq(as.Date('2014-10-01'), as.Date('2017-04-17'), 7))
grid$class <- predict(svm_model, grid)
grid$class[grid$BFD19 + 180 > grid$DEASSIGN] <- 'aod'

ggplot(assignments.sample, aes(x = DEASSIGN, y = BFD19)) +
  scale_y_date(limits = c(as.Date('2009-04-01'), as.Date('2017-04-17'))) +
  geom_tile(data = grid, aes(fill = class), alpha = 0.2) +
  geom_point(aes(color = orig_aod), alpha = 0.01)

tuning <- tune(svm, orig_aod ~ DEASSIGN + age_at_pickup, data = assignments.sample, kernel="radial", ranges=list(cost=10^(-1:2), gamma=c(.5,1,2)))
tuning


library(kernlab)
svm_model.2 <- ksvm(orig_aod ~ DEASSIGN + BFD19, data = assignments.sample, class.weights = wts)
plot(svm_model.2, data = sample_n(assignments.sample, 1000))

grid <- expand.grid(BFD19 = seq(as.Date('2009-04-01'), as.Date('2017-04-17'), 7), DEASSIGN = seq(as.Date('2014-10-01'), as.Date('2017-04-17'), 7))
grid$class <- predict(svm_model.2, grid)
grid$class[grid$BFD19 + 180 > grid$DEASSIGN] <- 'aod'

ggplot(assignments.sample, aes(x = DEASSIGN, y = BFD19)) +
  scale_y_date(limits = c(as.Date('2009-04-01'), as.Date('2017-04-17'))) +
  geom_tile(data = grid, aes(fill = class), alpha = 0.2) +
  geom_point(aes(color = orig_aod), alpha = 0.01)




ggplot(subset(assignments, !AOD), aes(x = DEASSIGN, y = age_at_pickup, color = HEARING)) +
  scale_y_continuous(limits = c(0, 3500)) +
  geom_point(alpha = 0.01) +
  guides(color = guide_legend(override.aes = list(alpha = 1))) +
  facet_wrap(~HEARING)




