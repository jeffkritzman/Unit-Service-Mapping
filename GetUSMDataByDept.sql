USE FinBI
GO
DROP PROCEDURE adt.GetUSMDataByDept
GO
/****** Object:  StoredProcedure [adt].[GetUSMData]    Script Date: 2/8/2016 12:07:14 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE PROCEDURE adt.GetUSMDataByDept

AS

	SET NOCOUNT ON;

	select 
		usm.DEPARTMENT_ID
		, COALESCE(MAX(staffedBeds.STAFFED_BEDS), 0) AS capacity	
	FROM adt.usm usm
	LEFT JOIN adt.FACT_STAFFED_BEDS_BY_DEPARTMENT staffedBeds
		ON staffedBeds.DEP_ID = usm.DEPARTMENT_ID
		AND staffedBeds.EFFECTIVE_FROM <= GETDATE()
		AND staffedBeds.EFFECTIVE_THRU > GETDATE()
	WHERE 1=1 
		AND usm.DEPARTMENT_ID IS NOT null 
		AND usm.ServiceCode IS NOT NULL
		AND usm.CareArea IS NOT NULL
		AND usm.CareAreaSpecialty IS NOT NULL
		AND usm.AvgDailyCensus IS NOT NULL
		AND usm.AvgDailyCensus > 0
	GROUP BY usm.DEPARTMENT_ID
	ORDER BY usm.DEPARTMENT_ID



