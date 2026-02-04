defmodule QrLabelSystem.DataSources.DbConnectorTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.DataSources.DbConnector

  describe "validate_query/1 - basic validation" do
    test "accepts valid SELECT query" do
      assert :ok = DbConnector.validate_query("SELECT * FROM users")
    end

    test "accepts SELECT with columns" do
      assert :ok = DbConnector.validate_query("SELECT id, name, email FROM users")
    end

    test "accepts SELECT with WHERE clause" do
      assert :ok = DbConnector.validate_query("SELECT * FROM users WHERE active = true")
    end

    test "accepts SELECT with JOIN" do
      query = "SELECT u.name, o.total FROM users u JOIN orders o ON u.id = o.user_id"
      assert :ok = DbConnector.validate_query(query)
    end

    test "accepts SELECT with GROUP BY" do
      assert :ok = DbConnector.validate_query("SELECT status, COUNT(*) FROM orders GROUP BY status")
    end

    test "accepts SELECT with ORDER BY" do
      assert :ok = DbConnector.validate_query("SELECT * FROM users ORDER BY created_at DESC")
    end

    test "accepts SELECT with LIMIT" do
      assert :ok = DbConnector.validate_query("SELECT * FROM users LIMIT 100")
    end

    test "rejects empty query" do
      assert {:error, "Query cannot be empty"} = DbConnector.validate_query("")
    end

    test "rejects whitespace-only query" do
      assert {:error, "Query cannot be empty"} = DbConnector.validate_query("   ")
    end

    test "rejects non-string query" do
      assert {:error, "Query must be a string"} = DbConnector.validate_query(nil)
      assert {:error, "Query must be a string"} = DbConnector.validate_query(123)
    end

    test "rejects query longer than 10000 characters" do
      long_query = "SELECT * FROM users WHERE name = '" <> String.duplicate("a", 10000) <> "'"
      assert {:error, "Query is too long (max 10,000 characters)"} = DbConnector.validate_query(long_query)
    end
  end

  describe "validate_query/1 - non-SELECT rejection" do
    test "rejects non-SELECT queries" do
      assert {:error, "Only SELECT queries are allowed"} = DbConnector.validate_query("INSERT INTO users VALUES (1)")
    end

    test "rejects UPDATE queries" do
      assert {:error, _} = DbConnector.validate_query("UPDATE users SET name = 'x'")
    end

    test "rejects DELETE queries" do
      assert {:error, _} = DbConnector.validate_query("DELETE FROM users")
    end

    test "rejects queries not starting with SELECT" do
      assert {:error, "Only SELECT queries are allowed"} = DbConnector.validate_query("WITH cte AS (SELECT 1)")
    end
  end

  describe "validate_query/1 - DDL prevention" do
    test "rejects DROP statements" do
      assert {:error, _} = DbConnector.validate_query("DROP TABLE users")
    end

    test "rejects ALTER statements" do
      assert {:error, _} = DbConnector.validate_query("ALTER TABLE users ADD COLUMN x")
    end

    test "rejects CREATE statements" do
      assert {:error, _} = DbConnector.validate_query("CREATE TABLE test (id int)")
    end

    test "rejects TRUNCATE statements" do
      assert {:error, _} = DbConnector.validate_query("TRUNCATE TABLE users")
    end

    test "rejects GRANT statements" do
      assert {:error, _} = DbConnector.validate_query("GRANT ALL ON users TO public")
    end

    test "rejects REVOKE statements" do
      assert {:error, _} = DbConnector.validate_query("REVOKE ALL ON users FROM public")
    end
  end

  describe "validate_query/1 - SQL injection prevention" do
    test "rejects queries with DROP in subquery" do
      query = "SELECT * FROM users WHERE id IN (SELECT id FROM users; DROP TABLE users)"
      assert {:error, _} = DbConnector.validate_query(query)
    end

    test "rejects stacked queries with semicolon" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM users; DELETE FROM users")
    end

    test "rejects stacked queries with SELECT after semicolon" do
      assert {:error, _} = DbConnector.validate_query("SELECT 1; SELECT * FROM passwords")
    end

    test "rejects UNION-based injection" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM users UNION SELECT * FROM passwords")
    end

    test "rejects UNION ALL injection" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM users UNION ALL SELECT password FROM admin")
    end

    test "rejects SQL comments (double dash)" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM users -- DROP TABLE")
    end

    test "rejects SQL comments (block comment start)" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM users /* comment")
    end

    test "rejects SQL comments (block comment end)" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM users */")
    end

    test "rejects hash comments" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM users # comment")
    end
  end

  describe "validate_query/1 - command execution prevention" do
    test "rejects EXEC keyword" do
      assert {:error, _} = DbConnector.validate_query("SELECT 1; EXEC sp_help")
    end

    test "rejects EXECUTE keyword" do
      assert {:error, _} = DbConnector.validate_query("EXECUTE sp_help")
    end

    test "rejects xp_ procedures" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM users; xp_cmdshell 'dir'")
    end

    test "rejects sp_ procedures" do
      assert {:error, _} = DbConnector.validate_query("SELECT 1; sp_executesql")
    end
  end

  describe "validate_query/1 - time-based attack prevention" do
    test "rejects SLEEP function" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM users WHERE id = 1 AND SLEEP(5)")
    end

    test "rejects BENCHMARK function" do
      assert {:error, _} = DbConnector.validate_query("SELECT BENCHMARK(1000000, SHA1('test'))")
    end

    test "rejects WAITFOR function" do
      assert {:error, _} = DbConnector.validate_query("SELECT 1; WAITFOR DELAY '0:0:5'")
    end

    test "rejects PG_SLEEP function" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM users WHERE pg_sleep(5) IS NOT NULL")
    end
  end

  describe "validate_query/1 - file operation prevention" do
    test "rejects LOAD_FILE function" do
      assert {:error, _} = DbConnector.validate_query("SELECT LOAD_FILE('/etc/passwd')")
    end

    test "rejects INTO OUTFILE" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM users INTO OUTFILE '/tmp/data.txt'")
    end

    test "rejects INTO DUMPFILE" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM users INTO DUMPFILE '/tmp/data.txt'")
    end
  end

  describe "validate_query/1 - information schema prevention" do
    test "rejects INFORMATION_SCHEMA access" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM INFORMATION_SCHEMA.TABLES")
    end

    test "rejects information_schema lowercase" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM information_schema.columns")
    end
  end

  describe "validate_query/1 - encoding bypass prevention" do
    test "rejects hex encoded values" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM users WHERE name = 0x61646D696E")
    end

    test "rejects CHAR function" do
      assert {:error, _} = DbConnector.validate_query("SELECT CHAR(65)")
    end

    test "rejects CHR function" do
      assert {:error, _} = DbConnector.validate_query("SELECT CHR(65)")
    end

    test "allows CONCAT function (legitimate SQL)" do
      # CONCAT is a legitimate SQL function, not a security risk by itself
      assert :ok = DbConnector.validate_query("SELECT CONCAT(first_name, ' ', last_name) FROM users")
    end
  end

  describe "validate_query/1 - case insensitivity" do
    test "rejects DROP case insensitive" do
      assert {:error, _} = DbConnector.validate_query("select * from users; drop table users")
    end

    test "rejects DELETE case insensitive" do
      assert {:error, _} = DbConnector.validate_query("Delete From users")
    end

    test "accepts SELECT case insensitive" do
      assert :ok = DbConnector.validate_query("select * from users")
    end
  end

  describe "validate_query/1 - edge cases" do
    test "accepts query with numbers" do
      assert :ok = DbConnector.validate_query("SELECT * FROM users WHERE age > 18 AND id = 100")
    end

    test "accepts query with quoted strings" do
      assert :ok = DbConnector.validate_query("SELECT * FROM users WHERE name = 'John Doe'")
    end

    test "accepts query with date functions" do
      assert :ok = DbConnector.validate_query("SELECT * FROM orders WHERE created_at > NOW() - INTERVAL 7 DAY")
    end

    test "accepts complex valid query" do
      query = """
      SELECT u.id, u.name, COUNT(o.id) as order_count, SUM(o.total) as total_spent
      FROM users u
      LEFT JOIN orders o ON u.id = o.user_id
      WHERE u.active = true AND u.created_at > '2024-01-01'
      GROUP BY u.id, u.name
      HAVING COUNT(o.id) > 0
      ORDER BY total_spent DESC
      LIMIT 100
      """
      assert :ok = DbConnector.validate_query(query)
    end

    test "accepts leading whitespace" do
      assert :ok = DbConnector.validate_query("   SELECT * FROM users")
    end
  end

  describe "validate_query/1 - Unicode bypass prevention" do
    test "rejects fullwidth DELETE" do
      # ＤＥＬＥＴＥ in fullwidth characters
      assert {:error, _} = DbConnector.validate_query("ＳＥＬＥＣＴ 1; ＤＥＬＥＴＥ FROM users")
    end

    test "rejects fullwidth DROP" do
      # ＤＲＯＰ in fullwidth characters
      assert {:error, _} = DbConnector.validate_query("ＳＥＬＥＣＴ 1; ＤＲＯＰ TABLE users")
    end

    test "normalizes fullwidth SELECT correctly" do
      # ＳＥＬＥＣＴ should be normalized to SELECT and accepted
      assert :ok = DbConnector.validate_query("ＳＥＬＥＣＴ * FROM users")
    end
  end

  describe "validate_query/1 - PostgreSQL specific prevention" do
    test "rejects pg_read_file" do
      assert {:error, _} = DbConnector.validate_query("SELECT pg_read_file('/etc/passwd')")
    end

    test "rejects pg_read_binary_file" do
      assert {:error, _} = DbConnector.validate_query("SELECT pg_read_binary_file('/etc/passwd')")
    end

    test "rejects pg_ls_dir" do
      assert {:error, _} = DbConnector.validate_query("SELECT pg_ls_dir('/tmp')")
    end

    test "rejects lo_import" do
      assert {:error, _} = DbConnector.validate_query("SELECT lo_import('/etc/passwd')")
    end

    test "rejects lo_export" do
      assert {:error, _} = DbConnector.validate_query("SELECT lo_export(12345, '/tmp/out.txt')")
    end

    test "rejects COPY command" do
      assert {:error, _} = DbConnector.validate_query("COPY users FROM '/tmp/data.csv'")
    end

    test "rejects dblink" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM dblink('host=attacker.com', 'SELECT 1')")
    end

    test "rejects pg_catalog access" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM pg_catalog.pg_tables")
    end

    test "rejects pg_terminate_backend" do
      assert {:error, _} = DbConnector.validate_query("SELECT pg_terminate_backend(12345)")
    end
  end

  describe "validate_query/1 - SQL Server specific prevention" do
    test "rejects OPENROWSET" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM OPENROWSET('SQLOLEDB', 'Server=attacker')")
    end

    test "rejects OPENDATASOURCE" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM OPENDATASOURCE('SQLOLEDB', 'Server=attacker').db.dbo.users")
    end

    test "rejects OPENQUERY" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM OPENQUERY(linkedserver, 'SELECT 1')")
    end

    test "rejects BULK INSERT" do
      assert {:error, _} = DbConnector.validate_query("BULK INSERT users FROM '/tmp/data.csv'")
    end

    test "rejects sys.databases access" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM sys.databases")
    end

    test "rejects sys.tables access" do
      assert {:error, _} = DbConnector.validate_query("SELECT * FROM sys.tables")
    end

    test "rejects WAITFOR DELAY" do
      assert {:error, _} = DbConnector.validate_query("SELECT 1; WAITFOR DELAY '00:00:05'")
    end

    test "rejects WAITFOR TIME" do
      assert {:error, _} = DbConnector.validate_query("SELECT 1; WAITFOR TIME '23:00'")
    end
  end

  describe "validate_query/1 - SELECT INTO prevention" do
    test "rejects SELECT INTO table" do
      assert {:error, _} = DbConnector.validate_query("SELECT * INTO new_table FROM users")
    end

    test "rejects SELECT INTO with schema" do
      assert {:error, _} = DbConnector.validate_query("SELECT * INTO dbo.new_table FROM users")
    end

    test "rejects SELECT INTO TEMPORARY" do
      assert {:error, _} = DbConnector.validate_query("SELECT * INTO TEMPORARY temp_users FROM users")
    end
  end

  describe "validate_query/1 - CTE prevention" do
    test "rejects WITH clause (CTE)" do
      assert {:error, _} = DbConnector.validate_query("WITH cte AS (SELECT 1) SELECT * FROM cte")
    end

    test "rejects WITH recursive CTE" do
      assert {:error, _} = DbConnector.validate_query("WITH RECURSIVE r AS (SELECT 1) SELECT * FROM r")
    end

    test "rejects WITH used for malicious operations" do
      # CTEs can wrap DELETE operations in some databases
      assert {:error, _} = DbConnector.validate_query("WITH x AS (DELETE FROM users RETURNING *) SELECT * FROM x")
    end
  end

  describe "validate_query/1 - MySQL specific prevention" do
    test "rejects LOAD DATA" do
      assert {:error, _} = DbConnector.validate_query("LOAD DATA INFILE '/tmp/data.csv' INTO TABLE users")
    end

    test "rejects UNHEX function" do
      assert {:error, _} = DbConnector.validate_query("SELECT UNHEX('414243')")
    end

    test "rejects CONV function" do
      assert {:error, _} = DbConnector.validate_query("SELECT CONV('a', 16, 10)")
    end
  end

  describe "validate_query/1 - dynamic SQL prevention" do
    test "rejects PREPARE statement" do
      assert {:error, _} = DbConnector.validate_query("PREPARE stmt FROM 'SELECT * FROM users'")
    end

    test "rejects DEALLOCATE statement" do
      assert {:error, _} = DbConnector.validate_query("DEALLOCATE PREPARE stmt")
    end
  end
end
