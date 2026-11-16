-- Dùng trong prj nào :
    SELECT distinct
	r_id,
    pj_code,
    drivetrain,
    archi,
    phase,
    lot,
    hierarchy,
    r_wp
FROM
    rfl_view_tlm
LEFT JOIN l_parameter on rfl_view_tlm.l_id = l_parameter.id
WHERE
	r_id IN (

	    210004,
    290130,
    290131,
    290464,
    290645,
    290647,
    290649,
    290646,
    290648,
    290650,
    290957,
    290594,
    290958,
    123123352,
    123123353,
    123123311,
    123123312
        )
;

select distinct project_code, drivetrain, architecturename, phase, lot
 from r_project_record
join project_info on r_project_record.project_id = project_info.id
WHERE
	r_parameter_id IN (

	    210004,
    290130,
    290131,
    290464,
    290645,
    290647,
    290649,
    290646,
    290648,
    290650,
    290957,
    290594,
    290958,
    123123352,
    123123353,
    123123311,
    123123312
    )
;