-- Where module 12 finished: the repeating groups are gone, so StudentPhone and
-- StudentSkill exist and EnrolmentSheet has no Phone1/2/3 or Skills columns.
--
-- What remains on EnrolmentSheet is the 2NF problem: the key is
-- (StudentId, CourseCode, Term), and several columns depend on only part of it.
IF OBJECT_ID('EnrolmentSheet') IS NOT NULL DROP TABLE EnrolmentSheet;
IF OBJECT_ID('StudentPhone')   IS NOT NULL DROP TABLE StudentPhone;
IF OBJECT_ID('StudentSkill')   IS NOT NULL DROP TABLE StudentSkill;
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

CREATE TABLE StudentPhone (
    StudentId int          NOT NULL,
    Phone     nvarchar(30) NOT NULL,
    CONSTRAINT PK_StudentPhone PRIMARY KEY (StudentId, Phone)
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
    CONSTRAINT PK_StudentSkill PRIMARY KEY (StudentId, Skill)
);
GO

INSERT INTO StudentSkill (StudentId, Skill) VALUES
    (1, 'SQL'), (1, 'Python'),
    (2, 'Java'),
    (3, 'SQL'), (3, 'R'), (3, 'Excel');
GO

CREATE TABLE EnrolmentSheet (
    StudentId        int            NOT NULL,
    StudentName      nvarchar(100)  NOT NULL,
    StudentEmail     nvarchar(200)  NOT NULL,
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
    (StudentId, StudentName, StudentEmail, CourseCode, Term,
     InstructorName, InstructorOffice, RoomCode, RoomBuilding, RoomCapacity, Grade)
VALUES
    (1, 'Thandi Mokoena', 'thandi@example.ac.za', 'DB101', '2026S1', 'Dr Naidoo', 'B-214', 'R101', 'Science Block', 60, 'A'),
    (2, 'Sipho Dlamini',  'sipho@example.ac.za',  'DB101', '2026S1', 'Dr Naidoo', 'B-214', 'R101', 'Science Block', 60, 'B'),
    (3, 'Ayesha Patel',   'ayesha@example.ac.za', 'ST200', '2026S1', 'Prof Botha', 'C-108', 'R205', 'Maths Block',  40, 'A'),
    (1, 'Thandi Mokoena', 'thandi@example.ac.za', 'ST200', '2026S1', 'Prof Botha', 'C-108', 'R205', 'Maths Block',  40, 'B');
GO
