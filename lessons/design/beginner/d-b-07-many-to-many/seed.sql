-- Books with their authors crammed into one delimited column, which is how this
-- almost always arrives from a spreadsheet or a CSV import.
IF OBJECT_ID('BookImport') IS NOT NULL DROP TABLE BookImport;

CREATE TABLE BookImport (
    RowId       int           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Title       nvarchar(200) NOT NULL,
    Isbn        char(13)      NOT NULL,
    PublishedOn date          NOT NULL,
    -- Every problem in this module lives in this one column.
    Authors     nvarchar(400) NOT NULL
);
GO

INSERT INTO BookImport (Title, Isbn, PublishedOn, Authors)
VALUES
    ('Designing Data-Intensive Applications', '9781449373320', '2017-03-16', 'Martin Kleppmann'),
    ('The Pragmatic Programmer',               '9780135957059', '2019-09-13', 'Andrew Hunt, David Thomas'),
    ('Refactoring',                            '9780134757599', '2018-11-19', 'Martin Fowler, Kent Beck'),
    ('Design Patterns',                        '9780201633610', '1994-10-31', 'Erich Gamma, Richard Helm, Ralph Johnson, John Vlissides'),
    ('Test-Driven Development',                '9780321146533', '2002-11-08', 'Kent Beck'),
    ('Domain-Driven Design',                   '9780321125217', '2003-08-20', 'Eric Evans');
GO
