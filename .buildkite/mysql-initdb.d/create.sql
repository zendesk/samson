create user travis@'%';
set GLOBAL innodb_large_prefix = true';
set GLOBAL innodb_file_per_table = true;
set GLOBAL innodb_file_format = "barracuda";
GRANT ALL ON *.* TO 'travis'@'localhost';
