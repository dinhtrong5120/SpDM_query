-- Dùng trong prj nào :
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
	r_id IN (140000, 1290175, 1290320, 123123126, 1290321, 123123127
    )
;

select distinct project_code, drivetrain, architecturename, phase, lot
 from r_project_record
join project_info on r_project_record.project_id = project_info.id
WHERE
	r_parameter_id IN (140000, 1290175, 1290320, 123123126, 1290321, 123123127
    )
;