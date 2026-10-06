-- เฉลย A1: DDL & DML (สำหรับผู้สอน)
USE lab_student;

-- 1
DROP TABLE IF EXISTS books;
CREATE TABLE books (
    book_id         INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
    isbn            CHAR(13)      NOT NULL UNIQUE,
    title           VARCHAR(255)  NOT NULL,
    author          VARCHAR(200)  NOT NULL,
    category        VARCHAR(10)   NOT NULL,
    published_year  SMALLINT      NOT NULL,
    copies          INT           NOT NULL DEFAULT 1,
    price           DECIMAL(10,2) NOT NULL,
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT ck_books_isbn     CHECK (CHAR_LENGTH(isbn) = 13),
    CONSTRAINT ck_books_category CHECK (category IN ('novel','science','business','kids')),
    CONSTRAINT ck_books_year     CHECK (published_year >= 1900),
    CONSTRAINT ck_books_copies   CHECK (copies >= 0)
);
-- 2
DESCRIBE books;
-- 3 (ตั้งใจให้ error)
-- INSERT INTO books (isbn, title, author, category, published_year, price) VALUES ('123', 'x', 'y', 'novel', 2020, 100);          -- ck_books_isbn
-- INSERT INTO books (isbn, title, author, category, published_year, price) VALUES ('9780000000001', 'x', 'y', 'comic', 2020, 1);  -- ck_books_category
-- INSERT INTO books (isbn, title, author, category, published_year, copies, price) VALUES ('9780000000002', 'x', 'y', 'kids', 2020, -1, 1); -- ck_books_copies

-- 4
INSERT INTO books (isbn, title, author, category, published_year, copies, price) VALUES
 ('9786160000011', 'ความสุขของกะทิ',       'งามพรรณ เวชชาชีวะ', 'novel',    2003, 3, 185),
 ('9786160000028', 'ข้างหลังภาพ',          'ศรีบูรพา',          'novel',    1937, 2, 150),
 ('9786160000035', 'จักรวาลในเปลือกนัท',   'Stephen Hawking',   'science',  2001, 1, 320),
 ('9786160000042', 'เซเปียนส์',            'Yuval Noah Harari', 'science',  2011, 4, 495),
 ('9786160000059', 'Zero to One',          'Peter Thiel',       'business', 2014, 2, 295),
 ('9786160000066', 'พ่อรวยสอนลูก',          'Robert Kiyosaki',   'business', 1997, 5, 225),
 ('9786160000073', 'กระต่ายกับเต่า',        'นิทานอีสป',         'kids',     2015, 6,  89),
 ('9786160000080', 'ไดโนเสาร์ตัวน้อย',      'นานมีบุ๊คส์',        'kids',     2019, 1, 120);
INSERT INTO books (isbn, title, author, category, published_year, price)                -- copies = default 1
VALUES ('9786160000097', 'เจ้าชายน้อย', 'Antoine de Saint-Exupéry', 'kids', 1943, 159);
SELECT * FROM books;

-- 5
UPDATE books SET copies = copies + 2 WHERE category = 'kids';
-- 6
UPDATE books SET price = ROUND(price * 0.8, 2) WHERE published_year < 2010;
-- 7
SELECT * FROM books WHERE isbn = '9786160000080';
DELETE FROM books WHERE isbn = '9786160000080';
-- 8
ALTER TABLE books ADD COLUMN shelf_code VARCHAR(10) NULL;
UPDATE books SET shelf_code = CONCAT(CASE category WHEN 'novel' THEN 'A' WHEN 'science' THEN 'B'
                                                   WHEN 'business' THEN 'C' ELSE 'D' END, '-', LPAD(book_id, 2, '0'))
WHERE book_id > 0;
-- 9 (ทุกเล่มถูกแก้ในข้อ 8 จึงควรทำข้อ 9 ก่อนข้อ 8 หรือเทียบ created_at กับ updated_at)
SELECT title, created_at, updated_at, updated_at > created_at AS was_updated FROM books;

-- 10
START TRANSACTION;
UPDATE books SET copies = copies - 1 WHERE isbn = '9786160000042';
UPDATE books SET copies = copies + 1 WHERE isbn = '9786160000035';
COMMIT;
-- 11
START TRANSACTION;
DELETE FROM books WHERE book_id > 0;
SELECT COUNT(*) AS after_delete FROM books;
ROLLBACK;
SELECT COUNT(*) AS after_rollback FROM books;
-- 12 DELETE: ลบทีละแถว มี WHERE ได้ ROLLBACK ได้ ไม่ reset AUTO_INCREMENT ช้าเมื่อข้อมูลเยอะ
--    TRUNCATE: ล้างทั้งตารางเร็วมาก reset AUTO_INCREMENT แต่เป็น DDL (auto-commit, ROLLBACK ไม่ได้)
--    pipeline: ล้างตาราง staging ชั่วคราวทั้งก้อน → TRUNCATE, ลบบางช่วง/ต้องอยู่ใน transaction → DELETE ... WHERE
