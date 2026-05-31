# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

RSpec.describe "Write Prevention Safety", :safety do
  describe "every forbidden ActiveRecord write method is blocked" do
    %i[
      save save! create create! update update! update_all
      destroy destroy! destroy_all delete delete_all
      insert insert_all upsert upsert_all
      touch increment! decrement! toggle!
    ].each do |method|
      it "blocks #{method}" do
        expect do
          Wild::Introspection::Adapter::WritePrevention.assert_not_write_method!(method)
        end.to raise_error(Wild::Introspection::WriteAttemptError)
      end
    end
  end

  describe "SQL injection patterns are caught" do
    [
      'INSERT INTO users (name) VALUES ("evil")',
      'insert into users (name) values ("evil")',
      "UPDATE users SET admin = true",
      "update users set admin = true",
      "DELETE FROM users",
      "delete from users",
      "DROP TABLE users",
      "drop table users",
      "ALTER TABLE users ADD COLUMN admin boolean",
      "alter table users add column admin boolean",
      "TRUNCATE users",
      "truncate users",
      "CREATE TABLE evil (id int)",
      "create table evil (id int)",
      "GRANT ALL ON users TO evil",
      "grant all on users to evil",
      "REVOKE ALL ON users FROM safe_user",
      "revoke all on users from safe_user",
      "SELECT * FROM users; INSERT INTO users (name) VALUES ('injected')",
      "SELECT * FROM users UNION INSERT INTO admin_users VALUES (1, 'hacker')",
      "SELECT * FROM users WHERE name = ''; DROP TABLE users; --"
    ].each do |sql|
      it "catches: #{sql.truncate(60)}" do
        expect do
          Wild::Introspection::Adapter::WritePrevention.assert_sql_read_only!(sql)
        end.to raise_error(Wild::Introspection::WriteAttemptError)
      end
    end
  end

  describe "safe SQL patterns are not false-positived" do
    [
      "SELECT * FROM users",
      'SELECT id, name FROM users WHERE status = "active"',
      "SELECT COUNT(*) FROM users",
      "SELECT * FROM users ORDER BY created_at DESC LIMIT 50",
      "SELECT u.* FROM users u INNER JOIN accounts a ON u.account_id = a.id",
      "SELECT * FROM users WHERE name = 'Grant'",
      "SELECT * FROM users WHERE description LIKE '%update%'",
      "SELECT * FROM users WHERE bio LIKE '%insert%'",
      "SELECT * FROM users WHERE notes = 'Please delete this later'",
      'SELECT * FROM feature_flags WHERE key = "truncated_display"',
      "SELECT * FROM users WHERE name = 'Salvatore'"
    ].each do |sql|
      it "allows: #{sql.truncate(60)}" do
        expect do
          Wild::Introspection::Adapter::WritePrevention.assert_sql_read_only!(sql)
        end.not_to raise_error
      end
    end
  end
end

# rubocop:enable RSpec/DescribeClass
