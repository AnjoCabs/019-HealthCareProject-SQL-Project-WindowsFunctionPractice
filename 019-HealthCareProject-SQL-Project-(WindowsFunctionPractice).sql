/* 
"Designed and implemented advanced SQL queries using Window Functions including RANK(), DENSE_RANK(),
 ROW_NUMBER(), LAG(), LEAD(), NTILE(), and cumulative aggregations to analyze healthcare operations 
 and support strategic decision-making."
*/

USE hospital3project;

-- 1. Rank providers by total revenue generated.
SELECT 
    p.providerName,
    SUM(COALESCE(v.treatmentCost,0) + COALESCE(v.medicationCost,0) + COALESCE(v.roomCharges,0)) AS totalRevenue,
    RANK() OVER (ORDER BY SUM(COALESCE(v.treatmentCost,0) + COALESCE(v.medicationCost,0) + COALESCE(v.roomCharges,0)) DESC) AS revenueRank
FROM providers p
JOIN visits v
    ON p.providerId = v.providerId
GROUP BY p.providerName;

-- 2. Rank diagnoses by total treatment cost.
SELECT
	v.diagnosisId,
    d.diagnosis,
    SUM(v.treatmentCost) AS totalTreatmentCosts,
    DENSE_RANK() OVER (ORDER BY SUM(v.treatmentCost) DESC) AS treatmentCostRank
FROM visits v
JOIN diagnoses d
	ON v.diagnosisId = d.diagnosisId
GROUP BY
	v.diagnosisId,
    d.diagnosis;
    
-- 3. Rank patients by total healthcare spending.
SELECT 
	p.patientId,
    p.patientName,
	SUM(COALESCE(v.treatmentCost,0) + COALESCE(v.medicationCost,0) + COALESCE(v.roomCharges,0)) AS totalHealthCareSpending,
    DENSE_RANK() OVER (ORDER BY SUM(COALESCE(v.treatmentCost,0) + COALESCE(v.medicationCost,0) + COALESCE(v.roomCharges,0)) DESC) AS healthCareSpendingRank
FROM visits v
JOIN patients p
	ON v.patientId = p.patientId
GROUP BY
	p.patientId,
    p.patientName;
    
    
-- 4. Calculate cumulative hospital revenue over time.
SELECT
    YEAR(dateOfVisit) AS year_,
    MONTH(dateOfVisit) AS month_,
    SUM(treatmentCost + medicationCost + roomCharges - insuranceCoverage) AS monthlyRevenue,
    SUM(SUM(treatmentCost + medicationCost + roomCharges - insuranceCoverage)) OVER (ORDER BY
            YEAR(dateOfVisit),
            MONTH(dateOfVisit)
    ) AS cumulativeRevenue
FROM visits
GROUP BY
    YEAR(dateOfVisit),
    MONTH(dateOfVisit)
ORDER BY
    YEAR(dateOfVisit),
    MONTH(dateOfVisit);
    
-- 5. Calculate cumulative revenue by department.
SELECT
    v.departmentId,
    d.department,
    SUM(
        COALESCE(v.treatmentCost, 0) + 
        COALESCE(v.medicationCost, 0) + 
        COALESCE(v.roomCharges, 0) - 
        COALESCE(v.insuranceCoverage, 0)) AS totalRevenue
FROM visits v
JOIN departments d
    ON v.departmentId = d.departmentId
GROUP BY 
    v.departmentId,
    d.department;
    
-- 6. Calculate cumulative patient visits by month.
SELECT
    YEAR(dateOfVisit) AS year_,
    MONTH(dateOfVisit) AS month_,
    MONTHNAME(dateOfVisit) AS monthName_,
    COUNT(visitId) AS monthlyVisits,
    SUM(COUNT(visitId)) OVER (ORDER BY YEAR(dateOfVisit), MONTH(dateOfVisit)) AS cumulative_visits
FROM visits
GROUP BY
    YEAR(dateOfVisit),
    MONTH(dateOfVisit),
    MONTHNAME(dateOfVisit)
ORDER BY
    YEAR(dateOfVisit),
    MONTH(dateOfVisit);
    
-- 7. Calculate cumulative insurance coverage amount over time
SELECT
	YEAR(dateOfVisit) AS year_,
    MONTH(dateOfVisit) AS month_,
    MONTHNAME(dateOfVisit) AS monthName_,
    SUM(SUM(COALESCE(insuranceCoverage, 0))) OVER (ORDER BY YEAR(dateOfVisit), MONTH(dateOfVisit)) AS cumulativeInsuranceCoverage
FROM visits
GROUP BY
	YEAR(dateOfVisit),
    MONTH(dateOfVisit),
    MONTHNAME(dateOfVisit)
ORDER BY
    YEAR(dateOfVisit),
    MONTH(dateOfVisit);
    
-- 8. Calculate running treatment costs for each provider.
SELECT
    YEAR(v.dateOfVisit) AS year_,
    MONTH(v.dateOfVisit) AS month_,
    v.providerId,
    p.providerName,
    SUM(SUM(COALESCE(v.treatmentCost, 0))) OVER (
        PARTITION BY v.providerId, p.providerName 
        ORDER BY YEAR(v.dateOfVisit), MONTH(v.dateOfVisit)
    ) AS runningTreatmentCost
FROM visits v
JOIN providers p
    ON v.providerId = p.providerId
GROUP BY
    YEAR(v.dateOfVisit),
    MONTH(v.dateOfVisit),
    v.providerId,
    p.providerName
ORDER BY
    year_,
    month_,
    v.providerId;
    
-- 9. Calculate a 3-month moving average of hospital revenue.
SELECT
    year_,
    month_,
    monthlyRevenue,
    ROUND(
        AVG(monthlyRevenue) OVER (ORDER BY year_, month_ ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS movingAvg3Months
FROM (
    SELECT
        YEAR(dateOfVisit) AS year_,
        MONTH(dateOfVisit) AS month_,
        SUM(treatmentCost + medicationCost + roomCharges - insuranceCoverage) AS monthlyRevenue
    FROM visits
    GROUP BY
        YEAR(dateOfVisit),
        MONTH(dateOfVisit)
) m
ORDER BY
    year_,
    month_;
    
-- 10. Calculate a moving average of patient satisfaction scores.
SELECT
    year_,
    month_,
    avgSatisfaction,
    ROUND(
		AVG(avgSatisfaction) OVER (ORDER BY year_, month_ ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS movingAvgSatisfaction
FROM (
	SELECT
		YEAR(dateOfVisit) AS year_,
		MONTH(dateOfVisit) AS month_,
		ROUND(AVG(patientSatisfactionScore), 2) AS avgSatisfaction
	FROM visits
	GROUP BY
		YEAR(dateOfVisit),
	MONTH(dateOfVisit)
) p 
ORDER BY
    year_,
    month_;
    
-- 11. Calculate a rolling average treatment cost per diagnosis.
WITH monthlyDiagnosisCosts AS (
    SELECT
        d.diagnosis,
        YEAR(v.dateOfVisit) AS year_,
        MONTH(v.dateOfVisit) AS month_,
        AVG(COALESCE(v.treatmentCost, 0)) AS monthlyAvgCost
    FROM visits v
    JOIN diagnoses d 
        ON v.diagnosisId = d.diagnosisId
    GROUP BY
        d.diagnosis,
        YEAR(v.dateOfVisit),
        MONTH(v.dateOfVisit)
)
SELECT
    diagnosis,
    year_,
    month_,
    ROUND(monthlyAvgCost, 2) AS currentMonthAvgCost,
    ROUND(
        AVG(monthlyAvgCost) OVER (
            PARTITION BY diagnosis
            ORDER BY year_, month_
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW ), 2 ) AS rolling3MonthAvgCost
FROM monthlyDiagnosisCosts
ORDER BY
    diagnosis,
    year_,
    month_;

-- 12. Compare each month's revenue to the previous month.
WITH monthlyRevenue AS (
    SELECT
        YEAR(dateOfVisit) AS year_,
        MONTH(dateOfVisit) AS month_,
        SUM(treatmentCost + medicationCost + roomCharges - insuranceCoverage) AS monthlyRevenue
    FROM visits
    GROUP BY
        YEAR(dateOfVisit),
        MONTH(dateOfVisit)
)
SELECT
    year_,
    month_,
    monthlyRevenue,
    LAG(monthlyRevenue) OVER (ORDER BY year_, month_) AS previousMonthRevenue,
    monthlyRevenue - LAG(monthlyRevenue) OVER (ORDER BY year_, month_) AS revenueDifference
FROM monthlyRevenue
ORDER BY
    year_,
    month_;
    
-- 13. Calculate revenue growth percentage month-over-month.
SELECT
	year_,
    month_,
    monthlyRevenue,
    LAG(monthlyRevenue) OVER (ORDER BY year_, month_) AS previusMonthRevenue,
ROUND(
    (monthlyRevenue - LAG(monthlyRevenue) OVER (ORDER BY year_, month_)) 
    * 100.0 / NULLIF(LAG(monthlyRevenue) OVER (ORDER BY year_, month_), 0), 2
) AS MoM_growthPercentage
FROM (
	SELECT	
		YEAR(dateOfVisit) AS year_,
		MONTH(dateOfVisit) AS month_,
		SUM(treatmentCost + medicationCost + roomCharges - insuranceCoverage) AS monthlyRevenue
	FROM visits
	GROUP BY
		year_,
		month_ ) mr
ORDER BY 
	year_,
    month_;
    
-- 14. Identify patients whose healthcare spending increased from their previous visit.
WITH patientSpending AS (
    SELECT
        visitId,
        patientId,
        dateOfVisit,
        (treatmentCost + medicationCost + roomCharges - insuranceCoverage) AS visitSpending,
        LAG( treatmentCost + medicationCost + roomCharges - insuranceCoverage) OVER (PARTITION BY patientId
            ORDER BY dateOfVisit) AS previousVisitSpending
    FROM visits
)
SELECT
    patientId,
    dateOfVisit,
    visitSpending,
    previousVisitSpending,
    ROUND((visitSpending - previousVisitSpending) / previousVisitSpending * 100, 2) AS percentageIncrease
FROM patientSpending
WHERE visitSpending > previousVisitSpending;

-- 15. Find the first diagnosis recorded for each patient.
WITH rankedVisits AS (
    SELECT
        v.patientId,
        v.diagnosisId,
        FIRST_VALUE(v.diagnosisId) OVER (
            PARTITION BY v.patientId
            ORDER BY v.dateOfVisit ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS firstDiagnosisId
    FROM visits v
)
SELECT DISTINCT
    rv.patientId,
    rv.firstDiagnosisId,
    d.diagnosis AS firstDiagnosisName
FROM rankedVisits rv
JOIN diagnoses d
    ON rv.firstDiagnosisId = d.diagnosisId;
    
-- 16. Find the most recent diagnosis for each patient.
WITH rankedVisits AS (
    SELECT
        v.patientId,
        v.diagnosisId,
        LAST_VALUE(v.diagnosisId) OVER (
            PARTITION BY v.patientId
            ORDER BY v.dateOfVisit ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS firstDiagnosisId
    FROM visits v
)
SELECT DISTINCT
    rv.patientId,
    rv.firstDiagnosisId,
    d.diagnosis AS firstDiagnosisName
FROM rankedVisits rv
JOIN diagnoses d
    ON rv.firstDiagnosisId = d.diagnosisId;
    
-- 17. Divide patients into 4 spending groups
WITH patientSpending AS (
    SELECT
        patientId,
        SUM(treatmentCost + medicationCost + roomCharges - insuranceCoverage) AS totalSpending
    FROM visits
    GROUP BY patientId
)
SELECT
    patientId,
    total_spending,
    CASE
        WHEN NTILE(4) OVER (ORDER BY total_spending) = 1
            THEN 'Low Spending'
        WHEN NTILE(4) OVER (ORDER BY total_spending) = 2
            THEN 'Medium Spending'
        WHEN NTILE(4) OVER (ORDER BY total_spending) = 3
            THEN 'High Spending'
        ELSE 'Very High Spending'
    END AS spending_group
FROM patient_spending;

-- 18. Determine which departments have revenue above the overall hospital average.
WITH departmentRevenue AS (
    SELECT
        d.department,
        SUM(COALESCE(v.treatmentCost,0) + COALESCE(v.medicationCost,0) + COALESCE(v.roomCharges,0)) AS totalDeptRevenue
    FROM visits v
    JOIN departments d
        ON v.departmentId = d.departmentId
    GROUP BY d.department
),
hospitalAverage AS (
    SELECT 
        department,
        totalDeptRevenue,
        AVG(totalDeptRevenue) OVER() AS overallHospitalAvg
    FROM departmentRevenue
)
SELECT 
    department,
    ROUND(totalDeptRevenue, 2) AS departmentRevenue,
    ROUND(overallHospitalAvg, 2) AS hospitalAverageRevenue
FROM HospitalAverage
WHERE totalDeptRevenue > overallHospitalAvg;

-- 19. Find patients spending more than the average patient.
WITH totalSpending AS (
    SELECT
        patientId,
        SUM(COALESCE(treatmentCost,0) + COALESCE(medicationCost,0) + COALESCE(roomCharges,0)) AS totalSpending
    FROM visits
    GROUP BY patientId
),
patientAvg AS (
    SELECT
        patientId,
        totalSpending,
        AVG(totalSpending) OVER () AS avgTotalSpending 
    FROM totalSpending
)
SELECT
    patientId,
    ROUND(totalSpending, 2) AS totalSpending,
    ROUND(avgTotalSpending, 2) AS avgTotalSpending
FROM patientAvg 
WHERE totalSpending > avgTotalSpending;

-- 20. Calculate each provider's contribution percentage to total hospital revenue.
WITH providerTotalRevenue AS (
    SELECT
        v.providerId,
        p.providerName,
        SUM(COALESCE(v.treatmentCost, 0) + COALESCE(v.medicationCost, 0) + COALESCE(v.roomCharges, 0)) AS totalRevenue
    FROM visits v
    JOIN providers p
        ON v.providerId = p.providerId
    GROUP BY 
        v.providerId,
        p.providerName
)
SELECT
    providerId,
    providerName,
    ROUND(totalRevenue, 2) AS providerRevenue,    
    ROUND((totalRevenue * 100.0) / SUM(totalRevenue) OVER (), 2) AS contributionPercentage
FROM providerTotalRevenue
ORDER BY contributionPercentage DESC;

/* 
"Designed and implemented advanced SQL queries using Window Functions including RANK(), DENSE_RANK(),
 ROW_NUMBER(), LAG(), LEAD(), NTILE(), and cumulative aggregations to analyze healthcare operations 
 and support strategic decision-making."
*/