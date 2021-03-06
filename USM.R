################################################################################
#
# Script to determine optimal service / unit assignments
#
################################################################################

##### connect to libraries #####################################################

library(DBI)
library(dplyr)
library(dbplyr)
library(lpSolve)




##### set parameters ###########################################################

penalty <- 1000 #penalty weight
conservativeness.factor <- .9 # how conservative should we be? 1 = very, 0 = not at all
silence.helpers <- 1 # 1 = silent, 0 = not silent (i.e. with debugging calculations)




##### connect to SQL, pull data ################################################

# set up SQL connection to dwSQL > FinBI
finBI <- dbConnect(odbc::odbc(), "finBI", timeout = 10)

# pull all relevant departments - historical capacity info (staffed beds)
helper.depts <- dbGetQuery(finBI, "EXEC adt.GetUSMDataByDept")
helper.numDepts <- nrow(helper.depts)
if (silence.helpers==0) {sum(helper.depts$capacity)}

# pull all relevant services - historical demand info (avg of max weekly census)
helper.svcs <- dbGetQuery(finBI, "EXEC adt.GetUSMDataBySvc")
helper.svcs$trueDemand <- helper.svcs$demand
helper.svcs$demand <- helper.svcs$demand * conservativeness.factor
helper.numSvcs <- nrow(helper.svcs)
if (silence.helpers==0) {sum(helper.svcs$trueDemand)}
if (silence.helpers==0) {sum(helper.svcs$demand)}

# pull all relevant svc dept combos - calculate score (i.e. how desirable the combo is)
helper.combos <- dbGetQuery(finBI, "EXEC adt.GetUSMDataDeptSvcCombos") 
helper.numCombos <- nrow(helper.combos) #number of relevant svc dept combos




##### set up objective function ################################################

# set up objective function coefficients 
obj.pt1.init <- helper.combos['score'] 
#typeof(obj.pt1.init)
#score of each combination - want to minimize overall score
obj.pt1 <- obj.pt1.init[ , 'score'] 
# penalty for using each combo.
# idea is that we want as few combinations as possible while still meeting demand and minimizing score.
obj.pt2 <- as.vector(rep(penalty, helper.numCombos)) 
obj.coeff <- c(obj.pt1, obj.pt2)
if (silence.helpers==0) {obj.coeff}

# set up objective function indicator vector, showing whether a combo is used
# i.e. which indexes are for variables that should be binary
obj.indicator <- 
  c(as.integer(helper.numCombos+1):as.integer(helper.numCombos*2))
if (silence.helpers==0) {obj.indicator}



##### set up constraint matrix #################################################

# Note on index notation: row, column

# construct part 1, summing over all services for each department, one at a time
con.pt1a <- matrix(0, helper.numDepts, helper.numCombos)
if (silence.helpers==0) {con.pt1a[1:10, 1:10]} #check your work!
for (x in 1:helper.numDepts) {
  for (y in 1:helper.numCombos) {
    if (helper.depts[x, "DEPARTMENT_ID"] == helper.combos[y, "DEPARTMENT_ID"]) {
      con.pt1a[x, y] <- 1
    }
  }
}
if (silence.helpers==0) {con.pt1a[1:10, 1:20]}
con.pt1b <- matrix(0, helper.numDepts, helper.numCombos) #0s for penalty vars
con.pt1 <- cbind(con.pt1a, con.pt1b)
#check your work
if (silence.helpers==0) {con.pt1[1:10, 1:20]}
if (silence.helpers==0) {sum(con.pt1a)}
if (silence.helpers==0) {sum(con.pt1b)}
if (silence.helpers==0) {sum(con.pt1)}

# construct part 2, summing over all departments for each service, one at a time
con.pt2a <- matrix(0, helper.numSvcs, helper.numCombos)
for (x in 1:helper.numSvcs) {
  for (y in 1:helper.numCombos) {
    if (helper.svcs[x, 'ServiceCode'] == helper.combos[y, 'ServiceCode']) {
      con.pt2a[x, y] <- 1
    }
  }
}
if (silence.helpers==0) {con.pt2a[1:10, 1:20]}
con.pt2b <- matrix(0, helper.numSvcs, helper.numCombos) #0s for penalty vars
con.pt2 <- cbind(con.pt2a, con.pt2b)
#check your work
if (silence.helpers==0) {con.pt2[1:10, 1:20]}
if (silence.helpers==0) {sum(con.pt2a)}
if (silence.helpers==0) {sum(con.pt2b)}
if (silence.helpers==0) {sum(con.pt2)}

# construct part 3, double diagonal matrix for relating 'score' and 'penalty'
con.pt3a <- diag(helper.numCombos) * -1 
con.pt3b <- diag(helper.numCombos) * penalty
con.pt3 <- cbind(con.pt3a, con.pt3b) 
#check your work
if (silence.helpers==0) {con.pt3[1:4, 1:4] }
if (silence.helpers==0) {
  con.pt3[1:4, as.integer(helper.numCombos):as.integer(helper.numCombos+4)]}
if (silence.helpers==0) {sum(con.pt3a)}
if (silence.helpers==0) {sum(con.pt3b)}
if (silence.helpers==0) {sum(con.pt3)}

# pull it all together
con.full <- rbind(con.pt1, con.pt2, con.pt3)

#check your work
if (silence.helpers==0) {con.full[1:10, 1:20]}
if (silence.helpers==0) {
  con.full[as.integer(helper.numDepts):as.integer(helper.numDepts+10), 1:20]}
helper.index1 <- helper.numDepts + helper.numSvcs
if (silence.helpers==0) {
  con.full[as.integer(helper.index1):as.integer(helper.index1+10), 1:20]}
if (silence.helpers==0) {
  con.full[as.integer(helper.index1):as.integer(helper.index1+10),
           as.integer(helper.numCombos):as.integer(helper.numCombos+10)]}
if (silence.helpers==0) {sum(con.pt1)}
if (silence.helpers==0) {sum(con.pt2)}
if (silence.helpers==0) {sum(con.pt3)}
if (silence.helpers==0) {sum(con.full)} # should be equal to (1000 * numCombos) + numCombos




##### set up 'right hand side' ('RHS') #########################################

# get actual data for RHS
rhs.deptCap <- helper.depts[ , 'capacity']
rhs.svcDemand <- helper.svcs[ , 'demand']

# set up rest of RHS
rhs.zeros <- rep(0, helper.numCombos)
rhs.combined <- c(rhs.deptCap, rhs.svcDemand, rhs.zeros)
if (silence.helpers==0) {rhs.combined}



##### set up inequality vector #################################################

dir.pt1 <- rep("<=", helper.numDepts) # no more than capacity
dir.pt2 <- rep(">=", helper.numSvcs)  # no less than demand
dir.pt3 <- rep(">=", helper.numCombos) # enforce penalty
dir.combined <- c(dir.pt1, dir.pt2, dir.pt3)
if (silence.helpers==0) {dir.combined}




##### run MIP ##################################################################

MIP <- lp("min", obj.coeff, con.full, dir.combined, rhs.combined
          , binary.vec = obj.indicator)

MIP # Final value (z) or 'score'
MIP.soln <- MIP$solution
if (silence.helpers==0) {MIP.soln[1:20]}
if (silence.helpers==0) {
  MIP.soln[as.integer(helper.numCombos+1):as.integer(helper.numCombos*2)]}




##### combine into final matrix ################################################

# append solution to svc-unit combinations
final.matrix.pt2c <- helper.combos #called pt2c because of order for sql table
final.matrix.pt2c$solution <- MIP.soln[1:as.integer(helper.numCombos)]

# run group 1 & 2 
# building out functionality in case we need to split out by care area, ICU, etc
final.matrix.pt2a <- matrix("n/a", as.integer(helper.numCombos), 1)
final.matrix.pt2b <- matrix("n/a", as.integer(helper.numCombos), 1)

final.matrix.pt2 <- as.data.frame(final.matrix.pt2a)
colnames(final.matrix.pt2)[1] <- "run_group_1"
final.matrix.pt2$run_group_2 <- final.matrix.pt2b
final.matrix.pt2 <- cbind(final.matrix.pt2, final.matrix.pt2c)

# get run time
run.time <- Sys.time()
run.time <- as.character(run.time)
final.matrix.pt1 <- matrix(run.time, as.integer(helper.numCombos), 1)
colnames(final.matrix.pt1)[1] <- "run_time"

# combine
final.matrix <- as.data.frame(cbind(final.matrix.pt1, final.matrix.pt2))




##### write to SQL #############################################################

# truncate previous staging data
dbGetQuery(finBI, "TRUNCATE TABLE adt.USM_MIP_staging")

# copy data frame to staging table
copy_to(dest = finBI, df = final.matrix
        , name = in_schema("adt", "USM_MIP_staging")
        , overwrite = TRUE
        , temporary = FALSE)

# process data
dbGetQuery(finBI, "EXEC adt.ProcessUsmMIP")


