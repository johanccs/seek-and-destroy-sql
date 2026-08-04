-- Where module 11 finished: Course has its own table, and EnrolmentSheet no
-- longer carries CourseTitle or Credits.
--
-- What is left is the student side, and it is a mess of a different kind:
-- three numbered phone columns and one comma-separated Skills column.
IF OBJECT_ID('EnrolmentSheet') IS NOT NULL DROP TABLE EnrolmentSheet;
IF OBJECT_ID('Course') IS NOT NULL DROP TABLE Course;
GO

CREATE TABLE Course (
    CourseCode  nvarchar(12)  NOT NULL,
    CourseTitle nvarchar(120) NOT NULL,
    Credits     int           NOT NULL,
    CONSTRAINT PK_Course PRIMARY KEY (CourseCode)
);
GO

INSERT INTO Course (CourseCode, CourseTitle, Credits) VALUES
    ('DB101', 'Database Fundamentals', 15),
    ('ST200', 'Statistics',            12);
GO

CREATE TABLE EnrolmentSheet (
    StudentId        int            NOT NULL,
    StudentName      nvarchar(100)  NOT NULL,
    StudentEmail     nvarchar(200)  NOT NULL,
    Phone1           nvarchar(30)   NULL,
    Phone2           nvarchar(30)   NULL,
    Phone3           nvarchar(30)   NULL,
    Skills           nvarchar(400)  NULL,
    CourseCode       nvarchar(12)   NOT NULL,
    Term             nvarchar(12)   NOT NULL,
    InstructorName   nvarchar(100)  NOT NULL,
    InstructorOffice nvarchar(40)   NOT NULL,
    RoomCode         nvarchar(12)   NOT NULL,
    RoomBuilding     nvarchar(60)   NOT NULL,
    RoomCapacity     int            NOT NULL,
    Grade            nvarchar(2)    NULL,
    CONSTRAINT PK_EnrolmentSheet PRIMARY KEY (StudentId, CourseCode, Term),
    CONSTRAINT FK_EnrolmentSheet_Course FOREIGN KEY (CourseCode) REFERENCES Course (CourseCode)
);
GO

INSERT INTO EnrolmentSheet
    (StudentId, StudentName, StudentEmail, Phone1, Phone2, Phone3, Skills,
     CourseCode, Term, InstructorName, InstructorOffice, RoomCode, RoomBuilding, RoomCapacity, Grade)
VALUES
    (1, 'Thandi Mokoena', 'thandi@example.ac.za', '082 555 0101', '021 555 0199', NULL, 'SQL,Python',
     'DB101', '2026S1', 'Dr Naidoo', 'B-214', 'R101', 'Science Block', 60, 'A'),
    (2, 'Sipho Dlamini', 'sipho@example.ac.za', '083 555 0102', NULL, NULL, 'Java',
     'DB101', '2026S1', 'Dr Naidoo', 'B-214', 'R101', 'Science Block', 60, 'B'),
    -- Ayesha has all three phone slots used. There is nowhere to put a fourth.
    (3, 'Ayesha Patel', 'ayesha@example.ac.za', '084 555 0103', '011 555 0177', '072 555 0155', 'SQL,R,Excel',
     'ST200', '2026S1', 'Prof Botha', 'C-108', 'R205', 'Maths Block', 40, 'A'),
    (1, 'Thandi Mokoena', 'thandi@example.ac.za', '082 555 0101', '021 555 0199', NULL, 'SQL,Python',
     'ST200', '2026S1', 'Prof Botha', 'C-108', 'R205', 'Maths Block', 40, 'B');
GO
