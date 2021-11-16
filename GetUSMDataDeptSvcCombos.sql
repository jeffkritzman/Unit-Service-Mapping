USE FinBI
GO
DROP PROCEDURE adt.GetUSMDataDeptSvcCombos
GO
/****** Object:  StoredProcedure [adt].[GetUSMData]    Script Date: 2/8/2016 12:07:14 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE PROCEDURE adt.GetUSMDataDeptSvcCombos

AS

	SET NOCOUNT ON;

	--get summed census for each service-unit combo
	DROP TABLE IF EXISTS #sumUnitSvc
	SELECT
		usm.MapID, usm.ServiceCode, usm.DEPARTMENT_ID
		, SUM(hourly.census) AS summed_census
	INTO #sumUnitSvc
	FROM adt.usm usm --granularity = mapID (i.e. dept + svc), has high level stats
	JOIN FinBI.adt.UnitServiceMapCoreByHour hourly --granularity = hour + dept + svc, good for seeing granular system state
		ON hourly.serviceCode = usm.ServiceCode
		AND hourly.DEPARTMENT_ID = usm.DEPARTMENT_ID
	WHERE 1=1 
		AND usm.DEPARTMENT_ID IS NOT null 
		AND usm.ServiceCode IS NOT NULL
		AND usm.CareArea IS NOT NULL
		AND usm.CareAreaSpecialty IS NOT NULL
		AND usm.AvgDailyCensus IS NOT NULL
		AND usm.AvgDailyCensus > 0
	GROUP BY usm.MapID, usm.ServiceCode, usm.DEPARTMENT_ID
	
	--for each service, find max summed census of any unit-service combo. Want to use this as a scaling factor
	DROP TABLE IF EXISTS #maxBySvc
	SELECT 
		main.ServiceCode
		, MAX(main.summed_census) AS max_summed_census
	INTO #maxBySvc
	FROM #sumUnitSvc main --granularity = mapID (mapID = unique combo of unit + svc)
	GROUP BY main.ServiceCode
		
	select
		main.MapID, main.ServiceCode, main.DEPARTMENT_ID
		, 5 * (1 - 
			(CASE WHEN main.summed_census = 0 THEN -5 --if this combo hasn't been used in 6 months, we really don't want it to be a proposed solution
				WHEN maxBySvc.max_summed_census = 0 THEN -5 --if this combo hasn't been used in 6 months, we really don't want it to be a proposed solution
				ELSE main.summed_census / maxBySvc.max_summed_census --scale by service's most highly used unit
				END))
				AS score --high is bad, low is good	
	FROM #sumUnitSvc main --granularity = mapID (mapID = unique combo of unit + svc)
	JOIN #maxBySvc maxBySvc --granularity = service
		ON maxBySvc.ServiceCode = main.ServiceCode

	--future work: incorporate survey data, weighting survey score vs imputed ADT score based on how many survey responses exists for a svc-unit combo

