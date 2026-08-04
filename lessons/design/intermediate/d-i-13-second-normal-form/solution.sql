-- Three partial dependencies, three destinations. Each column moves to the
-- table whose key it actually depends on.

-- StudentId -> StudentName, StudentEmail
IF OBJECT_ID('Student') IS NOT NULL DROP TABLE Student;
GO

CREATE TABLE Student (
    StudentId    int           NOT NULL,
    StudentName  nvarchar(100) NOT NULL,
    StudentEmail nvarchar(200) NOT NULL,
    CONSTRAINT PK_Student PRIMARY KEY (StudentId)
);
GO

INSERT INTO Student (StudentId, StudentName, StudentEmail)
SELECT DISTINCT StudentId, StudentName, StudentEmail FROM EnrolmentSheet;
GO

-- (CourseCode, Term) -> RoomCode, InstructorName (and, for now, their details)
--
-- Note the key: an offering is a course IN A TERM. The instructor belongs here
-- and not on Course, because who teaches DB101 is a fact about the term. Module
-- 15 depends on this choice.
IF OBJECT_ID('CourseOffering') IS NOT NULL DROP TABLE CourseOffering;
GO

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
SELECT DISTINCT CourseCode, Term, InstructorName, InstructorOffice, RoomCode, RoomBuilding, RoomCapacity
FROM EnrolmentSheet;
GO

-- What is left on the enrolment is what genuinely depends on the whole key:
-- the grade a student earned in a course in a term.
ALTER TABLE EnrolmentSheet DROP COLUMN StudentName;
ALTER TABLE EnrolmentSheet DROP COLUMN StudentEmail;
ALTER TABLE EnrolmentSheet DROP COLUMN InstructorName;
ALTER TABLE EnrolmentSheet DROP COLUMN InstructorOffice;
ALTER TABLE EnrolmentSheet DROP COLUMN RoomCode;
ALTER TABLE EnrolmentSheet DROP COLUMN RoomBuilding;
ALTER TABLE EnrolmentSheet DROP COLUMN RoomCapacity;
GO

ALTER TABLE EnrolmentSheet
    ADD CONSTRAINT FK_EnrolmentSheet_Student
    FOREIGN KEY (StudentId) REFERENCES Student (StudentId);
GO

-- The child tables from module 12 can finally be anchored to a real student.
ALTER TABLE StudentPhone
    ADD CONSTRAINT FK_StudentPhone_Student
    FOREIGN KEY (StudentId) REFERENCES Student (StudentId);

ALTER TABLE StudentSkill
    ADD CONSTRAINT FK_StudentSkill_Student
    FOREIGN KEY (StudentId) REFERENCES Student (StudentId);
GO
