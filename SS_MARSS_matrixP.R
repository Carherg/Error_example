#1) Housekeeping 

rm(list = ls())

library(MARSS)
library(lubridate)
library(tidyverse)
library('tseries')
library('dplyr')
library(quantmod)

# 2) Get data from Quantmod and prepare data frame for estimation

getSymbols('GDPC1',src='FRED')
getSymbols('PAYEMS',from = "1947-01-01",src='FRED')
getSymbols('INDPRO',from = "1947-01-01",src='FRED')
getSymbols('RPI',from = "1947-01-01",src='FRED')


GDP <-  data.frame(date=index(GDPC1), coredata(GDPC1))
Emp <-  data.frame(date=index(PAYEMS), coredata(PAYEMS))
Indpr <- data.frame(date=index(INDPRO), coredata(INDPRO))
Inc  <- data.frame(date=index(RPI), coredata(RPI))

Emp <- Emp %>%  filter(date>=as.Date("1947-01-01")&date<=as.Date("2020-06-01"))
Indpr <-Indpr %>% filter(date>=as.Date("1947-01-01")&date<=as.Date("2020-06-01"))
Inc <-Inc %>% filter(date>=as.Date("1947-01-01")&date<=as.Date("2020-06-01"))

names(Inc) <- c("date","Inc")

Inc_aux <- data.frame(seq.Date(as.Date("1947-01-01"), as.Date("1958-12-01") , by = "month"))
Inc_aux$RPI <- NA

names(Inc_aux) <-c("date","Inc")

Inc <- rbind(Inc_aux,Inc)

Emp$PAYEMS <- as.numeric(Emp$PAYEMS)
Emp <- Emp %>% mutate(rate = PAYEMS/lag(PAYEMS,1)-1)

Indpr$INDPRO <- as.numeric(Indpr$INDPRO)
Indpr <- Indpr %>% mutate(rate = INDPRO/lag(INDPRO,1)-1)

Inc$Inc <- as.numeric(Inc$Inc)
Inc <- Inc %>% mutate(rate = Inc/lag(Inc,1)-1)


GDP <- GDP %>% mutate(rate =GDPC1/lag(GDPC1,1)-1)
GDP <- select(GDP, -c(GDPC1))

months <- lapply(X = GDP$date, FUN = seq.Date, by = "month", length.out = 3)
months <- data.frame(date = do.call(what = c, months))

m_GDP <- left_join(x = months, y = GDP , by = "date")

# Data frame for estimation

df <- cbind(m_GDP,Emp$rate,Indpr$rate,Inc$rate)

names(df) <- c("date","S01_GDP","S02_Emp","S03_Indpr","S04_Inc")

# 3) Model 1: one quarterly series and two monthly series

df_marss <- select(df, -c(S04_Inc))

df_marss  <- df_marss %>% gather(key = "serie", value = "value", -date)

df_marss <- df_marss  %>% spread(key=date,value=value)

df_marss$serie <- NULL

df_marss <- as.matrix(df_marss)

df_marss <- zscore(df_marss)


# Matrix Z
# 
Z <- matrix(list("0.33*z1","z2","z3",
                 "0.67*z1",0,0,
                 "z1",0,0,
                 "0.67*z1",0,0,
                 "0.33*z1",0,0,
                 1/3,0,0,
                 2/3,0,0,
                 1,0,0,
                 2/3,0,0,
                 1/3,0,0,
                 0,1,0,
                 0,0,0,
                 0,0,1,
                 0,0,0),3,14)

m <- nrow(Z)
p <- ncol(Z)

# Matrix R

R <- matrix(list(0),m,m)

# Matrix B

B <- matrix (list("b1",1,0,0,0,0,0,0,0,0,0,0,0,0,
                  "b2",0,1,0,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,1,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,0,1,0,0,0,0,0,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,0,0,"b6",1,0,0,0,0,0,0,0,
                  0,0,0,0,0,"b7",0,1,0,0,0,0,0,0,
                  0,0,0,0,0,0,0,0,1,0,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,1,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,0,"b11",1,0,0,
                  0,0,0,0,0,0,0,0,0,0,"b12",0,0,0,
                  0,0,0,0,0,0,0,0,0,0,0,0,"b13",1,
                  0,0,0,0,0,0,0,0,0,0,0,0,"b14",0),14,14)


# Matrix Q

Q <-matrix (list(1,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,"q6",0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,"q11",0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,"q13",0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0),14,14)

Q[1,1]=1


# Other options for matrix Q

# Q <- matrix(list(0),14,14)
# Q <- ldiag(list("q1", 0,0,0,0,"q6",0,0,0,0,"q11",0))

# Q <- "diagonal and unequal"

# Rest of matrices

x0 <-  matrix(0,p,1)
A  <- matrix(0,(length(df)-2),1)
U <- matrix(0,p,1)
V0 <- 5*diag(1,p)
U <-  matrix(0,p,1)


# Estimation

# Define model

model.gen_1 =list(Z=Z,A=A,R=R,B=B,U=U,Q=Q,x0=x0,V0=V0,tinitx=1)

# Estimation

kf_ss_1= MARSS(df_marss, model=model.gen_1,control= list(trace=1,maxit = 300),method="BFGS") #,fun.kf = "MARSSkfss")

summary(kf_ss_1)

# 4) Model 2: one quarterly series and three monthly series

df_marss  <- df%>% gather(key = "serie", value = "value", -date)

df_marss <- df_marss  %>% spread(key=date,value=value)

df_marss$serie <- NULL

df_marss <- as.matrix(df_marss)

#df_marss <- zscore(df_marss,mean.only=TRUE)

# Matrix Z
# 
Z <- matrix(list("0.33*z1","z2","z3","z4",
                 "0.67*z1",0,0,0,
                 "z1",0,0,0,
                 "0.67*z1",0,0,0,
                 "0.33*z1",0,0,0,
                 1/3,0,0,0,
                 2/3,0,0,0,
                 1,0,0,0,
                 2/3,0,0,0,
                 1/3,0,0,0,
                 0,1,0,0,
                 0,0,0,0,
                 0,0,1,0,
                 0,0,0,0,
                 0,0,0,1,
                 0,0,0,0),4,16)

m <- nrow(Z)
p <- ncol(Z)

# Matrix R

R <- matrix(list(0),m,m)

# Matrix B

B <- matrix (list("b1",1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                  "b2",0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,0,0,"b6",1,0,0,0,0,0,0,0,0,0,
                  0,0,0,0,0,"b7",0,1,0,0,0,0,0,0,0,0,
                  0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,0,"b11",1,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,0,"b12",0,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,0,0,0,"b13",1,0,0,
                  0,0,0,0,0,0,0,0,0,0,0,0,"b14",0,0,0,
                  0,0,0,0,0,0,0,0,0,0,0,0,0,0,"b15",1,
                  0,0,0,0,0,0,0,0,0,0,0,0,0,0,"b16",0),16,16)


# Matrix Q

Q <-matrix (list(1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,"q6",0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,"q11",0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,"q13",0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,"q15",0,
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),16,16)

#Q[1,1]=1

# Q <- matrix(list(0),14,14)
# Q <- ldiag(list("q1", 0,0,0,0,"q6",0,0,0,0,"q11",0))

# Q <- "diagonal and unequal"

# Rest of matrices

x0 <-  matrix(0,p,1)
A  <- matrix(0,(length(df)-1),1)
U <- matrix(0,p,1)
V0 <- 5*diag(1,p)
U <-  matrix(0,p,1)

# Estimation

# Define model

model.gen_2 =list(Z=Z,A=A,R=R,B=B,U=U,Q=Q,x0=x0,V0=V0,tinitx=1)

# Estimation

kf_ss_2= MARSS(df_marss, model=model.gen_2,control= list(trace=1,maxit = 300),method="BFGS") #,fun.kf = "MARSSkfss")

summary(kf_ss_2)

# Forecast YT

kff <- forecast.marssMLE(kf_ss_2, h=12)

plot(kff, include=50)

# GDP Forecasat

GDP_hat_T <- as.data.frame(kf_ss_2[["ytT"]])
  
GDP_hat_T   <- select(kff[["pred"]], c(.rownames,estimate))

names(GDP_hat_T) <- c("variable","estimate")

GDP_hat_T <- GDP_hat_T %>% dplyr::filter(variable == "Y1")

GDP_hat_T$date <-(seq.Date(as.Date("1947-01-01"), as.Date("2021-06-01") , by = "month"))

GDP_hat_T_Q  <- GDP_hat_T%>% filter(month(GDP_hat_T$date) %in% c(3,6,9,12))

GDP_mean <- colMeans(subset(GDP, select=-c(date)),  na.rm = TRUE)

GDP_hat_T_Q <- GDP_hat_T_Q %>% mutate (annualized_rate = (estimate +GDP_mean+1)^4-1 )

# Forecast and fitted ytt

kff_tt <- forecast.marssMLE(kf_ss_2, h=12, type="ytt")

kff_fit_tt <- fitted(kf_ss_2, type="ytt")
