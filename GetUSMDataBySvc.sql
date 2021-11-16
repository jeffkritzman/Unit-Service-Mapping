USE FinBI
GO
DROP PROCEDURE adt.GetUSMDataBySvc
GO
/****** Object:  StoredProcedure [adt].[GetUSMData]    Script Date: 2/8/2016 12:07:14 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE PROCEDURE adt.GetUSMDataBySvc

AS

	SET NOCOUNT ON;

	--get hourly summed census for each service
	DROP TABLE IF EXISTS #hourlySvc
	SELECT
		usm.ServiceCode, hourly.enddttm
		, SUM(hourly.census) AS summed_hourly_census
	INTO #hourlySvc
	FROM adt.usm usm --granularity = dept + svc, has high level stats
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
	GROUP BY usm.ServiceCode, hourly.enddttm
	ORDER BY usm.ServiceCode, hourly.enddttm

	--for each service, find the maximum hourly census for each week
	DROP TABLE IF EXISTS #weeklySvc
	SELECT
		hourly.ServiceCode, dt.DATE_WEEK_BEGIN_DATE
		, MAX(hourly.summed_hourly_census) AS max_weekly_census
	INTO #weeklySvc
	FROM #hourlySvc hourly --granularity = hour + service
	JOIN HEDIReporting..DIM_DATE dt 
		ON dt.DATE_CALENDAR_DATE = DATEFROMPARTS(YEAR(hourly.enddttm), MONTH(hourly.enddttm), DAY(hourly.enddttm))
	WHERE 1=1 
	GROUP BY hourly.ServiceCode, dt.DATE_WEEK_BEGIN_DATE
	ORDER BY hourly.ServiceCode, dt.DATE_WEEK_BEGIN_DATE

	--for each service, take the average of the weekly maximum hourly census - use this as the patient demand to be a little conservative, but not overly so
	SELECT main.ServiceCode, AVG(main.max_weekly_census) AS demand
	FROM #weeklySvc main --granularity = week + service
	GROUP BY main.ServiceCode
	ORDER BY 2, main.ServiceCode


