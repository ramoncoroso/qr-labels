defmodule QrLabelSystem.Repo.Migrations.AddWorkspaceToResources do
  use Ecto.Migration

  def up do
    # Step 1: Add nullable workspace_id columns
    alter table(:label_designs) do
      add :workspace_id, references(:workspaces, on_delete: :nilify_all)
    end

    alter table(:data_sources) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all)
    end

    alter table(:design_tags) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all)
    end

    flush()

    # Step 2: Data migration — create personal workspaces for existing users
    # and assign all their resources to those workspaces
    # Idempotent: skip users who already have a personal workspace
    execute """
    DO $$
    DECLARE
      u RECORD;
      ws_id BIGINT;
    BEGIN
      FOR u IN SELECT id, email FROM users LOOP
        -- Check if personal workspace already exists for this user
        SELECT id INTO ws_id FROM workspaces WHERE slug = 'personal-' || u.id LIMIT 1;

        IF ws_id IS NULL THEN
          -- Create personal workspace
          INSERT INTO workspaces (name, slug, type, owner_id, inserted_at, updated_at)
          VALUES (
            'Personal',
            'personal-' || u.id,
            'personal',
            u.id,
            NOW(),
            NOW()
          )
          RETURNING id INTO ws_id;

          -- Create admin membership
          INSERT INTO workspace_memberships (workspace_id, user_id, role, inserted_at, updated_at)
          VALUES (ws_id, u.id, 'admin', NOW(), NOW());
        END IF;

        -- Assign user's resources that are not yet assigned to any workspace
        UPDATE label_designs SET workspace_id = ws_id WHERE user_id = u.id AND workspace_id IS NULL;
        UPDATE data_sources SET workspace_id = ws_id WHERE user_id = u.id AND workspace_id IS NULL;
        UPDATE design_tags SET workspace_id = ws_id WHERE user_id = u.id AND workspace_id IS NULL;
      END LOOP;

      -- Clean up orphaned records (user_id IS NULL) before NOT NULL enforcement
      DELETE FROM data_sources WHERE user_id IS NULL AND workspace_id IS NULL;
      DELETE FROM design_tags WHERE user_id IS NULL AND workspace_id IS NULL;
    END $$;
    """

    flush()

    # Step 3: Make workspace_id NOT NULL for data_sources and tags (they always belong to a user)
    # label_designs stays nullable because system templates have no workspace
    alter table(:data_sources) do
      modify :workspace_id, :bigint, null: false, from: {:bigint, null: true}
    end

    alter table(:design_tags) do
      modify :workspace_id, :bigint, null: false, from: {:bigint, null: true}
    end

    # Step 4: Update unique index for tags
    drop_if_exists index(:design_tags, [:user_id, :name])
    create unique_index(:design_tags, [:workspace_id, :name])

    # Step 5: Add indexes
    create index(:label_designs, [:workspace_id])
    create index(:data_sources, [:workspace_id])
    create index(:design_tags, [:workspace_id])
  end

  def down do
    drop_if_exists index(:design_tags, [:workspace_id, :name])
    drop_if_exists index(:label_designs, [:workspace_id])
    drop_if_exists index(:data_sources, [:workspace_id])
    drop_if_exists index(:design_tags, [:workspace_id])

    alter table(:label_designs) do
      remove :workspace_id
    end

    alter table(:data_sources) do
      remove :workspace_id
    end

    alter table(:design_tags) do
      remove :workspace_id
    end

    create unique_index(:design_tags, [:user_id, :name])
  end
end
