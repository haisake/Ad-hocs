/*
Purpose: To compute the overtime and sick time hours for the reporting packages
Author: Hans Aisake
Date Created: 
Date Modified: 
Inclusions/Exclusions:
Comments:
*/ 

	/*reporting periods, based on 1 day lag*/
	IF OBJECT_ID('tempdb.dbo.#st_ot_packages_FP') IS NOT NULL DROP TABLE #st_ot_packages_FP;


	SELECT distinct TOP 39 FiscalPeriodLong, fiscalperiodstartdate, fiscalperiodenddate, FiscalPeriodEndDateID, FiscalPeriod, FiscalYearLong
	INTO #st_ot_packages_FP
	FROM ADTCMart.dim.[Date]
	WHERE fiscalperiodenddate <= DATEADD(day, -1, GETDATE())
	ORDER BY FiscalPeriodEndDate DESC
	;


	/*pull overtime hours from FinanceMart tables by cost center*/
	IF OBJECT_ID('tempdb.dbo.#otHours') is not null DROP TABLE #otHours;


	SELECT productiveHours.EntityDesc
	, productiveHours.ProgramDesc
	, productiveHours.SubProgramDesc
	, productiveHours.CostCenterCode
	, productiveHours.FinSiteID
	, productiveHours.[FiscalYearLong]
	, productiveHours.[FiscalPeriod] 
	, productiveHours.Act_ProdHrs
	, ISNULL(casualHours.Casual_ProdHrs,0) as 'Casual_ProdHrs'
	, ISNULL(otHours.Act_OTHrs,0) as 'Act_OTHrs'
	, productiveHours.Bud_ProdHrs	/*The OT report didn't exclude casual hours*/
	, ISNULL(otHours.Bud_OTHrs,0) as 'Bud_OTHrs'
	INTO #otHours
	FROM
	(	
		SELECT epsp.EntityDesc
		, CASE WHEN epsp.CostCenterBusinessUnitEntitySiteID =6450 THEN 'Volunteers'	/*custom remapping for me as surgery doesn't seam consistently reliable*/
			   ELSE epsp.ProgramDesc
		END as 'ProgramDesc'
		, epsp.SubProgramDesc
		, cc.CostCenterCode
		, epsp.FinSiteID
		, schrs.[FiscalYearLong]
		, schrs.[FiscalPeriod]  
		,Sum([SumCodeHrs]) as 'Act_ProdHrs'   
		,Sum([BudgetHrs]) as 'Bud_ProdHrs'
		FROM [FinanceMart].[dbo].[SumCodeHrsSummary] as schrs
		INNER JOIN [FinanceMart].[Dim].[CostCenter] as cc
		ON schrs.CostCenter = cc.CostCenterCode
		INNER JOIN [FinanceMart].Dim.CostCenterBusinessUnitEntitySite as ccbues
		ON cc.CostCenterID = ccbues.CostCenterID 
		AND schrs.FinSiteID=ccbues.FinSiteID
		INNER JOIN [FinanceMart].[Finance].[EntityProgramSubProgram] as EPSP
		ON ccbues.CostCenterBusinessUnitEntitySiteID = EPSP.CostCenterBusinessUnitEntitySiteID		/*same ccentitysiteid*/
		where sumCodeID <= 199							/*productive hours*/
		and EntityDesc in('Richmond Health Services')		/*focus on these entities*/
		and EntityProgramDesc in ('RH Clinical'	,'RHS HSDA')	/*rileys file had both of these included in the total richmond numbers*/
		and FiscalYearLong >= 2015						/*date cutoff*/
		GROUP BY epsp.EntityDesc
		, CASE WHEN epsp.CostCenterBusinessUnitEntitySiteID =6450 THEN 'Volunteers'	/*custom remapping for me as surgery doesn't seam consistently reliable*/
			   ELSE epsp.ProgramDesc
		END
		, epsp.SubProgramDesc
		, cc.CostCenterCode
		, epsp.FinSiteID
		, schrs.[FiscalYearLong]
		, schrs.[FiscalPeriod]
	) as productiveHours
	LEFT JOIN
	(	SELECT epsp.EntityDesc
		, CASE WHEN epsp.CostCenterBusinessUnitEntitySiteID =6450 THEN 'Volunteers'	/*custom remapping for me as surgery doesn't seam consistently reliable*/
			   ELSE epsp.ProgramDesc
		END as 'ProgramDesc'
		, epsp.SubProgramDesc
		, cc.CostCenterCode
		, epsp.FinSiteID
		, schrs.[FiscalYearLong]
		, schrs.[FiscalPeriod] 
		, Sum([SumCodeHrs]) as 'Act_OTHrs' 
		, Sum([BudgetHrs]) as 'Bud_OTHrs' 
		FROM [FinanceMart].[dbo].[SumCodeHrsSummary] as schrs
		INNER JOIN [FinanceMart].[Dim].[CostCenter] as cc	/*get cost center business unit entity site id*/
		ON schrs.CostCenter = cc.CostCenterCode				/*same cost center*/
		INNER JOIN FinanceMart.Dim.CostCenterBusinessUnitEntitySite as ccbues
		ON cc.CostCenterID = ccbues.CostCenterID			/*same cost center*/
		AND schrs.FinSiteID=ccbues.FinSiteID				/*same financial site*/
		JOIN [FinanceMart].[Finance].[EntityProgramSubProgram] as EPSP
		ON ccbues.CostCenterBusinessUnitEntitySiteID = EPSP.CostCenterBusinessUnitEntitySiteID
		WHERE sumCodeID = 104									/*overtime hours*/
		and EntityDesc in('Richmond Health Services')			/*focus on these entities*/
		and EntityProgramDesc in ('RH Clinical'	,'RHS HSDA')	/*rileys file had both of these included in the total richmond numbers*/
		AND FiscalYearLong >= 2015								/*date cutoff*/
		GROUP BY epsp.EntityDesc
		, CASE WHEN epsp.CostCenterBusinessUnitEntitySiteID =6450 THEN 'Volunteers'	/*custom remapping for me as surgery doesn't seam consistently reliable*/
			   ELSE epsp.ProgramDesc
		END
		, epsp.SubProgramDesc
		, cc.CostCenterCode
		, epsp.FinSiteID
		, schrs.[FiscalYearLong]
		, schrs.[FiscalPeriod]
	) as otHours
	ON  productiveHours.EntityDesc = otHours.EntityDesc				/*same entity*/
	AND productiveHours.ProgramDesc = otHours.ProgramDesc			/*same program*/
	AND productiveHours.SubProgramDesc = otHours.SubProgramDesc		/*same sub program*/
	AND productiveHours.CostCenterCode = otHours.CostCenterCode		/*same cost center*/
	AND productiveHours.FinSiteID = otHours.FinsiteID				/*same fine site*/
	AND productiveHours.[FiscalYearLong] = otHours.[FiscalYearLong]	/*same fiscal year*/
	AND productiveHours.[FiscalPeriod] = otHours.[FiscalPeriod]		/*same fiscal period*/
	LEFT JOIN
	(	SELECT epsp.EntityDesc
		, CASE WHEN epsp.CostCenterBusinessUnitEntitySiteID =6450 THEN 'Volunteers'	/*custom remapping for me as surgery doesn't seam consistently reliable*/
			   ELSE epsp.ProgramDesc
		END as 'ProgramDesc'
		, epsp.SubProgramDesc
		, cas.[Dept#] as 'CostCenterCode'
		, cas.[Site] as 'FinSiteID'
		, cas.[YEAR] as 'FiscalYearLong'
		, cas.[period] as 'FiscalPeriod'
		, SUM(cas.[Hour Prod]) as 'Casual_ProdHrs'
		, SUM(cas.[SickHrs]) as 'Casual_SickHrs'
		, SUM(cas.[OTHrs]) as 'Casual_OTHrs'
		FROM FinanceMart.[Finance].[vwCasualHrsFact] as cas
		LEFT JOIN FinanceMArt.Finance.EntityProgramSubProgram as epsp
		ON cas.[CostCenterBusinessUnitEntitySiteID] = epsp.CostCenterBusinessUnitEntitySiteID
		GROUP BY epsp.EntityDesc
		, CASE WHEN epsp.CostCenterBusinessUnitEntitySiteID =6450 THEN 'Volunteers'	/*custom remapping for me as surgery doesn't seam consistently reliable*/
			   ELSE epsp.ProgramDesc
		END
		, epsp.SubProgramDesc
		, cas.[Dept#]
		, cas.[Site]
		, cas.[YEAR]
		, cas.[period]
	) as casualHours
	ON  productiveHours.EntityDesc = casualHours.EntityDesc					/*same entity*/
	AND productiveHours.ProgramDesc = casualHours.ProgramDesc				/*same program*/
	AND productiveHours.CostCenterCode =casualHours.CostCenterCode		/*same cost center*/
	AND productiveHours.FinSiteID = casualHours.FinSiteID					/*same financial site*/
	AND productiveHours.[FiscalYearLong] = casualHours.[FiscalYearLong]		/*same fiscal year*/
	AND productiveHours.[FiscalPeriod] = casualHours.[FiscalPeriod]			/*same fiscal period*/
	;


	/*roll up cost centers according to Betty's map*/
	IF OBJECT_ID('tempdb.dbo.#otHours2') is not null DROP TABLE #otHours2;


	/*Coo and director rows*/
	SELECT OT.FiscalYearLong
	, OT.FiscalPeriod
	, 'TOP' as 'Level'
	, 'Overtime hours as % of all productive hours (incl. casuals)' as 'IndicatorName'
	, 'RHS' as 'Senior_Accountability'
	, CASE	WHEN OT.CostCenterCode ='73102030' AND OT.FinSiteID='650' THEN 'Jodi Kortje'
			WHEN OT.CostCenterCode ='75354001' AND OT.FinSiteID='655' THEN 'Nellie Hariri'
			WHEN OT.CostCenterCode in ('89902006', '72201009') AND OT.FinSiteID='650' THEN 'Unallocated'
			ELSE MAP.Accountability
	END as 'Junior_Accountability'
	, SUM(OT.Act_OTHrs) as 'Act_OTHrs'
	, SUM(OT.Bud_OTHrs) as 'Bud_OTHrs'
	, SUM(OT.Act_ProdHrs) as 'Act_ProdHrs'
	, SUM(OT.Casual_ProdHrs) as 'Casual_ProdHrs'
	, SUM(OT.Bud_ProdHrs) as 'Bud_ProdHrs'
	, IIF( SUM(OT.Act_ProdHrs)=0, 0, 1.0*SUM(OT.Act_OTHrs)/ SUM(OT.Act_ProdHrs)  ) as 'OT_Rate'
	INTO #otHours2
	FROM #otHours as OT
	LEFT JOIN DSSI.[dbo].[RHS_BETTY_CCMAP] as MAP
	ON OT.CostCenterCode=Map.DeptID	/*same cost center*/
	AND OT.FinSiteID=Map.ProdID		/*same site*/
	WHERE OT.ProgramDesc not in ('Health Protection','BISS','Regional Clinical Services')	/*exclude these programs*/
	GROUP BY OT.FiscalYearLong
	, OT.FiscalPeriod
	, CASE	WHEN OT.CostCenterCode ='73102030' AND OT.FinSiteID='650' THEN 'Jodi Kortje'
			WHEN OT.CostCenterCode ='75354001' AND OT.FinSiteID='655' THEN 'Nellie Hariri'
			WHEN OT.CostCenterCode in ('89902006', '72201009') AND OT.FinSiteID='650' THEN 'Unallocated'
			ELSE MAP.Accountability
	END
	/*add director and manager rows*/
	UNION
	SELECT OT.FiscalYearLong
	, OT.FiscalPeriod
	, 'MIDDLE' as 'Level'
	, 'Overtime hours as % of all productive hours (incl. casuals)' as 'IndicatorName'
	, CASE	WHEN OT.CostCenterCode ='73102030' AND OT.FinSiteID='650' THEN 'Jodi Kortje'
			WHEN OT.CostCenterCode ='75354001' AND OT.FinSiteID='655' THEN 'Nellie Hariri'
			WHEN OT.CostCenterCode in ('89902006', '72201009') AND OT.FinSiteID='650' THEN 'Unallocated'
			ELSE MAP.Accountability
	END as 'Senior_Accountability'
	, CASE	WHEN OT.CostCenterCode ='73102030' AND OT.FinSiteID='650' THEN 'Jodi Kortje'
			WHEN OT.CostCenterCode ='75354001' AND OT.FinSiteID='655' THEN 'Nellie Hariri'
			WHEN OT.CostCenterCode in ('89902006', '72201009') AND OT.FinSiteID='650' THEN 'Unallocated'
			ELSE ISNULL(MAP.Manager,MAP.Accountability)	/*use director if no manager present*/
	END as 'Junior_Accountability'
	, SUM(OT.Act_OTHrs) as 'Act_OTHrs'
	, SUM(OT.Bud_OTHrs) as 'Bud_OTHrs'
	, SUM(OT.Act_ProdHrs) as 'Act_ProdHrs'
	, SUM(OT.Casual_ProdHrs) as 'Casual_ProdHrs'
	, SUM(OT.Bud_ProdHrs) as 'Bud_ProdHrs'
	, IIF( SUM(OT.Act_ProdHrs)=0, 0, 1.0*SUM(OT.Act_OTHrs)/ SUM(OT.Act_ProdHrs)  ) as 'OT_Rate'
	FROM #otHours as OT
	LEFT JOIN DSSI.[dbo].[RHS_BETTY_CCMAP] as MAP
	ON OT.CostCenterCode=Map.DeptID	/*same cost center*/
	AND OT.FinSiteID=Map.ProdID		/*same site*/
	WHERE OT.ProgramDesc not in ('Health Protection','BISS','Regional Clinical Services')	/*exclude these programs*/
	GROUP BY OT.FiscalYearLong
	, OT.FiscalPeriod
	, CASE	WHEN OT.CostCenterCode ='73102030' AND OT.FinSiteID='650' THEN 'Jodi Kortje'
			WHEN OT.CostCenterCode ='75354001' AND OT.FinSiteID='655' THEN 'Nellie Hariri'
			WHEN OT.CostCenterCode in ('89902006', '72201009') AND OT.FinSiteID='650' THEN 'Unallocated'
			ELSE MAP.Accountability
	END 
	, CASE	WHEN OT.CostCenterCode ='73102030' AND OT.FinSiteID='650' THEN 'Jodi Kortje'
			WHEN OT.CostCenterCode ='75354001' AND OT.FinSiteID='655' THEN 'Nellie Hariri'
			WHEN OT.CostCenterCode in ('89902006', '72201009') AND OT.FinSiteID='650' THEN 'Unallocated'
			ELSE ISNULL(MAP.Manager, MAP.Accountability)
	END
	/*add manager and cost center rows*/
	UNION
	SELECT OT.FiscalYearLong
	, OT.FiscalPeriod
	, 'BOTTOM' as 'Level'
	, 'Overtime hours as % of all productive hours (incl. casuals)' as 'IndicatorName'
	, CASE	WHEN OT.CostCenterCode ='73102030' AND OT.FinSiteID='650' THEN 'Jodi Kortje'
			WHEN OT.CostCenterCode ='75354001' AND OT.FinSiteID='655' THEN 'Nellie Hariri'
			WHEN OT.CostCenterCode in ('89902006', '72201009') AND OT.FinSiteID='650' THEN 'Unallocated'
			ELSE ISNULL(MAP.Manager, MAP.Accountability)	/*fill with director if no manager is specified*/
	END as 'Senior_Accountability'
	, CostCenterCode as 'Junior_Accountability'
	, SUM(OT.Act_OTHrs) as 'Act_OTHrs'
	, SUM(OT.Bud_OTHrs) as 'Bud_OTHrs'
	, SUM(OT.Act_ProdHrs) as 'Act_ProdHrs'
	, SUM(OT.Casual_ProdHrs) as 'Casual_ProdHrs'
	, SUM(OT.Bud_ProdHrs) as 'Bud_ProdHrs'
	, IIF( SUM(OT.Act_ProdHrs)=0, 0, 1.0*SUM(OT.Act_OTHrs)/ SUM(OT.Act_ProdHrs)  ) as 'OT_Rate'
	FROM #otHours as OT
	LEFT JOIN DSSI.[dbo].[RHS_BETTY_CCMAP] as MAP
	ON OT.CostCenterCode=Map.DeptID	/*same cost center*/
	AND OT.FinSiteID=Map.ProdID		/*same site*/
	WHERE OT.ProgramDesc not in ('Health Protection','BISS','Regional Clinical Services')	/*exclude these programs*/
	GROUP BY OT.FiscalYearLong
	, OT.FiscalPeriod
	, CASE	WHEN OT.CostCenterCode ='73102030' AND OT.FinSiteID='650' THEN 'Jodi Kortje'
			WHEN OT.CostCenterCode ='75354001' AND OT.FinSiteID='655' THEN 'Nellie Hariri'
			WHEN OT.CostCenterCode in ('89902006', '72201009') AND OT.FinSiteID='650' THEN 'Unallocated'
			ELSE ISNULL(MAP.Manager, MAP.Accountability)	
	END
	, CostCenterCode
	;

	/* final result filtered to reporting fiscal periods*/
	SELECT D.FiscalPeriodLong
	, D.FiscalPeriodEndDate
	, OT.*
	FROM #otHours2 as OT
	INNER JOIN #st_ot_packages_FP as D
	ON OT.FiscalYearLong = D.FiscalYearLong
	AND OT.FiscalPeriod =D.FiscalPeriod




---------------------------------------
-- ID13 Sick Rate
---------------------------------------
	/*
	Purpose: To pull the sick hours and productive horus from FinanceMart.
	Author: Hans Aisake
	Date Created: May 21, 2019
	Date Modified: 
	Inclusions/Exclusions:
	Comments:
		Carolina was consulted for the specs. I took some liberties to blend the query she sent and what was in the financeportal reports.
		It removes casual productive and sick hours.

		The arugment was made that casuals don't get sick hours normally, and instead they just don't get paid.
		There are also some technical issues with how we determine overtime pay and sick time pay for casuals because it's based on strange employment criteria.
		Casuals choose which days are their "days off" and get OT for comming in on those days. -Not 100% certain this is true, but I have reason to lean this way.
		Because of this we exclude casuals hours from the indicator. 
		For some areas this can be 15% of the total productive hours.
		I don't have casual budgeted productive hours and can't remove them.

	*/

	/*reporting periods, based on 1 day lag*/
	IF OBJECT_ID('tempdb.dbo.#st_ot_packages_FP') IS NOT NULL DROP TABLE #st_ot_packages_FP;


	SELECT distinct TOP 39 FiscalPeriodLong, fiscalperiodstartdate, fiscalperiodenddate, FiscalPeriodEndDateID, FiscalPeriod, FiscalYearLong
	INTO #st_ot_packages_FP
	FROM ADTCMart.dim.[Date]
	WHERE fiscalperiodenddate <= DATEADD(day, -1, GETDATE())
	ORDER BY FiscalPeriodEndDate DESC
	;
	
	/*pull sick time hours*/
	IF OBJECT_ID('tempdb.dbo.#stHours') is not null DROP TABLE #stHours;

	SELECT productiveHours.EntityDesc
	, productiveHours.ProgramDesc
	, productiveHours.CostCenterCode
	, productiveHours.FinSiteID
	, productiveHours.[FiscalYearLong]
	, productiveHours.[FiscalPeriod] 
	, productiveHours.Act_ProdHrs - ISNULL(casualHours.Casual_ProdHrs,0) as 'Act_ProdHrs'	/*we exclude casual hours for sick time*/
	, ISNULL(casualHours.Casual_ProdHrs,0) as 'Casual_ProdHrs'
	, ISNULL(stHours.Act_STHrs,0) - ISNULL(casualHours.Casual_SickHrs,0) as 'Act_STHrs'
	, casualHours.Casual_SickHrs
	, productiveHours.Bud_ProdHrs	/*I could see an arugment to have to adjust via casual hours, but I can also see one not to. We don't plan for casual hours.*/
	, ISNULL(StHours.Bud_STHrs,0) as 'Bud_STHrs'
	INTO #stHours
	FROM
	(	
		SELECT epsp.EntityDesc
		, CASE WHEN epsp.CostCenterBusinessUnitEntitySiteID =6450 THEN 'Volunteers'	/*custom remapping for me as surgery doesn't seam consistently reliable*/
			   ELSE epsp.ProgramDesc
		END as 'ProgramDesc'
		, epsp.SubProgramDesc
		, cc.CostCenterCode
		, schrs.FinSiteID
		, schrs.[FiscalYearLong]
		, schrs.[FiscalPeriod]  
		, Sum(schrs.[SumCodeHrs]) as 'Act_ProdHrs'   
		, Sum(schrs.[BudgetHrs]) as 'Bud_ProdHrs'
		FROM [FinanceMart].[dbo].[SumCodeHrsSummary] as schrs
		INNER JOIN [FinanceMart].[Dim].[CostCenter] as cc
		ON schrs.CostCenter = cc.CostCenterCode
		INNER JOIN [FinanceMart].Dim.CostCenterBusinessUnitEntitySite as ccbues
		ON cc.CostCenterID = ccbues.CostCenterID 
		AND schrs.FinSiteID=ccbues.FinSiteID
		INNER JOIN [FinanceMart].[Finance].[EntityProgramSubProgram] as EPSP
		ON ccbues.CostCenterBusinessUnitEntitySiteID = EPSP.CostCenterBusinessUnitEntitySiteID		/*same ccentitysiteid*/
		where sumCodeID <= 199										/*productive hours*/
		AND EntityDesc in('Richmond Health Services')				/*focus on these entities*/
		AND EntityProgramDesc in ('RH Clinical'	,'RHS HSDA')		/*rileys file had both of these included in the total richmond numbers*/
		AND FiscalYearLong >= 2015									/*date cutoff*/
		GROUP BY epsp.EntityDesc
		, CASE WHEN epsp.CostCenterBusinessUnitEntitySiteID =6450 THEN 'Volunteers'	/*custom remapping for me as surgery doesn't seam consistently reliable*/
			   ELSE epsp.ProgramDesc
		END
		, epsp.SubProgramDesc
		, cc.CostCenterCode
		, schrs.FinSiteID
		, schrs.[FiscalYearLong]
		, schrs.[FiscalPeriod]
	) as productiveHours
	LEFT JOIN
	(	SELECT epsp.EntityDesc
		, CASE WHEN epsp.CostCenterBusinessUnitEntitySiteID =6450 THEN 'Volunteers'	/*custom remapping for me as surgery doesn't seam consistently reliable*/
			   ELSE epsp.ProgramDesc
		END as 'ProgramDesc'
		, epsp.SubProgramDesc
		, cc.CostCenterCode
		, schrs.FinSiteID
		, schrs.[FiscalYearLong]
		, schrs.[FiscalPeriod] 
		, Sum([SumCodeHrs]) as 'Act_STHrs' 
		, Sum([BudgetHrs]) as 'Bud_STHrs' 
		FROM [FinanceMart].[dbo].[SumCodeHrsSummary] as schrs
		INNER JOIN [FinanceMart].[Dim].[CostCenter] as cc	/*get cost center business unit entity site id*/
		ON schrs.CostCenter = cc.CostCenterCode		/*same cost center*/
		INNER JOIN FinanceMart.Dim.CostCenterBusinessUnitEntitySite as ccbues
		ON cc.CostCenterID = ccbues.CostCenterID		/*same cost center*/
		AND schrs.FinSiteID=ccbues.FinSiteID			/*same financial site*/
		JOIN [FinanceMart].[Finance].[EntityProgramSubProgram] as EPSP
		ON ccbues.CostCenterBusinessUnitEntitySiteID = EPSP.CostCenterBusinessUnitEntitySiteID
		WHERE sumCodeID = 206							/*sick time hours*/
		and EntityDesc in('Richmond Health Services')		/*focus on these entities*/
		and EntityProgramDesc in ('RH Clinical','RHS HSDA')	/*rileys file had both of these included in the total richmond numbers*/
		AND FiscalYearLong >= 2015						/*date cutoff*/
		GROUP BY epsp.EntityDesc
		, CASE WHEN epsp.CostCenterBusinessUnitEntitySiteID =6450 THEN 'Volunteers'	/*custom remapping for me as surgery doesn't seam consistently reliable*/
			   ELSE epsp.ProgramDesc
		END 
		, epsp.SubProgramDesc
		, cc.CostCenterCode
		, schrs.FinSiteID
		, schrs.[FiscalYearLong]
		, schrs.[FiscalPeriod]
	) as stHours
	ON  productiveHours.EntityDesc = stHours.EntityDesc					/*same entity*/
	AND productiveHours.ProgramDesc = stHours.ProgramDesc				/*same program*/
	AND productiveHours.CostCenterCode =stHours.CostCenterCode				/*same cost center*/
	AND productiveHours.FinSiteID = stHours.FinSiteID						/*same financial site*/
	AND productiveHours.[FiscalYearLong] = stHours.[FiscalYearLong]		/*same fiscal year*/
	AND productiveHours.[FiscalPeriod] = stHours.[FiscalPeriod]			/*same fiscal period*/
	LEFT JOIN
	(
		SELECT epsp.EntityDesc
		, CASE WHEN epsp.CostCenterBusinessUnitEntitySiteID =6450 THEN 'Volunteers'	/*custom remapping for me as surgery doesn't seam consistently reliable*/
			   ELSE epsp.ProgramDesc
		END as 'ProgramDesc'
		, epsp.SubProgramDesc
		, cas.[Dept#] as 'CostCenterCode'
		, cas.[Site] as 'FinSiteID'
		, cas.[YEAR] as 'FiscalYearLong'
		, cas.[period] as 'FiscalPeriod'
		, SUM(cas.[Hour Prod]) as 'Casual_ProdHrs'
		, SUM(cas.[SickHrs]) as 'Casual_SickHrs'
		, SUM(cas.[OTHrs]) as 'Casual_OTHrs'
		FROM FinanceMart.[Finance].[vwCasualHrsFact] as cas
		LEFT JOIN FinanceMArt.Finance.EntityProgramSubProgram as epsp
		ON cas.[CostCenterBusinessUnitEntitySiteID] = epsp.CostCenterBusinessUnitEntitySiteID
		GROUP BY epsp.EntityDesc
		, CASE WHEN epsp.CostCenterBusinessUnitEntitySiteID =6450 THEN 'Volunteers'	/*custom remapping for me as surgery doesn't seam consistently reliable*/
			   ELSE epsp.ProgramDesc
		END
		, epsp.SubProgramDesc
		, cas.[Dept#]
		, cas.[Site]
		, cas.[YEAR]
		, cas.[period]
	) as casualHours
	ON  productiveHours.EntityDesc = casualHours.EntityDesc				/*same entity*/
	AND productiveHours.ProgramDesc = casualHours.ProgramDesc			/*same program*/
	AND productiveHours.CostCenterCode =casualHours.CostCenterCode		/*same cost center*/
	AND productiveHours.FinSiteID = casualHours.FinSiteID				/*same financial site*/
	AND productiveHours.[FiscalYearLong] = casualHours.[FiscalYearLong]	/*same fiscal year*/
	AND productiveHours.[FiscalPeriod] = casualHours.[FiscalPeriod]		/*same fiscal period*/
	;


	/*roll up cost centers according to Betty's map*/
	IF OBJECT_ID('tempdb.dbo.#stHours2') is not null DROP TABLE #stHours2;


	/*Coo and director rows*/
	SELECT ST.FiscalYearLong
	, ST.FiscalPeriod
	, 'TOP' as 'Level'
	, 'Sick time hours as % of all productive hours (excl. casual hrs)' as 'IndicatorName'
	, 'RHS' as 'Senior_Accountability'
	, CASE	WHEN ST.CostCenterCode ='73102030' AND ST.FinSiteID='650' THEN 'Jodi Kortje'
			WHEN ST.CostCenterCode ='75354001' AND ST.FinSiteID='655' THEN 'Nellie Hariri'
			WHEN ST.CostCenterCode in ('89902006', '72201009') AND ST.FinSiteID='650' THEN 'Unallocated'
			ELSE MAP.Accountability
	END as 'Junior_Accountability'
	, SUM(ST.Act_STHrs) as 'Act_STHrs'
	, SUM(ST.Bud_STHrs) as 'Bud_STHrs'
	, SUM(ST.Act_ProdHrs) as 'Act_ProdHrs'
	, SUM(ST.Casual_ProdHrs) as 'Casual_ProdHrs'
	, SUM(ST.Bud_ProdHrs) as 'Bud_ProdHrs'
	, IIF( SUM(ST.Act_ProdHrs)=0, 0, 1.0*SUM(ST.Act_STHrs)/SUM(ST.Act_ProdHrs)  ) as 'Sicktime Rate' /*division by 0 errors are set as 0; Technically they are nulls, but 0's will stop the lines from being wierd and I feel 0/0 = 0 is fair in this case.*/
	INTO #stHours2
	FROM #stHours as ST
	LEFT JOIN DSSI.[dbo].[RHS_BETTY_CCMAP] as MAP
	ON ST.CostCenterCode=Map.DeptID	/*same cost center*/
	AND ST.FinSiteID=Map.ProdID		/*same site*/
	WHERE ST.ProgramDesc not in ('Health Protection','BISS','Regional Clinical Services')	/*exclude these programs*/
	GROUP BY ST.FiscalYearLong
	, ST.FiscalPeriod
	, CASE	WHEN ST.CostCenterCode ='73102030' AND ST.FinSiteID='650' THEN 'Jodi Kortje'
			WHEN ST.CostCenterCode ='75354001' AND ST.FinSiteID='655' THEN 'Nellie Hariri'
			WHEN ST.CostCenterCode in ('89902006', '72201009') AND ST.FinSiteID='650' THEN 'Unallocated'
			ELSE MAP.Accountability
	END
	/*add director and manager rows*/
	UNION
	SELECT ST.FiscalYearLong
	, ST.FiscalPeriod
	, 'MIDDLE' as 'Level'
	, 'Sick time hours as % of all productive hours (excl. casual hrs)' as 'IndicatorName'
	, CASE	WHEN ST.CostCenterCode ='73102030' AND ST.FinSiteID='650' THEN 'Jodi Kortje'
			WHEN ST.CostCenterCode ='75354001' AND ST.FinSiteID='655' THEN 'Nellie Hariri'
			WHEN ST.CostCenterCode in ('89902006', '72201009') AND ST.FinSiteID='650' THEN 'Unallocated'
			ELSE MAP.Accountability
	END as 'Senior_Accountability'
	, CASE	WHEN ST.CostCenterCode ='73102030' AND ST.FinSiteID='650' THEN 'Jodi Kortje'
			WHEN ST.CostCenterCode ='75354001' AND ST.FinSiteID='655' THEN 'Nellie Hariri'
			WHEN ST.CostCenterCode in ('89902006', '72201009') AND ST.FinSiteID='650' THEN 'Unallocated'
			ELSE ISNULL(MAP.Manager,MAP.Accountability)	/*use director if no manager present*/
	END as 'Junior_Accountability'
	, SUM(ST.Act_STHrs) as 'Act_STHrs'
	, SUM(ST.Bud_STHrs) as 'Bud_STHrs'
	, SUM(ST.Act_ProdHrs) as 'Act_ProdHrs'
	, SUM(ST.Casual_ProdHrs) as 'Casual_ProdHrs'
	, SUM(ST.Bud_ProdHrs) as 'Bud_ProdHrs'
	, IIF( SUM(ST.Act_ProdHrs)=0, 0, 1.0*SUM(ST.Act_STHrs)/SUM(ST.Act_ProdHrs)  ) as 'Sicktime Rate' /*division by 0 errors are set as 0; Technically they are nulls, but 0's will stop the lines from being wierd and I feel 0/0 = 0 is fair in this case.*/
	FROM #stHours as ST
	LEFT JOIN DSSI.[dbo].[RHS_BETTY_CCMAP] as MAP
	ON ST.CostCenterCode=Map.DeptID	/*same cost center*/
	AND ST.FinSiteID=Map.ProdID		/*same site*/
	WHERE ST.ProgramDesc not in ('Health Protection','BISS','Regional Clinical Services')	/*exclude these programs*/
	GROUP BY ST.FiscalYearLong
	, ST.FiscalPeriod
	, CASE	WHEN ST.CostCenterCode ='73102030' AND ST.FinSiteID='650' THEN 'Jodi Kortje'
			WHEN ST.CostCenterCode ='75354001' AND ST.FinSiteID='655' THEN 'Nellie Hariri'
			WHEN ST.CostCenterCode in ('89902006', '72201009') AND ST.FinSiteID='650' THEN 'Unallocated'
			ELSE MAP.Accountability
	END 
	, CASE	WHEN ST.CostCenterCode ='73102030' AND ST.FinSiteID='650' THEN 'Jodi Kortje'
			WHEN ST.CostCenterCode ='75354001' AND ST.FinSiteID='655' THEN 'Nellie Hariri'
			WHEN ST.CostCenterCode in ('89902006', '72201009') AND ST.FinSiteID='650' THEN 'Unallocated'
			ELSE ISNULL(MAP.Manager, MAP.Accountability)
	END
	/*add manager and cost center rows*/
	UNION
	SELECT ST.FiscalYearLong
	, ST.FiscalPeriod
	, 'BOTTOM' as 'Level'
	, 'Sick time hours as % of all productive hours (excl. casual hrs)' as 'IndicatorName'
	, CASE	WHEN ST.CostCenterCode ='73102030' AND ST.FinSiteID='650' THEN 'Jodi Kortje'
			WHEN ST.CostCenterCode ='75354001' AND ST.FinSiteID='655' THEN 'Nellie Hariri'
			WHEN ST.CostCenterCode in ('89902006', '72201009') AND ST.FinSiteID='650' THEN 'Unallocated'
			ELSE ISNULL(MAP.Manager, MAP.Accountability)	/*fill with director if no manager is specified*/
	END as 'Senior_Accountability'
	, CostCenterCode as 'Junior_Accountability'
	, SUM(ST.Act_STHrs) as 'Act_STHrs'
	, SUM(ST.Bud_STHrs) as 'Bud_STHrs'
	, SUM(ST.Act_ProdHrs) as 'Act_ProdHrs'
	, SUM(ST.Casual_ProdHrs) as 'Casual_ProdHrs'
	, SUM(ST.Bud_ProdHrs) as 'Bud_ProdHrs'
	, IIF( SUM(ST.Act_ProdHrs)=0, 0, 1.0*SUM(ST.Act_STHrs)/SUM(ST.Act_ProdHrs)  ) as 'Sicktime Rate' /*division by 0 errors are set as 0; Technically they are nulls, but 0's will stop the lines from being wierd and I feel 0/0 = 0 is fair in this case.*/
	FROM #stHours as ST
	LEFT JOIN DSSI.[dbo].[RHS_BETTY_CCMAP] as MAP
	ON ST.CostCenterCode=Map.DeptID	/*same cost center*/
	AND ST.FinSiteID=Map.ProdID		/*same site*/
	WHERE ST.ProgramDesc not in ('Health Protection','BISS','Regional Clinical Services')	/*exclude these programs*/
	GROUP BY ST.FiscalYearLong
	, ST.FiscalPeriod
	, CASE	WHEN ST.CostCenterCode ='73102030' AND ST.FinSiteID='650' THEN 'Jodi Kortje'
			WHEN ST.CostCenterCode ='75354001' AND ST.FinSiteID='655' THEN 'Nellie Hariri'
			WHEN ST.CostCenterCode in ('89902006', '72201009') AND ST.FinSiteID='650' THEN 'Unallocated'
			ELSE ISNULL(MAP.Manager, MAP.Accountability)	
	END
	, CostCenterCode
	;

	/* filter the results to the reporting periods*/
	SELECT ST.*
	, D.FiscalPeriodLong
	, D.FiscalPeriodEndDate
	FROM #stHours2 as ST
	INNER JOIN #st_ot_packages_FP as D
	ON  ST.FiscalYearLong = D.FiscalYearLong
	AND ST.FiscalPeriod = D.FiscalPeriod



	
		

	