# Unit-Service-Mapping
Implemented MIP to optimally map physician teams to hospital units

Run R script, which calls the SQL Stored Procedures

Idea: physician teams are currently spread all over the hospital. They spend too much time walking! Plus, they can't attend daily huddles on all of their patients. We'd like to assign each physician team to fewer hospital units. To this purpose, I formulated and implemented a Mixed Integer Program (MIP) to give an optimal mapping.

MIP in English: 

Different physician team work better in different hospital units. Each combination can be given a score (denote as score(team, unit) ). Here, low is good and high is bad. I.e. Burn patient in Burn Unit = score of 1. Burn patient in Pysch Unit = score of 5. 

Also, there is a 'use penalty' (denote as penalty) for each combination of physician team and hospital unit. We have to open combinations but would like to use as few as possible.

In terms of constraints, we can't assign more patient demand to a unit than it can handle. Conversely, all of the patient demand for each team must be assigned to some unit.

Denote the patient demand for a physician team as demand(team). Denote the capacity of a unit as capacity(unit).

Decision Variables: Denote the MIP policy's recommendation for assigning demand to a unit as POLICY(team, unit). Denote whether a unit-team combo is used as USE(team, unit) - this is binary.

MIP formulation:

Minimize
 - SUM (over teams and units) \[ (score(team, unit) * POLICY(team, unit)) + (USE(team, unit) * penalty) \]

Such that
 - SUM (over teams) \[POLICY(team, unit)\] <= capacity(unit), for all units
 - SUM (over units) \[POLICY(team, unit)\] >= , for all teams
 - (penalty * USE(team, unit)) - POLICY(team, unit) >= 0, for all teams and units
 - USE(team, unit) IN {0,1}, for all teams and units

Decision Variables:
 - POLICY(team, unit): the MIP policy's recommendation of how much of a team's demand to assign to a unit
 - USE(team, unit): whether a unit-team combo is used - this is binary

Derived Variables:
 - score(team, unit): how well a team and unit work together - low is good and high is bad
 - penalty: a high number to discourage unnecessary combinations 
 - capacity(unit): capacity of a unit
 - demand(team): patient demand of a team
