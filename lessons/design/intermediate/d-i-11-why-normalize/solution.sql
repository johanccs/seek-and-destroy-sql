-- The smallest decomposition that makes the insert anomaly impossible: a course
-- gets its own table, so it can exist before anyone enrols on it.
--
-- This is not "applying 1NF" - no normal form has been named yet. It is one
-- concrete bug being fixed by putting a fact where it belongs.

IF OBJECT_ID('Course') IS NOT NULL
BEGIN
    -- Drop the FK first if a previous attempt left it behind, or the DROP fails.
    IF OBJECT_ID('FK_EnrolmentSheet_Course', 'F') IS NOT NULL
        ALTER TABLE EnrolmentSheet DROP CONSTRAINT FK_EnrolmentSheet_Course;
    DROP TABLE Course;
END
GO

CREATE TABLE Course (
    CourseCode  nvarchar(12)  NOT NULL,
    CourseTitle nvarchar(120) NOT NULL,
    Credits     int           NOT NULL,
    CONSTRAINT PK_Course PRIMARY KEY (CourseCode)
);
GO

-- DISTINCT is doing real work here: the sheet holds one row per enrolment, so
-- DB101 appears twice. That duplication is exactly what we are removing.
INSERT INTO Course (CourseCode, CourseTitle, Credits)
SELECT DISTINCT CourseCode, CourseTitle, Credits FROM EnrolmentSheet;
GO

ALTER TABLE EnrolmentSheet DROP COLUMN CourseTitle;
ALTER TABLE EnrolmentSheet DROP COLUMN Credits;
GO

-- The foreign key is what keeps the two tables honest: an enrolment can no
-- longer name a course that does not exist.
ALTER TABLE EnrolmentSheet
    ADD CONSTRAINT FK_EnrolmentSheet_Course
    FOREIGN KEY (CourseCode) REFERENCES Course (CourseCode);
GO
