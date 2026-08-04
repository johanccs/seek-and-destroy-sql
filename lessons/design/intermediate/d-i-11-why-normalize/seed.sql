-- One spreadsheet pretending to be a database. Every fact about a student, a
-- course, an instructor and a room is repeated on every row that mentions it,
-- which is what makes all three anomalies possible.
--
-- This table shape is the spine of modules 11-15. Do not change its columns
-- without following the change through every module that inherits it.
IF OBJECT_ID('EnrolmentSheet') IS NOT NULL DROP TABLE EnrolmentSheet;

CREATE TABLE EnrolmentSheet (
    StudentId        int            NOT NULL,
    StudentName      nvarchar(100)  NOT NULL,
    StudentEmail     nvarchar(200)  NOT NULL,
    Phone1           nvarchar(30)   NULL,
    Phone2           nvarchar(30)   NULL,
    Phone3           nvarchar(30)   NULL,
    Skills           nvarchar(400)  NULL,
    CourseCode       nvarchar(12)   NOT NULL,
    CourseTitle      nvarchar(120)  NOT NULL,
    Credits          int            NOT NULL,
    Term             nvarchar(12)   NOT NULL,
    InstructorName   nvarchar(100)  NOT NULL,
    InstructorOffice nvarchar(40)   NOT NULL,
    RoomCode         nvarchar(12)   NOT NULL,
    RoomBuilding     nvarchar(60)   NOT NULL,
    RoomCapacity     int            NOT NULL,
    Grade            nvarchar(2)    NULL,
    CONSTRAINT PK_EnrolmentSheet PRIMARY KEY (StudentId, CourseCode, Term)
);
GO

INSERT INTO EnrolmentSheet
    (StudentId, StudentName, StudentEmail, Phone1, Phone2, Phone3, Skills,
     CourseCode, CourseTitle, Credits, Term,
     InstructorName, InstructorOffice, RoomCode, RoomBuilding, RoomCapacity, Grade)
VALUES
    -- Thandi appears twice: her name and email are stored twice, which is the
    -- update anomaly waiting to happen.
    (1, 'Thandi Mokoena', 'thandi@example.ac.za', '082 555 0101', '021 555 0199', NULL, 'SQL,Python',
     'DB101', 'Database Fundamentals', 15, '2026S1', 'Dr Naidoo', 'B-214', 'R101', 'Science Block', 60, 'A'),
    (2, 'Sipho Dlamini', 'sipho@example.ac.za', '083 555 0102', NULL, NULL, 'Java',
     'DB101', 'Database Fundamentals', 15, '2026S1', 'Dr Naidoo', 'B-214', 'R101', 'Science Block', 60, 'B'),
    -- Ayesha is the only student on ST200: delete her row and the course itself
    -- vanishes from the database.
    (3, 'Ayesha Patel', 'ayesha@example.ac.za', '084 555 0103', '011 555 0177', '072 555 0155', 'SQL,R,Excel',
     'ST200', 'Statistics', 12, '2026S1', 'Prof Botha', 'C-108', 'R205', 'Maths Block', 40, 'A'),
    (1, 'Thandi Mokoena', 'thandi@example.ac.za', '082 555 0101', '021 555 0199', NULL, 'SQL,Python',
     'ST200', 'Statistics', 12, '2026S1', 'Prof Botha', 'C-108', 'R205', 'Maths Block', 40, 'B');
GO
