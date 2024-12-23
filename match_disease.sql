DELETE FROM Disease
insert into major (major_id, major_name) values (1, 'Cardiology');
insert into major (major_id, major_name) values (2, 'Neurology');
insert into major (major_id, major_name) values (3, 'Dermatology');
insert into major (major_id, major_name) values (4, 'Pediatrics');
insert into major (major_id, major_name) values (5, 'Oncology');
insert into major (major_id, major_name) values (6, 'Gynecology');
insert into major (major_id, major_name) values (7, 'Orthopedics');
insert into major (major_id, major_name) values (8, 'Urology');
insert into major (major_id, major_name) values (9, 'Psychiatry');
insert into major (major_id, major_name) values (10, 'Endocrinology');


INSERT INTO Disease (disease_id, disease_name, major_id)
VALUES 
    (1, 'Flu', 1),
    (2, 'Covid-19', 2),
    (3, 'Diabetes', 3),
    (4, 'Hypertension', 4),
    (5, 'Asthma', 5);

INSERT INTO Symptom (symptom_id, symptom_name, disease_id)
VALUES 
    -- Symptoms for Flu
    (1, 'Fever', 1),
    (2, 'Cough', 1),
    (3, 'Body Ache', 1),

    -- Symptoms for Covid-19
    (1, 'Fever', 2),
    (2, 'Cough', 2),
    (4, 'Loss of Smell', 2),
    (5, 'Shortness of Breath', 2),

    -- Symptoms for Diabetes
    (6, 'Increased Thirst', 3),
    (7, 'Frequent Urination', 3),
    (8, 'Fatigue', 3),

    -- Symptoms for Hypertension
    (9, 'Headache', 4),
    (10, 'Chest Pain', 4),
    (11, 'Blurred Vision', 4),

    -- Symptoms for Asthma
    (5, 'Shortness of Breath', 5),
    (12, 'Wheezing', 5),
    (13, 'Chest Tightness', 5);

-- Show disease and matched symptom
SELECT d.disease_name AS Disease, array_agg(ds.symptom_name) AS Symptom
FROM Disease d
JOIN Symptom ds ON d.disease_id = ds.disease_id
GROUP BY d.disease_name

-- Find most matched disease

SELECT d.disease_name, COUNT(s.symptom_id) AS num_matched_symptoms 
FROM disease d  
JOIN Symptom s ON d.disease_id = s.disease_id 
WHERE s.symptom_id IN (7,8, 9,10)
GROUP BY d.disease_name
ORDER BY num_matched_symptoms DESC


CREATE OR REPLACE FUNCTION find_suitable_doctor_with_major (major VARCHAR)
RETURNS TABLE (
	doctor_id INT,
	doctor_first_name VARCHAR,
	doctor_last_name VARCHAR,
	doctor_email VARCHAR,
	gender VARCHAR,
	doctor_dob DATE,
	years_of_exp INT,
	roles VARCHAR,
	major_name VARCHAR,
	workplace VARCHAR,
	slot_begin_time TIMESTAMP,
	slot_end_time TIMESTAMP,
	available VARCHAR
)
AS $$ 
BEGIN
	RETURN QUERY
	SELECT d.doctor_id, d.doctor_first_name, d.doctor_last_name,d.doctor_email,
		   d.gender, d.doctor_dob, d.years_of_exp, d.roles, m.major_name, d.workplace,
		   ds.slot_begin_time, ds.slot_end_time, ds.available
	FROM doctors d
	JOIN major m ON m.major_id = d.major_id
	JOIN doctor_schedule ds ON ds.doctor_id = d.doctor_id
	WHERE m.major_name = major AND ds.available = 'Yes'
	ORDER BY slot_begin_time ASC;
END;
$$ LANGUAGE plpgsql;


SELECT * FROM find_suitable_doctor_with_major ('Neurology');

SELECT * FROM major;


