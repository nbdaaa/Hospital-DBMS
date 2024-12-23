													-- TABLES -- 
-- DROP TABLE major;
CREATE TABLE major (
	major_id INT,
	major_name VARCHAR NOT NULL,
  	CONSTRAINT major_pkey PRIMARY KEY(major_id)
);

--DROP TABLE doctors;
CREATE TABLE doctors(
	doctor_id INT,
	doctor_first_name VARCHAR NOT NULL,
	doctor_last_name VARCHAR NOT NULL,
	doctor_email VARCHAR NOT NULL,
	gender VARCHAR NOT NULL,
	doctor_dob DATE NOT NULL,
	years_of_exp INT NOT NULL,
	roles VARCHAR NOT NULL,
	major_id INT NOT NULL,
	workplace VARCHAR NOT NULL,
	CONSTRAINT doctor_pkey PRIMARY KEY(doctor_id),
	CONSTRAINT doctor_major_fkey FOREIGN KEY (major_id) REFERENCES major(major_id) ON DELETE CASCADE,
	CONSTRAINT check_gender CHECK (gender = 'F' or gender = 'M')
);

-- DROP TABLE disease
CREATE TABLE Disease (
    disease_id SERIAL PRIMARY KEY,
    major_id INT NOT NULL,
    disease_name VARCHAR NOT NULL,
    CONSTRAINT disease_major_fkey FOREIGN KEY (major_id) REFERENCES major(major_id) ON DELETE CASCADE
);


-- DROP TABLE disease_symptoms
CREATE TABLE Symptom (
    symptom_id INT,
    symptom_name VARCHAR(100) NOT NULL,
    disease_id INT,
    FOREIGN KEY(disease_id) REFERENCES Disease(disease_id),
    PRIMARY KEY(symptom_id, disease_id)
);


--DROP TABLE doctor_schedule
CREATE TABLE doctor_schedule (
	slot_id INT, 
	slot_begin_time TIMESTAMP NOT NULL,
  	slot_end_time TIMESTAMP NOT NULL,
	doctor_id INT NOT NULL,
	nums_of_patient INT,
  	available VARCHAR NOT NULL,
	CONSTRAINT doctor_schedule_pkey PRIMARY KEY (slot_id, doctor_id),
	CONSTRAINT doctor_schedule_doctor_fkey FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE CASCADE,
	CONSTRAINT check_time CHECK (slot_begin_time < slot_end_time),
	CONSTRAINT check_available CHECK (available = 'Yes' or available = 'No')
);

--DROP TABLE patients;
CREATE TABLE patients(
	patient_id INT,
	patient_first_name VARCHAR NOT NULL,
	patient_last_name VARCHAR NOT NULL,
	patient_dob DATE NOT NULL,
	age INT NOT NULL,
	gender VARCHAR NOT NULL,
	address VARCHAR NOT NULL,
	CONSTRAINT patient_pkey PRIMARY KEY (patient_id),
	CONSTRAINT check_gender CHECK (gender = 'F' or gender = 'M')
);

--SELECT * FROM doctor_slots
--DROP TABLE appointments
CREATE TABLE appointments(
	slot_id INT,
	patient_id INT,
	doctor_id INT,
	CONSTRAINT appointment_pkey PRIMARY KEY (slot_id, patient_id, doctor_id),
	CONSTRAINT appointment_slot_fkey FOREIGN KEY (slot_id, doctor_id) REFERENCES doctor_schedule(slot_id, doctor_id) ON DELETE CASCADE,
	CONSTRAINT appointment_patient_fkey FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE
);

--DROP TABLE record
CREATE TABLE record (
	slot_id INT,
	doctor_id INT,
	patient_id INT,
	bill INT NOT NULL,
	patient_review INT,
	symptoms VARCHAR NOT NULL,
	disease VARCHAR NOT NULL,
  	treatment VARCHAR,
	type_of_operation VARCHAR,
  	prescription VARCHAR,
	doctor_note VARCHAR,
	medical_condition_over_5 INT NOT NULL,
	begin_time TIMESTAMP,
	end_time TIMESTAMP,
	CONSTRAINT record_pkey PRIMARY KEY (slot_id, patient_id, doctor_id),
	CONSTRAINT record_appointment_fkey FOREIGN KEY (slot_id, patient_id, doctor_id) REFERENCES appointments(slot_id, patient_id, doctor_id) ON DELETE CASCADE
);

--DROP TABLE medical_history;   
CREATE TABLE medical_history (
    patient_id INT,
    disease VARCHAR NOT NULL,
    prescription VARCHAR,
    diagnosis_date DATE NOT NULL,
	cured_date DATE,
	number_of_app INT DEFAULT 0,
    CONSTRAINT history_patient_fkey FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE
);

													-- INDEX --


CREATE INDEX symptom_name ON symptoms USING HASH(symptoms_name)

-- CREATE INDEX disease_name 

CREATE INDEX doctor_info ON doctors(doctor_first_name, doctor_last_name, years_of_exp, roles, major_id)

CREATE INDEX doctor_schedule_time ON doctor_schedule(slot_begin_time, slot_end_time);

CREATE INDEX patients_info ON patients(patient_first_name, patient_last_name, age, patient_dob);

CREATE INDEX medical_history_date ON medical_history(disease, diagnosis_date, cured_date);




													-- TRIGGER --

-- Trigger để thay đổi trạng thái của slot sau khi khách hàng đã book appointment --
CREATE OR REPLACE FUNCTION public.update_available_slots()
RETURNS trigger 
AS $$
BEGIN 
	UPDATE doctor_schedule
	SET available = 'No' 
	WHERE slot_id = NEW.slot_id;
	RETURN NEW;
END 
$$ language plpgsql; 

CREATE OR REPLACE TRIGGER available_slots 
AFTER INSERT ON appointments
FOR EACH ROW
EXECUTE PROCEDURE public.update_available_slots()


--------------------------------------------------------------

-- Trigger để thay đổi trạng thái của slot sau khi khách hàng hủy appointment --
CREATE OR REPLACE FUNCTION public.cancel_appointment() 
RETURNS trigger
AS $$
BEGIN 
    UPDATE doctor_schedule
	SET available = 'Yes'
	WHERE slot_id = OLD.slot_id;
	RETURN NEW;
END;
$$ language plpgsql;

CREATE OR REPLACE TRIGGER cancel_appointments 
AFTER DELETE ON appointments
FOR EACH ROW
EXECUTE PROCEDURE public.cancel_appointment()



--------------------------------------------------------------

-- Trigger để thêm thông tin của appointment vào tiền sử bệnh án (medical_history) của khách hàng --

CREATE OR REPLACE FUNCTION public.update_medical_history_function() 
RETURNS trigger 
AS $$ 
BEGIN 
	-- Check if exists disease
	IF EXISTS(
		SELECT 1 
		FROM medical_history 
		WHERE disease = NEW.disease AND patient_id = NEW.patient_id
	) THEN
	-- Check if this disease had been cured ?
	IF EXISTS(
		SELECT 1 
		FROM medical_history 
		WHERE disease = NEW.disease  AND cured_date IS NULL AND patient_id = NEW.patient_id
	) THEN 
		-- update prescriptions and number of appointments. 
		UPDATE medical_history 
 		SET prescription = CONCAT(NEW.prescription, ', ', prescription),
			number_of_app = number_of_app + 1
		WHERE disease = NEW.disease  AND cured_data IS NULL AND patient_id = NEW.patient_id; 
		-- update cured date
		UPDATE medical_history 
		SET cured_date = DATE(NEW.end_time)
		WHERE medical_condition_over_5 = 5 AND disease = NEW.disease  AND cured_data IS NULL AND patient_id = NEW.patient_id; 
	--- If the disease had been cured in the past, then create a new record (chua thong tin tai phat cua benh)
	ELSE
		INSERT INTO medical_history(patient_id, disease, prescription, diagnosis_date)
		VALUES (NEW.patient_id, NEW.disease, NEW.prescription, DATE(NEW.begin_time));		
		--update the number of app = the order of the latest appointment + 1
		UPDATE medical_history 
		SET number_of_app = ( 
			SELECT COALESCE(MAX(number_of_app), 0) 
			FROM medical_history 
			WHERE disease = NEW.disease AND cured_date IS NOT NULL AND patient_id = NEW.patient_id
		) + 1
		WHERE disease = NEW.disease  AND cured_data IS NULL AND patient_id = NEW.patient_id; 
		-- update cured date if medical_condition_over_5 = 5 (doctor's evaluation)
		UPDATE medical_history 
		SET cured_date = DATE(NEW.end_time)
		WHERE medical_condition_over_5 = 5 AND disease = NEW.disease  AND cured_data IS NULL AND patient_id = NEW.patient_id; 
	END IF; 
	-- Case: New disease
	ELSE
		INSERT INTO medical_history(patient_id, disease, prescription, diagnosis_date, number_of_app)
		VALUES (NEW.patient_id, NEW.disease, NEW.prescription, DATE(NEW.begin_time));		

		UPDATE medical_history 
		SET cured_date = DATE(NEW.end_time)
		WHERE medical_condition_over_5 = 5 AND disease = NEW.disease  AND cured_data IS NULL AND patient_id = NEW.patient_id; 
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE TRIGGER update_medical_history 
AFTER UPDATE OF begin_time,end_time ON record
FOR EACH ROW 
EXECUTE PROCEDURE public.update_medical_history_function ()

--------------------------------------------------------------

-- Trigger tự động cập nhật thời gian của cuộc hẹn(appointment) theo thời gian của lịch làm việc bác sĩ đã đặt trước đấy --

CREATE OR REPLACE FUNCTION public.update_time_record ()
RETURNS trigger
AS $$
DECLARE begintime TIMESTAMP;
		endtime TIMESTAMP;
BEGIN
	begintime := (SELECT ds.slot_begin_time FROM doctor_schedule ds WHERE ds.slot_id = NEW.slot_id);
	endtime := (SELECT ds.slot_end_time FROM doctor_schedule ds WHERE ds.slot_id = NEW.slot_id);
	UPDATE record
	SET begin_time = begintime,
		end_time = endtime
	WHERE slot_id = NEW.slot_id;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER update_time_record
AFTER INSERT ON record
FOR EACH ROW
EXECUTE PROCEDURE public.update_time_record ()
----------------------------------------------------


															-- FUNCTION --


-- Function có tác dụng tìm thông tin bệnh án của bệnh nhân --

CREATE OR REPLACE FUNCTION find_patient_health_record(patientfirstname VARCHAR, patientlastname VARCHAR, dob DATE)
RETURNS TABLE (
	patient_id INT,
	patient_first_name VARCHAR,
	patient_last_name VARCHAR,
	patient_dob DATE,
	age INT,
	gender VARCHAR,
	disease VARCHAR,
	prescription VARCHAR,
    diagnosis_date DATE,
	cured_date DATE,
	number_of_app INT
)
AS $$
BEGIN 
    RETURN QUERY
	SELECT p.patient_id, p.patient_first_name, p.patient_last_name, p.patient_dob, p.age,
		   p.gender, m.disease, m.prescription, m.diagnosis_date, m.cured_date, m.number_of_app
	FROM patients p
	JOIN medical_history m ON p.patient_id = m.patient_id
	WHERE p.patient_first_name = patientfirstname AND
	      p.patient_last_name = patientlastname AND
		  p.patient_dob = dob;
END;
$$ LANGUAGE plpgsql;
-- DROP FUNCTION find_patient_health_record


-- Function có tác dụng tìm bác sĩ và các slot available cho bệnh nhân có dấu hiệu (symptoms) phù hợp với major của bác sĩ --
-- DROP FUNCTION find_suitable_doctor_with_major

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

-- Function có tác dụng đặt lịch khám cho bệnh nhân có patient_id bác sĩ và thời gian khám --

CREATE OR REPLACE FUNCTION booking_doctor (patientid int, doctorid int, begintime timestamp, endtime timestamp) 
RETURNS VOID
AS $$
DECLARE ans INT;
BEGIN 
	ans := (SELECT slot_id FROM doctor_schedule WHERE slot_end_time = endtime AND doctor_id = doctorid);
	INSERT INTO appointments VALUES (ans, patientid, doctorid);
	RAISE NOTICE 'Booking success';
END;
$$ language plpgsql;
-- DROP FUNCTION booking_doctor(patientid int, doctorid int, begintime timestamp, endtime timestamp)

-- Function có tác dụng tìm lịch làm việc của bác sĩ với thời gian cho trước --

CREATE OR REPLACE FUNCTION find_slots(endtime TIMESTAMP, doctorid INT)
RETURNS INT
AS $$
DECLARE ans INT;
BEGIN 
	ans :=
    (SELECT slot_id 
	FROM doctor_schedule
	WHERE slot_end_time = endtime AND doctor_id = doctorid);
	RETURN ans;
END;
$$ language plpgsql;

-- DROP FUNCTION find_diseases_by_symptoms(symptom_names TEXT)

-- Find most matched disease with symptoms
CREATE OR REPLACE FUNCTION find_diseases_by_symptoms(symptom_names TEXT)
RETURNS TABLE (
	major_name VARCHAR, 
    disease_name VARCHAR,
    symptoms VARCHAR[],
    num_matched_symptoms BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH symptom_ids AS (
        SELECT symptom_id 
        FROM Symptom 
        WHERE symptom_name = ANY(string_to_array(symptom_names, ','))
    )
    SELECT 
		m.major_name,
        d.disease_name,
        array_agg(s.symptom_name),
        COUNT(s.symptom_id)::BIGINT
    FROM disease d
    JOIN Symptom s ON d.disease_id = s.disease_id
	JOIN major m ON d.major_id = m.major_id
    WHERE s.symptom_id IN (SELECT symptom_id FROM symptom_ids)
    GROUP BY d.disease_name, m.major_name
    ORDER BY COUNT(s.symptom_id) DESC;
END;
$$ LANGUAGE plpgsql;

															-- Privilege --

--admin--
CREATE USER adminstrator WITH PASSWORD 'admin1'
GRANT CONNECT ON DATABASE dblabproject TO adminstrator
REVOKE CONNECT ON DATABASE dblabproject FROM adminstrator
GRANT SELECT ON ALL TABLES IN SCHEMA public TO adminstrator
REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM adminstrator

--idadmin--
CREATE USER itadmin SUPERUSER PASSWORD 'itadmin1';

--patient--
CREATE USER patient WITH PASSWORD 'patient1';
GRANT CONNECT ON DATABASE dblabproject TO patient;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO patient;

--doctor--
CREATE USER doctor WITH PASSWORD 'doctor1';
GRANT CONNECT ON DATABASE dblabproject TO doctor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO doctor;

												
						
																-- Demo --
-- Show disease and matched symptom
SELECT m.major_name AS Major, d.disease_name AS Disease, array_agg(ds.symptom_name) AS Symptom 
FROM Disease d
JOIN Symptom ds ON d.disease_id = ds.disease_id
JOIN major m ON m.major_id = d.major_id
GROUP BY d.disease_name, m.major_name

-- Find most matched disease
SELECT * FROM find_diseases_by_symptoms('Headache,Fever,Cough');

-- example demo: patient_id = 15

-- Find appopriate doctor --
SELECT * FROM find_suitable_doctor_with_major ('Neurology');

-- Booking doctor --
SELECT public.booking_doctor(15, 125, '2023-02-12 11:00:00', '2023-02-12 12:00:00')

-- After the appointment, there is a record --
insert into record (slot_id, doctor_id, patient_id, bill, patient_review, symptoms, disease, treatment, type_of_operation, prescription, doctor_note, medical_condition_over_5) 
values (find_slots('2023-02-12 12:00:00', 125), 125, 15, 6640, 4, 'Headaches', 'Pneumonia', 'Pain medications', 'Hysterectomy', 'Pantoprazole', 'Patient is recovering well.', 5);

-- Check the medical_history --
SELECT * FROM find_patient_health_record('Benoite', 'Dunsmore', '1983-11-09') 

-- If incase the patient are cured but he relapses(tái phát), the medical_history will be updated for each relapse --
SELECT public.booking_doctor(15, 36, '2023-02-16 10:00:00', '2023-02-16 11:00:00');
SELECT public.booking_doctor(15, 11, '2023-02-25 12:00:00', '2023-02-25 13:00:00');
SELECT public.booking_doctor(15, 52, '2023-02-25 15:00:00', '2023-02-25 16:00:00');
SELECT public.booking_doctor(15, 78, '2023-03-09 15:00:00', '2023-03-09 16:00:00');

insert into record (slot_id, doctor_id, patient_id, bill, patient_review, symptoms, disease, treatment, type_of_operation, prescription, doctor_note, medical_condition_over_5) 
values (find_slots('2023-02-16 11:00:00', 36), 36, 15, 664, 3, 'Headaches', 'Pneumonia', 'Pills', 'Hysterectomy', 'Pills', 'Patient is recovering well.', 1);
insert into record (slot_id, doctor_id, patient_id, bill, patient_review, symptoms, disease, treatment, type_of_operation, prescription, doctor_note, medical_condition_over_5) 
values (find_slots('2023-02-25 13:00:00', 11), 11, 15, 640, 5, 'Headaches', 'Pneumonia', 'Pain medications', 'Hysterectomy', 'Pantoprazole', 'Patient is recovering well.', 2);
insert into record (slot_id, doctor_id, patient_id, bill, patient_review, symptoms, disease, treatment, type_of_operation, prescription, doctor_note, medical_condition_over_5) 
values (find_slots('2023-02-25 16:00:00', 52), 52, 15, 40, 1, 'Headaches', 'Pneumonia', 'Drink water', 'Hysterectomy', 'Pills', 'Patient is recovering well.', 3);
insert into record (slot_id, doctor_id, patient_id, bill, patient_review, symptoms, disease, treatment, type_of_operation, prescription, doctor_note, medical_condition_over_5) 
values (find_slots('2023-03-09 16:00:00', 78), 78, 15, 100, 2, 'Headaches', 'Pneumonia', 'Pills', 'Hysterectomy', 'Drink water', 'Patient is recovering well.', 5);

-- Finally, the medical_history after several times having appointments --
SELECT * FROM find_patient_health_record('Benoite', 'Dunsmore', '1983-11-09');
