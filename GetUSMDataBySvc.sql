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

	DROP TABLE IF EXISTS #weeklySvc
	SELECT
		usm.ServiceCode, MAX(hourly.census) AS max_weekly_census
		, dt.DATE_WEEK_BEGIN_DATE
	INTO #weeklySvc
	FROM adt.usm usm
	JOIN FinBI.adt.UnitServiceMapCoreByHour hourly
		ON hourly.serviceCode = usm.ServiceCode
	JOIN HEDIReporting..DIM_DATE dt
		ON dt.DATE_CALENDAR_DATE = DATEFROMPARTS(YEAR(enddttm), MONTH(enddttm), DAY(enddttm))
	WHERE 1=1 
		AND usm.DEPARTMENT_ID IS NOT null 
		AND usm.ServiceCode IS NOT NULL
		AND usm.CareArea IS NOT NULL
		AND usm.CareAreaSpecialty IS NOT NULL
		AND usm.AvgDailyCensus IS NOT NULL
		AND usm.AvgDailyCensus > 0
	GROUP BY usm.ServiceCode, dt.DATE_WEEK_BEGIN_DATE
	ORDER BY usm.ServiceCode, dt.DATE_WEEK_BEGIN_DATE

	SELECT main.ServiceCode, AVG(main.max_weekly_census) AS demand
	FROM #weeklySvc main
	GROUP BY main.ServiceCode


