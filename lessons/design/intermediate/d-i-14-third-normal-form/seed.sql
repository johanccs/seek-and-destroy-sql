-- Where module 13 finished: Student and CourseOffering exist, and EnrolmentSheet
-- is down to (StudentId, CourseCode, Term, Grade).
--
-- Both remaining problems are now inside CourseOffering, and they share a shape.
IF OBJECT_ID('EnrolmentSheet') IS NOT NULL DROP TABLE EnrolmentSheet;
IF OBJECT_ID('StudentPhone')   IS NOT NULL DROP TABLE StudentPhone;
IF OBJECT_ID('StudentSkill')   IS NOT NULL DROP TABLE StudentSkill;
IF OBJECT_ID('CourseOffering') IS NOT NULL DROP TABLE CourseOffering;
IF OBJECT_ID('Student')        IS NOT NULL DROP TABLE Student;
IF OBJECT_ID('Course')         IS NOT NULL DROP TABLE Course;
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

CREATE TABLE Student (
    StudentId    int           NOT NULL,
    StudentName  nvarchar(100) NOT NULL,
    StudentEmail nvarchar(200) NOT NULL,
    CONSTRAINT PK_Student PRIMARY KEY (StudentId)
);
GO

INSERT INTO Student (StudentId, StudentName, StudentEmail) VALUES
    (1, 'Thandi Mokoena', 'thandi@example.ac.za'),
    (2, 'Sipho Dlamini',  'sipho@example.ac.za'),
    (3, 'Ayesha Patel',   'ayesha@example.ac.za');
GO

CREATE TABLE StudentPhone (
    StudentId int          NOT NULL,
    Phone     nvarchar(30) NOT NULL,
    CONSTRAINT PK_StudentPhone PRIMARY KEY (StudentId, Phone),
    CONSTRAINT FK_StudentPhone_Student FOREIGN KEY (StudentId) REFERENCES Student (StudentId)
);
GO

INSERT INTO StudentPhone (StudentId, Phone) VALUES
    (1, '082 555 0101'), (1, '021 555 0199'),
    (2, '083 555 0102'),
    (3, '084 555 0103'), (3, '011 555 0177'), (3, '072 555 0155');
GO

CREATE TABLE StudentSkill (
    StudentId int          NOT NULL,
    Skill     nvarchar(60) NOT NULL,
    CONSTRAINT PK_StudentSkill PRIMARY KEY (StudentId, Skill),
    CONSTRAINT FK_StudentSkill_Student FOREIGN KEY (StudentId) REFERENCES Student (StudentId)
);
GO

INSERT INTO StudentSkill (StudentId, Skill) VALUES
    (1, 'SQL'), (1, 'Python'),
    (2, 'Java'),
    (3, 'SQL'), (3, 'R'), (3, 'Excel');
GO

-- The 3NF problem lives here. RoomCode and InstructorName depend on the key,
-- but RoomBuilding depends on RoomCode and InstructorOffice depends on
-- InstructorName -- neither of which is the key.
--
-- Two extra offerings are seeded so the redundancy is visible rather than
-- merely asserted: R101 appears three times, Dr Naidoo twice.
CREATE TABLE CourseOffering (
    CourseCode       nvarchar(12)  NOT NULL,
    Term             nvarchar(12)  NOT NULL,
    InstructorName   nvarchar(100) NOT NULL,
    InstructorOffice nvarchar(40)  NOT NULL,
    RoomCode         nvarchar(12)  NOT NULL,
    RoomBuilding     nvarchar(60)  NOT NULL,
    RoomCapacity     int           NOT NULL,
    CONSTRAINT PK_CourseOffering PRIMARY KEY (CourseCode, Term),
    CONSTRAINT FK_CourseOffering_Course FOREIGN KEY (CourseCode) REFERENCES Course (CourseCode)
);
GO

INSERT INTO CourseOffering
    (CourseCode, Term, InstructorName, InstructorOffice, RoomCode, RoomBuilding, RoomCapacity)
VALUES
    ('DB101', '2026S1', 'Dr Naidoo',  'B-214', 'R101', 'Science Block', 60),
    ('ST200', '2026S1', 'Prof Botha', 'C-108', 'R205', 'Maths Block',   40),
    ('DB101', '2026S2', 'Dr Naidoo',  'B-214', 'R101', 'Science Block', 60),
    ('ST200', '2026S2', 'Dr Khumalo', 'A-002', 'R101', 'Science Block', 60);
GO

CREATE TABLE EnrolmentSheet (
    StudentId  int          NOT NULL,
    CourseCode nvarchar(12) NOT NULL,
    Term       nvarchar(12) NOT NULL,
    Grade      nvarchar(2)  NULL,
    CONSTRAINT PK_EnrolmentSheet PRIMARY KEY (StudentId, CourseCode, Term),
    CONSTRAINT FK_EnrolmentSheet_Student FOREIGN KEY (StudentId) REFERENCES Student (StudentId),
    CONSTRAINT FK_EnrolmentSheet_Course  FOREIGN KEY (CourseCode) REFERENCES Course (CourseCode)
);
GO

INSERT INTO EnrolmentSheet (StudentId, CourseCode, Term, Grade) VALUES
    (1, 'DB101', '2026S1', 'A'),
    (2, 'DB101', '2026S1', 'B'),
    (3, 'ST200', '2026S1', 'A'),
    (1, 'ST200', '2026S1', 'B');
GO
