-- 1. Xem danh sách username có bookmark nhưng thiếu trong auth_user
SELECT DISTINCT b.employee_number AS username
FROM bookmark AS b
WHERE NOT EXISTS (
    SELECT 1
    FROM auth_user AS u
    WHERE u.username = b.employee_number
)
ORDER BY username;

-- 2. Xoá các dòng bookmark tương ứng
DELETE FROM bookmark
WHERE NOT EXISTS (
    SELECT 1
    FROM auth_user AS u
    WHERE u.username = bookmark.employee_number
);

-- 3. Chạy ngay sau DELETE, trong cùng kết nối
SELECT ROW_COUNT() AS deleted_rows;