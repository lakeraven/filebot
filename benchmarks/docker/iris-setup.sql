-- FileBot Benchmark IRIS Database Setup
-- Creates sample Patient table and data for reproducible benchmarking

-- Switch to USER namespace for benchmarking
use USER;

-- Create Patient table for FileBot vs FileMan benchmarking
CREATE TABLE Patient (
    ID INTEGER PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    DateOfBirth DATE,
    SSN VARCHAR(11),
    Address VARCHAR(200),
    PhoneNumber VARCHAR(20),
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert standardized test data for reproducible benchmarks
INSERT INTO Patient (ID, Name, DateOfBirth, SSN, Address, PhoneNumber) VALUES 
(1, 'BENCHMARK,PATIENT ONE', '1980-01-15', '123-45-6789', '123 Main St, Boston MA 02101', '617-555-0001'),
(2, 'TEST,PATIENT TWO', '1975-03-22', '234-56-7890', '456 Oak Ave, Cambridge MA 02139', '617-555-0002'),
(3, 'SAMPLE,PATIENT THREE', '1990-07-10', '345-67-8901', '789 Pine Rd, Somerville MA 02144', '617-555-0003'),
(4, 'DEMO,PATIENT FOUR', '1985-12-05', '456-78-9012', '321 Elm St, Brookline MA 02446', '617-555-0004'),
(5, 'VERIFY,PATIENT FIVE', '1992-09-18', '567-89-0123', '654 Maple Dr, Newton MA 02458', '617-555-0005'),
(6, 'CONTROL,PATIENT SIX', '1988-04-30', '678-90-1234', '987 Cedar Ln, Watertown MA 02472', '617-555-0006'),
(7, 'STANDARD,PATIENT SEVEN', '1983-11-12', '789-01-2345', '147 Birch St, Arlington MA 02476', '617-555-0007'),
(8, 'BASELINE,PATIENT EIGHT', '1991-06-25', '890-12-3456', '258 Spruce Ave, Medford MA 02155', '617-555-0008'),
(9, 'REFERENCE,PATIENT NINE', '1987-08-17', '901-23-4567', '369 Willow Way, Malden MA 02148', '617-555-0009'),
(10, 'CANONICAL,PATIENT TEN', '1994-02-14', '012-34-5678', '741 Poplar Pl, Everett MA 02149', '617-555-0010');

-- Create indexes for realistic performance testing
-- These indexes simulate real-world database performance characteristics
CREATE INDEX IDX_Patient_Name ON Patient(Name);
CREATE INDEX IDX_Patient_SSN ON Patient(SSN);
CREATE INDEX IDX_Patient_DOB ON Patient(DateOfBirth);
CREATE INDEX IDX_Patient_Phone ON Patient(PhoneNumber);

-- Create additional patients for search diversity testing
INSERT INTO Patient (ID, Name, DateOfBirth, SSN) 
SELECT 
    ROW_NUMBER() OVER () + 100,
    'TEST,SEARCH ' || ROW_NUMBER() OVER (),
    DATE('1970-01-01') + (ROW_NUMBER() OVER () * 365) DAY,
    LPAD(ROW_NUMBER() OVER (), 3, '0') || '-' || LPAD(ROW_NUMBER() OVER (), 2, '0') || '-' || LPAD(ROW_NUMBER() OVER (), 4, '0')
FROM (
    SELECT 1 as dummy UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL 
    SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL 
    SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL 
    SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15 UNION ALL 
    SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL SELECT 20
) numbers;

-- Update statistics for optimal query planning
UPDATE STATISTICS Patient;

-- Verify setup completed successfully
SELECT 'FileBot Benchmark Database Setup Complete' as Status,
       COUNT(*) as PatientCount,
       MIN(ID) as MinPatientID,
       MAX(ID) as MaxPatientID
FROM Patient;

-- Display sample of test data for verification
SELECT 'Sample Patient Data:' as Info, ID, Name, DateOfBirth, SSN
FROM Patient 
WHERE ID <= 5
ORDER BY ID;