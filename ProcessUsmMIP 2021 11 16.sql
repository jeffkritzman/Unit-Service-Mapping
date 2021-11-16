USE FinBI
GO
DROP PROCEDURE adt.ProcessUsmMIP
GO
/****** Object:  StoredProcedure [adt].[GetUSMData]    Script Date: 2/8/2016 12:07:14 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE PROCEDURE adt.ProcessUsmMIP

AS
	SET NOCOUNT ON;

	--update previous run in instance table
	DECLARE @max_run_date DATE
	SELECT @max_run_date = 
		CAST(MAX(run_time) AS DATE)
		FROM adt.usm_mip_staging
	UPDATE adt.USM_MIP_instances
	SET eff_to = @max_run_date
	WHERE eff_to IS NULL

	--insert new row into instances table
	INSERT INTO adt.USM_MIP_instances --table with run-level information
		(run_time, eff_from, eff_to, notes)
	SELECT MAX(run_time) AS run_time
		, CAST(MAX(run_time) AS DATE) AS eff_from
		, NULL AS eff_to, NULL AS notes
	FROM adt.usm_mip_staging

	--load staging into results
	INSERT INTO adt.usm_mip_results --store info from all runs
		(run_instance, run_group_1, run_group_2, MapID, ServiceCode, DEPARTMENT_ID, score, solution)
	SELECT SCOPE_IDENTITY() AS run_instance
		, run_group_1, run_group_2, MapID, ServiceCode, DEPARTMENT_ID, score, solution
	FROM adt.usm_mip_staging