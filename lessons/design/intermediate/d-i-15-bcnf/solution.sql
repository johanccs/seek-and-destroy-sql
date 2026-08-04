-- The BCNF decomposition: split on the offending determinant.
--
-- InstructorName is a determinant (it determines CourseCode) but is not a
-- superkey. BCNF says every determinant must be a superkey, so InstructorName
-- becomes the key of its own table and takes what it determines with it.

IF OBJECT_ID('StudentInstructor') IS NOT NULL DROP TABLE StudentInstructor;
IF OBJECT_ID('InstructorCourse')  IS NOT NULL DROP TABLE InstructorCourse;
GO

-- InstructorName -> CourseCode. The determinant is now the key, which is
-- exactly what BCNF asks for. "Dr Naidoo teaches DB101" is stored once, so no
-- two rows can disagree about it.
CREATE TABLE InstructorCourse (
    InstructorName nvarchar(100) NOT NULL,
    CourseCode     nvarchar(12)  NOT NULL,
    CONSTRAINT PK_InstructorCourse PRIMARY KEY (InstructorName),
    CONSTRAINT FK_InstructorCourse_Course FOREIGN KEY (CourseCode) REFERENCES Course (CourseCode)
);
GO

INSERT INTO InstructorCourse (InstructorName, CourseCode)
SELECT DISTINCT InstructorName, CourseCode FROM StudentCourseInstructor;
GO

-- Which student was taught by which instructor. The course is NOT repeated
-- here -- it is reachable through the instructor, and storing it again is the
-- redundancy this whole module exists to remove.
CREATE TABLE StudentInstructor (
    StudentId      int           NOT NULL,
    InstructorName nvarchar(100) NOT NULL,
    CONSTRAINT PK_StudentInstructor PRIMARY KEY (StudentId, InstructorName),
    CONSTRAINT FK_StudentInstructor_Student FOREIGN KEY (StudentId) REFERENCES Student (StudentId),
    CONSTRAINT FK_StudentInstructor_Instructor FOREIGN KEY (InstructorName) REFERENCES InstructorCourse (InstructorName)
);
GO

INSERT INTO StudentInstructor (StudentId, InstructorName)
SELECT DISTINCT StudentId, InstructorName FROM StudentCourseInstructor;
GO

DROP TABLE StudentCourseInstructor;
GO

-- What this decomposition cost, made concrete:
--
-- (StudentId, CourseCode) -> InstructorName can no longer be enforced by
-- either table on its own. Nothing above stops a student being linked to two
-- instructors who teach the same course. Rejoin the tables and the violation
-- appears; look at either one alone and it does not.
--
-- That is the price of BCNF here: the decomposition is lossless, but it is not
-- dependency-preserving. Enforcing that rule now needs a trigger or an
-- application check. Stopping at 3NF to keep it declarative is a legitimate
-- engineering decision, not laziness.
