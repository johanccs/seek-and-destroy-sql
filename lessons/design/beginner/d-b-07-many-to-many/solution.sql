-- Many-to-many has no direct form in a relational database. You materialise it:
-- a third table whose rows ARE the relationships.

CREATE TABLE Books (
    BookId      int           NOT NULL IDENTITY(1,1),
    Title       nvarchar(200) NOT NULL,
    Isbn        char(13)      NOT NULL,
    PublishedOn date          NOT NULL,
    CONSTRAINT PK_Books PRIMARY KEY (BookId)
);

CREATE TABLE Authors (
    AuthorId int           NOT NULL IDENTITY(1,1),
    Name     nvarchar(100) NOT NULL,
    CONSTRAINT PK_Authors PRIMARY KEY (AuthorId)
);

-- The junction. Its primary key is BOTH foreign keys together, which is what
-- makes "this author wrote this book" recordable exactly once.
CREATE TABLE BooksAuthors (
    BookId   int NOT NULL,
    AuthorId int NOT NULL,
    CONSTRAINT PK_BooksAuthors PRIMARY KEY (BookId, AuthorId)
);

ALTER TABLE BooksAuthors ADD CONSTRAINT FK_BooksAuthors_Books
    FOREIGN KEY (BookId) REFERENCES Books (BookId);
ALTER TABLE BooksAuthors ADD CONSTRAINT FK_BooksAuthors_Authors
    FOREIGN KEY (AuthorId) REFERENCES Authors (AuthorId);

-- Move the data across. STRING_SPLIT is what finally kills the delimited column.
INSERT INTO Books (Title, Isbn, PublishedOn)
SELECT Title, Isbn, PublishedOn FROM BookImport;

INSERT INTO Authors (Name)
SELECT DISTINCT LTRIM(RTRIM(s.value))
FROM BookImport b
CROSS APPLY STRING_SPLIT(b.Authors, ',') s;

INSERT INTO BooksAuthors (BookId, AuthorId)
SELECT DISTINCT bk.BookId, a.AuthorId
FROM BookImport b
CROSS APPLY STRING_SPLIT(b.Authors, ',') s
JOIN Books   bk ON bk.Isbn  = b.Isbn
JOIN Authors a  ON a.Name = LTRIM(RTRIM(s.value));

-- Now this question is answerable, which it never was before:
--   SELECT a.Name, COUNT(*) FROM BooksAuthors ba
--   JOIN Authors a ON a.AuthorId = ba.AuthorId GROUP BY a.Name;
