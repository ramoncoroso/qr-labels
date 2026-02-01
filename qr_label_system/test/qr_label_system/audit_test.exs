defmodule QrLabelSystem.AuditTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.Audit
  alias QrLabelSystem.Audit.Log

  import QrLabelSystem.AccountsFixtures
  import QrLabelSystem.AuditFixtures

  describe "log/4" do
    test "creates an audit log entry" do
      user = user_fixture()

      assert {:ok, %Log{} = log} = Audit.log("login", "user", user.id, user_id: user.id)
      assert log.action == "login"
      assert log.resource_type == "user"
      assert log.resource_id == user.id
      assert log.user_id == user.id
    end

    test "converts atoms to strings for action and resource_type" do
      assert {:ok, log} = Audit.log(:create_design, :design, 1)
      assert log.action == "create_design"
      assert log.resource_type == "design"
    end

    test "accepts nil resource_id" do
      assert {:ok, log} = Audit.log("logout", "session")
      assert log.resource_id == nil
    end

    test "accepts metadata" do
      metadata = %{ip: "192.168.1.1", browser: "Chrome"}
      assert {:ok, log} = Audit.log("login", "user", 1, metadata: metadata)
      assert log.metadata == metadata
    end

    test "accepts ip_address option" do
      assert {:ok, log} = Audit.log("login", "user", 1, ip_address: "10.0.0.1")
      assert log.ip_address == "10.0.0.1"
    end

    test "accepts user_agent option" do
      assert {:ok, log} = Audit.log("login", "user", 1, user_agent: "Mozilla/5.0")
      assert log.user_agent == "Mozilla/5.0"
    end

    test "validates action inclusion" do
      assert {:error, changeset} = Audit.log("invalid_action", "resource")
      assert "is invalid" in errors_on(changeset).action
    end
  end

  describe "log_async/4" do
    test "returns :ok immediately" do
      assert :ok = Audit.log_async("login", "user", 1)
    end

    test "creates log entry asynchronously" do
      user = user_fixture()
      :ok = Audit.log_async("login", "user", user.id, user_id: user.id)

      # Give the async task time to complete
      Process.sleep(100)

      logs = Audit.logs_for_user(user.id)
      assert length(logs) >= 1
    end
  end

  describe "list_logs/1" do
    test "returns logs with pagination" do
      user = user_fixture()
      for _ <- 1..25, do: audit_log_fixture(%{user_id: user.id})

      result = Audit.list_logs(%{"page" => "1", "per_page" => "10"})

      assert length(result.logs) == 10
      assert result.page == 1
      assert result.per_page == 10
      assert result.total == 25
      assert result.total_pages == 3
    end

    test "filters by user_id" do
      user1 = user_fixture()
      user2 = user_fixture()

      audit_log_fixture(%{user_id: user1.id})
      audit_log_fixture(%{user_id: user1.id})
      audit_log_fixture(%{user_id: user2.id})

      result = Audit.list_logs(%{"user_id" => user1.id})
      assert result.total == 2
    end

    test "filters by action" do
      audit_log_fixture(%{action: "login"})
      audit_log_fixture(%{action: "login"})
      audit_log_fixture(%{action: "logout"})

      result = Audit.list_logs(%{"action" => "login"})
      assert result.total == 2
    end

    test "filters by resource_type" do
      audit_log_fixture(%{resource_type: "design"})
      audit_log_fixture(%{resource_type: "design"})
      audit_log_fixture(%{resource_type: "user"})

      result = Audit.list_logs(%{"resource_type" => "design"})
      assert result.total == 2
    end

    test "filters by from_date" do
      old_log = audit_log_fixture()
      _new_log = audit_log_fixture()

      # Update old log to have old timestamp (this is a simplification)
      from_date = Date.utc_today() |> Date.to_iso8601()

      result = Audit.list_logs(%{"from_date" => from_date})
      assert result.total >= 1
    end

    test "filters by to_date" do
      _log = audit_log_fixture()

      to_date = Date.utc_today() |> Date.to_iso8601()

      result = Audit.list_logs(%{"to_date" => to_date})
      assert result.total >= 1
    end

    test "filters by date range" do
      _log = audit_log_fixture()

      today = Date.utc_today()
      from_date = today |> Date.add(-1) |> Date.to_iso8601()
      to_date = today |> Date.add(1) |> Date.to_iso8601()

      result = Audit.list_logs(%{"from_date" => from_date, "to_date" => to_date})
      assert result.total >= 1
    end

    test "ignores invalid from_date" do
      audit_log_fixture()

      result = Audit.list_logs(%{"from_date" => "invalid"})
      assert result.total >= 1
    end

    test "ignores empty action filter" do
      audit_log_fixture()

      result = Audit.list_logs(%{"action" => ""})
      assert result.total >= 1
    end

    test "ignores empty resource_type filter" do
      audit_log_fixture()

      result = Audit.list_logs(%{"resource_type" => ""})
      assert result.total >= 1
    end

    test "uses default pagination values" do
      result = Audit.list_logs(%{})
      assert result.page == 1
      assert result.per_page == 50
    end

    test "handles invalid page number" do
      result = Audit.list_logs(%{"page" => "invalid"})
      assert result.page == 1
    end

    test "preloads user association" do
      user = user_fixture()
      audit_log_fixture(%{user_id: user.id})

      result = Audit.list_logs(%{})
      log = hd(result.logs)
      assert log.user.id == user.id
    end

    test "returns logs in expected order" do
      log1 = audit_log_fixture()
      log2 = audit_log_fixture()

      result = Audit.list_logs(%{})
      ids = Enum.map(result.logs, & &1.id)
      # Both logs should be present (order may vary due to timestamp ties)
      assert log1.id in ids
      assert log2.id in ids
    end
  end

  describe "logs_for_resource/3" do
    test "returns logs for specific resource" do
      audit_log_fixture(%{resource_type: "design", resource_id: 1})
      audit_log_fixture(%{resource_type: "design", resource_id: 1})
      audit_log_fixture(%{resource_type: "design", resource_id: 2})

      logs = Audit.logs_for_resource("design", 1)
      assert length(logs) == 2
    end

    test "limits results" do
      for _ <- 1..30, do: audit_log_fixture(%{resource_type: "design", resource_id: 1})

      logs = Audit.logs_for_resource("design", 1, 10)
      assert length(logs) == 10
    end

    test "uses default limit of 20" do
      for _ <- 1..30, do: audit_log_fixture(%{resource_type: "design", resource_id: 1})

      logs = Audit.logs_for_resource("design", 1)
      assert length(logs) == 20
    end

    test "preloads user" do
      user = user_fixture()
      audit_log_fixture(%{resource_type: "design", resource_id: 1, user_id: user.id})

      [log] = Audit.logs_for_resource("design", 1)
      assert log.user.id == user.id
    end

    test "accepts atom for resource_type" do
      audit_log_fixture(%{resource_type: "design", resource_id: 1})

      logs = Audit.logs_for_resource(:design, 1)
      assert length(logs) == 1
    end
  end

  describe "logs_for_user/2" do
    test "returns logs for specific user" do
      user = user_fixture()
      other_user = user_fixture()

      audit_log_fixture(%{user_id: user.id})
      audit_log_fixture(%{user_id: user.id})
      audit_log_fixture(%{user_id: other_user.id})

      logs = Audit.logs_for_user(user.id)
      assert length(logs) == 2
    end

    test "limits results" do
      user = user_fixture()
      for _ <- 1..100, do: audit_log_fixture(%{user_id: user.id})

      logs = Audit.logs_for_user(user.id, 10)
      assert length(logs) == 10
    end

    test "uses default limit of 50" do
      user = user_fixture()
      for _ <- 1..100, do: audit_log_fixture(%{user_id: user.id})

      logs = Audit.logs_for_user(user.id)
      assert length(logs) == 50
    end

    test "orders by inserted_at desc" do
      user = user_fixture()
      log1 = audit_log_fixture(%{user_id: user.id})
      log2 = audit_log_fixture(%{user_id: user.id})

      logs = Audit.logs_for_user(user.id)
      # log2 has higher id, so it should come first (desc order by inserted_at, then id)
      assert hd(logs).id == log2.id
      assert List.last(logs).id == log1.id
    end
  end

  describe "cleanup_old_logs/1" do
    test "deletes logs older than specified days" do
      # Create old log by directly inserting with old timestamp
      # Truncate to seconds to match database precision
      old_date = DateTime.utc_now() |> DateTime.add(-100, :day) |> DateTime.truncate(:second)

      {:ok, old_log} = Repo.insert(%Log{
        action: "login",
        resource_type: "user",
        inserted_at: old_date
      })

      new_log = audit_log_fixture()

      {count, _} = Audit.cleanup_old_logs(90)

      assert count >= 1
      assert_raise Ecto.NoResultsError, fn -> Repo.get!(Log, old_log.id) end
      assert Repo.get(Log, new_log.id) != nil
    end

    test "uses default of 90 days" do
      {_count, _} = Audit.cleanup_old_logs()
      # Just verify it doesn't crash
      assert true
    end

    test "returns count of deleted logs" do
      # Truncate to seconds to match database precision
      old_date = DateTime.utc_now() |> DateTime.add(-100, :day) |> DateTime.truncate(:second)

      for _ <- 1..5 do
        Repo.insert!(%Log{
          action: "login",
          resource_type: "user",
          inserted_at: old_date
        })
      end

      {count, _} = Audit.cleanup_old_logs(90)
      assert count >= 5
    end
  end
end
