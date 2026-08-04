-- Two transitive dependencies, one shape: a non-key attribute determining
-- another non-key attribute. Each determinant becomes the key of its own table.

-- InstructorName -> InstructorOffice
IF OBJECT_ID('Instructor') IS NOT NULL DROP TABLE Instructor;
GO

CREATE TABLE Instructor (
    InstructorName   nvarchar(100) NOT NULL,
    InstructorOffice nvarchar(40)  NOT NULL,
    CONSTRAINT PK_Instructor PRIMARY KEY (InstructorName)
);
GO

INSERT INTO Instructor (InstructorName, InstructorOffice)
SELECT DISTINCT InstructorName, InstructorOffice FROM CourseOffering;
GO

-- RoomCode -> RoomBuilding, RoomCapacity
IF OBJECT_ID('Room') IS NOT NULL DROP TABLE Room;
GO

CREATE TABLE Room (
    RoomCode     nvarchar(12) NOT NULL,
    RoomBuilding nvarchar(60) NOT NULL,
    RoomCapacity int          NOT NULL,
    CONSTRAINT PK_Room PRIMARY KEY (RoomCode)
);
GO

INSERT INTO Room (RoomCode, RoomBuilding, RoomCapacity)
SELECT DISTINCT RoomCode, RoomBuilding, RoomCapacity FROM CourseOffering;
GO

-- The determinants stay behind as foreign keys. RoomCode and InstructorName
-- genuinely do depend on (CourseCode, Term) -- which room and which instructor
-- an offering uses is a fact about the offering. What left is the detail that
-- was a fact about the room and the instructor instead.
ALTER TABLE CourseOffering DROP COLUMN InstructorOffice;
ALTER TABLE CourseOffering DROP COLUMN RoomBuilding;
ALTER TABLE CourseOffering DROP COLUMN RoomCapacity;
GO

ALTER TABLE CourseOffering
    ADD CONSTRAINT FK_CourseOffering_Instructor
    FOREIGN KEY (InstructorName) REFERENCES Instructor (InstructorName);

ALTER TABLE CourseOffering
    ADD CONSTRAINT FK_CourseOffering_Room
    FOREIGN KEY (RoomCode) REFERENCES Room (RoomCode);
GO
