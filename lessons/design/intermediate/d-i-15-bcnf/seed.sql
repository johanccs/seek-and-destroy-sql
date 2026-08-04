-- Where module 14 finished, plus the table this module is about.
IF OBJECT_ID('StudentCourseInstructor') IS NOT NULL DROP TABLE StudentCourseInstructor;
IF OBJECT_ID('EnrolmentSheet') IS NOT NULL DROP TABLE EnrolmentSheet;
IF OBJECT_ID('StudentPhone')   IS NOT NULL DROP TABLE StudentPhone;
IF OBJECT_ID('StudentSkill')   IS NOT NULL DROP TABLE StudentSkill;
IF OBJECT_ID('CourseOffering') IS NOT NULL DROP TABLE CourseOffering;
IF OBJECT_ID('Instructor')     IS NOT NULL DROP TABLE Instructor;
IF OBJECT_ID('Room')           IS NOT NULL DROP TABLE Room;
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

CREATE TABLE Room (
    RoomCode     nvarchar(12) NOT NULL,
    RoomBuilding nvarchar(60) NOT NULL,
    RoomCapacity int          NOT NULL,
    CONSTRAINT PK_Room PRIMARY KEY (RoomCode)
);
GO

INSERT INTO Room (RoomCode, RoomBuilding, RoomCapacity) VALUES
    ('R101', 'Science Block', 60),
    ('R205', 'Maths Block',   40);
GO

-- Where an instructor sits. Module 14 built this.
CREATE TABLE Instructor (
    InstructorName   nvarchar(100) NOT NULL,
    InstructorOffice nvarchar(40)  NOT NULL,
    CONSTRAINT PK_Instructor PRIMARY KEY (InstructorName)
);
GO

INSERT INTO Instructor (InstructorName, InstructorOffice) VALUES
    ('Dr Naidoo',  'B-214'),
    ('Prof Botha', 'C-108'),
    ('Dr Khumalo', 'A-002');
GO

CREATE TABLE CourseOffering (
    CourseCode     nvarchar(12)  NOT NULL,
    Term           nvarchar(12)  NOT NULL,
    InstructorName nvarchar(100) NOT NULL,
    RoomCode       nvarchar(12)  NOT NULL,
    CONSTRAINT PK_CourseOffering PRIMARY KEY (CourseCode, Term),
    CONSTRAINT FK_CourseOffering_Course     FOREIGN KEY (CourseCode)     REFERENCES Course (CourseCode),
    CONSTRAINT FK_CourseOffering_Instructor FOREIGN KEY (InstructorName) REFERENCES Instructor (InstructorName),
    CONSTRAINT FK_CourseOffering_Room       FOREIGN KEY (RoomCode)       REFERENCES Room (RoomCode)
);
GO

INSERT INTO CourseOffering (CourseCode, Term, InstructorName, RoomCode) VALUES
    ('DB101', '2026S1', 'Dr Naidoo',  'R101'),
    ('ST200', '2026S1', 'Prof Botha', 'R205'),
    ('DB101', '2026S2', 'Dr Naidoo',  'R101'),
    ('ST200', '2026S2', 'Dr Khumalo', 'R101');
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

-- The table this module is about.
--
-- The department wants to record WHICH instructor taught WHICH student, under
-- two rules: a course may be taught by several instructors, and each instructor
-- teaches only one course.
--
-- The UNIQUE constraint is not decoration. It is the second candidate key, and
-- it makes the overlapping-key structure visible in the schema rather than only
-- in the prose. Both keys contain StudentId; that overlap is the whole story.
CREATE TABLE StudentCourseInstructor (
    StudentId      int           NOT NULL,
    CourseCode     nvarchar(12)  NOT NULL,
    InstructorName nvarchar(100) NOT NULL,
    CONSTRAINT PK_StudentCourseInstructor PRIMARY KEY (StudentId, CourseCode),
    CONSTRAINT UQ_StudentCourseInstructor UNIQUE (StudentId, InstructorName)
);
GO

INSERT INTO StudentCourseInstructor (StudentId, CourseCode, InstructorName) VALUES
    (1, 'DB101', 'Dr Naidoo'),
    (2, 'DB101', 'Dr Naidoo'),
    (1, 'ST200', 'Prof Botha'),
    (3, 'ST200', 'Prof Botha');
GO
