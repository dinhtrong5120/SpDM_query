SELECT distinct
	l_id,
    pj_code,
    drivetrain,
    archi,
    phase,
    lot,
    hierarchy,
    r_wp
FROM
    rfl_view_tlm
LEFT JOIN r_parameter on rfl_view_tlm.r_id = r_parameter.id
WHERE
	-- r_id IN (10016 , 290196, 290217, 19999, 290197, 290218)
	l_id IN (
1001689, 1001645
    )
;


SELECT DISTINCT
    r_id,
    pj_code,
    drivetrain,
    archi,
    phase,
    lot,
    hierarchy,
    r_wp,
   TRIM(r_parameter.performance)   AS 性能,
   TRIM(r_parameter.design_item_1) AS 設計項目（大）,
   TRIM(r_parameter.design_item_2) AS 設計項目（小）,
   TRIM(r_parameter.design_item_3) AS 目標性能,
   TRIM(units.unit)                AS Unit
FROM rfl_view_tlm
LEFT JOIN r_parameter 
    ON rfl_view_tlm.r_id = r_parameter.id
LEFT JOIN units on r_parameter.unit_id = units.id
WHERE r_id IN (
    10016, 290196, 290217, 19999, 290197, 290218,
    50008, 51092, 50012, 51091, 50021, 51073,
    50022, 51074, 50023, 51075, 50024, 51076,
    50025, 51077, 50026, 51078, 50027, 51079,
    50028, 51080, 50029, 51081, 50043, 51083,
    240001, 290791, 50077, 290798, 50075, 290801,
    50019, 290804, 50084, 290838
)
ORDER BY FIELD(
    r_id,
    10016, 290196, 290217, 19999, 290197, 290218,
    50008, 51092, 50012, 51091, 50021, 51073,
    50022, 51074, 50023, 51075, 50024, 51076,
    50025, 51077, 50026, 51078, 50027, 51079,
    50028, 51080, 50029, 51081, 50043, 51083,
    240001, 290791, 50077, 290798, 50075, 290801,
    50019, 290804, 50084, 290838
);